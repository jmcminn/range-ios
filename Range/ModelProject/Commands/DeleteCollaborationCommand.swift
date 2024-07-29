import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Collaboration`
struct DeleteCollaborationCommand: Command, Codable, Equatable {
    var type: CommandType { .delete } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([collaborationId]) }

    let collaborationId: String
}

extension DeleteCollaborationCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        // fail locally if the collaboration doesn't exist, this shouldn't really happen
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }
        guard let geometry = collaboration.geometry.first else {
            throw ModelError.geometryNotFound
        }
        realm.delete(collaboration.comments)
        realm.delete(collaboration.updates)
        collaboration.uploads.forEach { upload in
            realm.delete(upload.comments)
        }
        realm.delete(collaboration.uploads)
        realm.delete(geometry)
        realm.delete(collaboration)
    }
}

/// Provide data for firebase function call
extension DeleteCollaborationCommand: FirebaseFunctionCommand {
    var functionName: String { "deleteCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
        ]
    }
}
