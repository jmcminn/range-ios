import FirebaseFirestore
import Foundation
import RealmSwift

/// Update assignee for given Collaboration(s)
struct UpdateCollaborationAssigneeCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType: [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    var assigneeId: String?

    init(collaborationId: String, assigneeId: String?) {
        self.collaborationId = collaborationId
        self.assigneeId = assigneeId
    }
}

/// Update in local Realm db
extension UpdateCollaborationAssigneeCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        if let assigneeId = assigneeId {
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: assigneeId) else {
                throw ModelError.userNotFound
            }
            collaboration.assignee = user
        } else {
            collaboration.assignee = nil
        }
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationAssigneeCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    var functionData: [String: Any?]? {
        [
            "collaborationId": collaborationId,
            "assigneeId": assigneeId,
        ]
    }
}
