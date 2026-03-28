import SwiftUI
import SwiftData

@main
struct InstaAlerterApp: App {
    let container: ModelContainer

    init() {
        BackgroundTaskManager.shared.register()

        do {
            container = try ModelContainer(for: TrackedAccount.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        BackgroundTaskManager.shared.modelContainer = container
    }

    var body: some Scene {
        WindowGroup {
            AccountListView()
                .task {
                    await NotificationManager.shared.requestPermission()
                    BackgroundTaskManager.shared.scheduleNextRefresh()
                }
        }
        .modelContainer(container)
    }
}
