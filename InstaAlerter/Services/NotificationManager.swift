import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    func sendChangeNotification(
        username: String,
        oldFollowers: Int,
        newFollowers: Int,
        oldFollowing: Int,
        newFollowing: Int
    ) {
        let content = UNMutableNotificationContent()
        content.title = "📊 @\(username) changed!"
        content.sound = .default

        var changes: [String] = []

        if newFollowers != oldFollowers {
            let delta = newFollowers - oldFollowers
            let sign = delta > 0 ? "+" : ""
            changes.append("Followers: \(formatNumber(oldFollowers))→\(formatNumber(newFollowers)) (\(sign)\(delta))")
        }

        if newFollowing != oldFollowing {
            let delta = newFollowing - oldFollowing
            let sign = delta > 0 ? "+" : ""
            changes.append("Following: \(formatNumber(oldFollowing))→\(formatNumber(newFollowing)) (\(sign)\(delta))")
        }

        content.body = changes.joined(separator: "\n")

        let request = UNNotificationRequest(
            identifier: "insta-\(username)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 10_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return NumberFormatter.localizedString(from: NSNumber(value: n), number: .decimal)
    }
}
