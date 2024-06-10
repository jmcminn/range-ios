import FirebaseFirestore
import Foundation
import RealmSwift

/// Update followers for given Collaboration
struct UpdateCollaborationFollowersCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { [collaborationId] }

    let collaborationId: String
    var followerIds: [String]
}

extension UpdateCollaborationFollowersCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let collaboration = realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId) else {
            throw ModelError.collaborationNotFound
        }

        collaboration.followers.removeAll()
        collaboration.addNewFollowers(newFollowerIds: followerIds, realm: realm)
    }
}

/// Provide data for firebase function call
extension UpdateCollaborationFollowersCommand: FirebaseFunctionCommand {
    var functionName: String { "updateCollaboration" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "collaborationId": collaborationId,
            "followers": followerIds
        ]
    }
}
