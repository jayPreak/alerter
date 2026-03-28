import Foundation

struct InstagramProfile {
    let username: String
    let followers: Int
    let following: Int
    let posts: Int
}

enum ScraperError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case parseError
    case profileNotFound
    case rateLimited
    case privateAccount

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid Instagram URL"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .parseError: return "Could not parse profile data"
        case .profileNotFound: return "Profile not found"
        case .rateLimited: return "Rate limited by Instagram. Try again later."
        case .privateAccount: return "This account is private"
        }
    }
}

actor InstagramScraper {
    static let shared = InstagramScraper()

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral // No disk cache — saves storage & memory
        config.timeoutIntervalForRequest = 10
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        ]
        self.session = URLSession(configuration: config)
    }

    func fetchProfile(username: String) async throws -> InstagramProfile {
        let cleanUsername = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://www.instagram.com/\(cleanUsername)/") else {
            throw ScraperError.invalidURL
        }

        // Only download first ~50KB — meta tags with counts are in <head>, no need for the full page
        var request = URLRequest(url: url)
        request.addValue("bytes=0-51200", forHTTPHeaderField: "Range")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ScraperError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScraperError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200, 206: break // 206 = partial content from Range header
        case 404: throw ScraperError.profileNotFound
        case 429: throw ScraperError.rateLimited
        default:
            if httpResponse.statusCode >= 400 {
                throw ScraperError.networkError(URLError(.badServerResponse))
            }
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw ScraperError.parseError
        }

        return try parseHTML(html, username: cleanUsername)
    }

    private func parseHTML(_ html: String, username: String) throws -> InstagramProfile {
        // Try parsing from meta description tag
        // Format: "X Followers, Y Following, Z Posts - ..."
        if let profile = parseMetaDescription(html, username: username) {
            return profile
        }

        // Try parsing from og:description
        if let profile = parseOGDescription(html, username: username) {
            return profile
        }

        // Try parsing from embedded JSON data
        if let profile = parseEmbeddedJSON(html, username: username) {
            return profile
        }

        throw ScraperError.parseError
    }

    private func parseMetaDescription(_ html: String, username: String) -> InstagramProfile? {
        // Match: <meta name="description" content="X Followers, Y Following, Z Posts ..."/>
        guard let match = html.range(of: #"<meta\s+name="description"\s+content="([^"]+)""#, options: .regularExpression) else {
            return nil
        }

        let content = String(html[match])
        return extractCounts(from: content, username: username)
    }

    private func parseOGDescription(_ html: String, username: String) -> InstagramProfile? {
        guard let match = html.range(of: #"<meta\s+property="og:description"\s+content="([^"]+)""#, options: .regularExpression) else {
            return nil
        }

        let content = String(html[match])
        return extractCounts(from: content, username: username)
    }

    private func parseEmbeddedJSON(_ html: String, username: String) -> InstagramProfile? {
        // Look for edge_followed_by and edge_follow counts in embedded JSON
        let followerPattern = #""edge_followed_by"\s*:\s*\{\s*"count"\s*:\s*(\d+)"#
        let followingPattern = #""edge_follow"\s*:\s*\{\s*"count"\s*:\s*(\d+)"#
        let postsPattern = #""edge_owner_to_timeline_media"\s*:\s*\{\s*"count"\s*:\s*(\d+)"#

        guard let followersMatch = html.range(of: followerPattern, options: .regularExpression),
              let followingMatch = html.range(of: followingPattern, options: .regularExpression) else {
            return nil
        }

        let followersStr = String(html[followersMatch])
        let followingStr = String(html[followingMatch])

        guard let followers = extractNumber(from: followersStr),
              let following = extractNumber(from: followingStr) else {
            return nil
        }

        var posts = 0
        if let postsMatch = html.range(of: postsPattern, options: .regularExpression) {
            let postsStr = String(html[postsMatch])
            posts = extractNumber(from: postsStr) ?? 0
        }

        return InstagramProfile(username: username, followers: followers, following: following, posts: posts)
    }

    private func extractCounts(from text: String, username: String) -> InstagramProfile? {
        // Parse numbers like "1,234" or "1.2M" or "12K"
        let pattern = #"([\d,\.]+[KMB]?)\s+Followers?,\s*([\d,\.]+[KMB]?)\s+Following,\s*([\d,\.]+[KMB]?)\s+Posts?"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }

        guard match.numberOfRanges >= 4,
              let followersRange = Range(match.range(at: 1), in: text),
              let followingRange = Range(match.range(at: 2), in: text),
              let postsRange = Range(match.range(at: 3), in: text) else {
            return nil
        }

        let followers = parseCount(String(text[followersRange]))
        let following = parseCount(String(text[followingRange]))
        let posts = parseCount(String(text[postsRange]))

        return InstagramProfile(username: username, followers: followers, following: following, posts: posts)
    }

    private func parseCount(_ str: String) -> Int {
        let cleaned = str.replacingOccurrences(of: ",", with: "")
        let upper = cleaned.uppercased()

        if upper.hasSuffix("K") {
            let num = Double(upper.dropLast()) ?? 0
            return Int(num * 1_000)
        } else if upper.hasSuffix("M") {
            let num = Double(upper.dropLast()) ?? 0
            return Int(num * 1_000_000)
        } else if upper.hasSuffix("B") {
            let num = Double(upper.dropLast()) ?? 0
            return Int(num * 1_000_000_000)
        }

        return Int(cleaned) ?? 0
    }

    private func extractNumber(from text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)"#),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[range])
    }
}
