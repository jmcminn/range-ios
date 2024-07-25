import Foundation
import RealmSwift

/// Realm object for local project metadata (not directly mapped from Firestore)
class ProjectMetadata: Object, WithId {
    
    static let metadataId = "_projectMetadata"
    
    /// Primary key
    @Persisted(primaryKey: true) var id: String = ProjectMetadata.metadataId
    /// The timestamp when the project collaboration level data was last updated from getAllDataForProject or feed
    @Persisted var feedLastUpdatedTimestamp: Date?

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Initializer to init all the fields of object.
    init(feedLastUpdatedTimestamp: Date?) {
        super.init()
        self.feedLastUpdatedTimestamp = feedLastUpdatedTimestamp
    }
}
