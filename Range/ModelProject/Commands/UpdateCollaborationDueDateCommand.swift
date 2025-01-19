import FirebaseFirestore
import Foundation
import RealmSwift

/// Update dueDateTimestamp for given Collaboration
struct UpdateCollaborationDueDateCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType: [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    var dueDateTimestamp: Date?

    init(collaborationId: String, dueDateTimestamp: Date?) {
        self.collaborationId = collaborationId
        self.dueDateTimestamp = dueDateTimestamp
    }
}

/// Update in local Realm db
extension UpdateCollaborationDueDateCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.dueDateTimestamp = dueDateTimestamp
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationDueDateCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    var functionData: [String: Any?]? {
        [
            "collaborationId": collaborationId,
            FirestoreCollaboration.CodingKeys.dueDateTimestamp.rawValue: dueDateTimestamp
                .map { Int($0.timeIntervalSince1970 * 1000) } as Any,
        ]
    }
}
