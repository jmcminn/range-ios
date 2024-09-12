import FirebaseFirestore
import Foundation
import RealmSwift

/// Update description for given Collaboration
struct UpdateCollaborationDescriptionCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [collaborationId]]
    }

    let collaborationId: String
    var collaborationDescription: String?

    init(collaborationId: String, description: String?) {
        self.collaborationId = collaborationId
        collaborationDescription = description
    }
}

extension UpdateCollaborationDescriptionCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        collaboration.collaborationDescription = collaborationDescription
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationDescriptionCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            FirestoreCollaboration.CodingKeys.descriptionString.rawValue: collaborationDescription,
        ]
    }
}
