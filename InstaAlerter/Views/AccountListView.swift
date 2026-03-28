import SwiftUI
import SwiftData

struct AccountListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedAccount.dateAdded, order: .reverse) private var accounts: [TrackedAccount]
    @State private var showingAddSheet = false
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            Group {
                if accounts.isEmpty {
                    emptyState
                } else {
                    accountList
                }
            }
            .navigationTitle("InstaAlerter")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !accounts.isEmpty {
                        Button {
                            Task { await refreshAll() }
                        } label: {
                            if isRefreshing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(isRefreshing)
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddAccountView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Accounts", systemImage: "person.2.slash")
        } description: {
            Text("Add an Instagram username to start tracking follower and following changes.")
        } actions: {
            Button("Add Account") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var accountList: some View {
        List {
            ForEach(accounts) { account in
                NavigationLink(destination: AccountDetailView(account: account)) {
                    AccountRow(account: account)
                }
            }
            .onDelete(perform: deleteAccounts)
        }
        .refreshable {
            await refreshAll()
        }
    }

    private func deleteAccounts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(accounts[index])
        }
    }

    private func refreshAll() async {
        isRefreshing = true
        for account in accounts {
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
            } catch {
                print("Error refreshing @\(account.username): \(error)")
            }
        }
        isRefreshing = false
    }
}

struct AccountRow: View {
    let account: TrackedAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("@\(account.username)")
                    .font(.headline)
                Spacer()
                if let lastChecked = account.lastChecked {
                    Text(lastChecked, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if account.lastChecked != nil {
                HStack(spacing: 16) {
                    StatBadge(
                        label: "Followers",
                        value: account.followerCount,
                        delta: account.followerDelta
                    )
                    StatBadge(
                        label: "Following",
                        value: account.followingCount,
                        delta: account.followingDelta
                    )
                }
            } else {
                Text("Not yet checked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatBadge: View {
    let label: String
    let value: Int
    let delta: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(formatNumber(value))
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let delta, delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(delta > 0 ? .green : .red)
                }
            }
        }
    }

    private func formatNumber(_ n: Int) -> String {
        NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }
}
