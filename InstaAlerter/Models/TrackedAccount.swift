import Foundation
import SwiftData

@Model
final class TrackedAccount {
    @Attribute(.unique) var username: String
    var followerCount: Int
    var followingCount: Int
    var postCount: Int
    var lastChecked: Date?
    var history: [CountSnapshot]
    var dateAdded: Date

    init(username: String, followerCount: Int = 0, followingCount: Int = 0, postCount: Int = 0) {
        self.username = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.postCount = postCount
        self.lastChecked = nil
        self.history = []
        self.dateAdded = Date()
    }

    func updateCounts(followers: Int, following: Int, posts: Int) {
        let snapshot = CountSnapshot(
            followers: followerCount,
            following: followingCount,
            posts: postCount,
            date: Date()
        )

        let changed = followers != followerCount || following != followingCount

        if lastChecked != nil && changed {
            history.append(snapshot)
            // Cap history at 50 entries to keep memory/storage low
            if history.count > 50 {
                history.removeFirst(history.count - 50)
            }
        }

        followerCount = followers
        followingCount = following
        postCount = posts
        lastChecked = Date()
    }

    var followerDelta: Int? {
        guard let last = history.last else { return nil }
        return followerCount - last.followers
    }

    var followingDelta: Int? {
        guard let last = history.last else { return nil }
        return followingCount - last.following
    }
}

struct CountSnapshot: Codable, Hashable {
    var followers: Int
    var following: Int
    var posts: Int
    var date: Date
}
