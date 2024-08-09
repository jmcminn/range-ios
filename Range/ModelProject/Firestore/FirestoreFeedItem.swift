import CoreLocation
import Foundation
import OSLog
import RealmSwift

/// Represents the feed item for current user and given project (`projects/<projectId>/participants/<userId>/feedItems` path in Firestore)
/// This document is not saved in the Realm database
struct FirestoreFeedItem: Decodable {
    /// CodingKeys used by Codable as a keys in the encoded form
    enum CodingKeys: String, CodingKey, CaseIterable {
        case action, createdAt, itemId, itemType
    }

    var action: String
    var createdAt: Date
    var itemId: String
    var itemType: String
}
