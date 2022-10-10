import Foundation
import RealmSwift

/// Update name for given Collaboration
struct UpdateCollaborationNameCommand: Command, Equatable {
    let collaborationId: String
    var name: String

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore.
        fatalError("UpdateCollaborationNameCommand.apply(inRealm:) has not been implemented")
    }
}
