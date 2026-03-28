import Foundation
import BackgroundTasks
import SwiftData

class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    static let taskIdentifier = "com.instaalerter.refresh"

    var modelContainer: ModelContainer?

    private init() {}

    func register() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.taskIdentifier,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            self.handleRefresh(task: refreshTask)
        }
    }

    func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60) // 30 minutes — gentle on battery
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let checkTask = Task {
            await checkAllAccounts()
        }

        task.expirationHandler = {
            checkTask.cancel()
        }

        Task {
            await checkTask.value
            task.setTaskCompleted(success: true)
        }
    }

    @MainActor
    func checkAllAccounts() async {
        guard let container = modelContainer else { return }
        let context = container.mainContext

        do {
            let accounts = try context.fetch(FetchDescriptor<TrackedAccount>())

            for account in accounts {
                guard !Task.isCancelled else { break }

                do {
                    let profile = try await InstagramScraper.shared.fetchProfile(username: account.username)

                    let oldFollowers = account.followerCount
                    let oldFollowing = account.followingCount
                    let changed = profile.followers != oldFollowers || profile.following != oldFollowing

                    account.updateCounts(
                        followers: profile.followers,
                        following: profile.following,
                        posts: profile.posts
                    )

                    if changed && account.lastChecked != nil {
                        NotificationManager.shared.sendChangeNotification(
                            username: account.username,
                            oldFollowers: oldFollowers,
                            newFollowers: profile.followers,
                            oldFollowing: oldFollowing,
                            newFollowing: profile.following
                        )
                    }

                    // Small delay between requests to avoid rate limiting
                    try? await Task.sleep(for: .seconds(2))
                } catch {
                    print("Error checking @\(account.username): \(error)")
                }
            }

            try context.save()
        } catch {
            print("Background check error: \(error)")
        }
    }
}
