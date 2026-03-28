import SwiftUI

struct AccountDetailView: View {
    @Bindable var account: TrackedAccount
    @State private var isRefreshing = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section("Current Stats") {
                LabeledContent("Followers", value: formatNumber(account.followerCount))
                LabeledContent("Following", value: formatNumber(account.followingCount))
                LabeledContent("Posts", value: formatNumber(account.postCount))
                if let lastChecked = account.lastChecked {
                    LabeledContent("Last Checked") {
                        Text(lastChecked, style: .relative)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                Button {
                    Task { await checkNow() }
                } label: {
                    HStack {
                        Text("Check Now")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRefreshing)
            }

            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }

            if !account.history.isEmpty {
                Section("Change History") {
                    ForEach(account.history.reversed(), id: \.date) { snapshot in
                        HistoryRow(snapshot: snapshot, account: account)
                    }
                }
            }
        }
        .navigationTitle("@\(account.username)")
    }

    private func checkNow() async {
        isRefreshing = true
        errorMessage = nil

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

            if changed {
                NotificationManager.shared.sendChangeNotification(
                    username: account.username,
                    oldFollowers: oldFollowers,
                    newFollowers: profile.followers,
                    oldFollowing: oldFollowing,
                    newFollowing: profile.following
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isRefreshing = false
    }

    private func formatNumber(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }
}

struct HistoryRow: View {
    let snapshot: CountSnapshot
    let account: TrackedAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Text("Followers: \(formatNumber(snapshot.followers))")
                    .font(.subheadline)
                Text("Following: \(formatNumber(snapshot.following))")
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 2)
    }

    private func formatNumber(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }
}
