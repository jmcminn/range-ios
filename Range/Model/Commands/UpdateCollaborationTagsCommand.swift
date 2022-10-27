import Foundation
import RealmSwift

/// Update tags for given Collaboration
struct UpdateCollaborationTagsCommand: Command, Equatable {
    let collaborationId: String
    var tagIds: [String]

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore.
        fatalError("UpdateCollaborationTagsCommand.apply(inRealm:) has not been implemented")
    }
}
