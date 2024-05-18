import FirebaseFirestore
import Foundation
import RealmSwift

/// Update name for given Collaboration
struct UpdateCollaborationNameCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([collaborationId]) }

    let collaborationId: String
    var name: String

    init(collaborationId: String, name: String) {
        self.collaborationId = collaborationId
        self.name = name
    }
}

extension UpdateCollaborationNameCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.name = name
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationNameCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "name": name,
        ]
    }
}
