import FirebaseFirestore
import Foundation
import RealmSwift

/// Update status for given Collaboration
struct UpdateCollaborationStatusCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { [collaborationId] }

    let collaborationId: String
    var statusId: String

    init(collaborationId: String, statusId: String) {
        self.collaborationId = collaborationId
        self.statusId = statusId
    }
}

extension UpdateCollaborationStatusCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        guard let status = realm.object(ofType: Status.self, forPrimaryKey: statusId) else {
            throw ModelError.statusNotFound
        }
        collaboration.status = status
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationStatusCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "statusId": statusId,
        ]
    }
}
