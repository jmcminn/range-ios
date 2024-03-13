import Foundation
import Knock

extension Knock.FeedItem {
    var actionUrl: URL? {
        guard let path = blocks.first(where: { $0.name == "action_url" })?.rendered
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        return URL(string: "https://range.io\(path)")
    }
}
