import Foundation
import RealmSwift

/// Update dueDateTimestamp for given Collaboration
struct UpdateCollaborationDueDateCommand: Command, Equatable {
    let collaborationId: String
    var dueDateTimestamp: TimeInterval?

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore.
        fatalError("UpdateCollaborationDueDateCommand.apply(inRealm:) has not been implemented")
    }
}
