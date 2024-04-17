import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Comment`
struct DeleteCommentCommand: Command, Codable, Equatable {
    var type: CommandType { .delete } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([commentId]) }

    let commentId: String
}

extension DeleteCommentCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        // fail locally if the comment doesn't exist, this shouldn't really happen
        guard let comment = realm.object(ofType: Comment.self, forPrimaryKey: commentId) else {
            throw ModelError.commentNotFound
        }
        realm.delete(comment)
    }
}

/// Provide data for 'deleteComment' firebase function call
extension DeleteCommentCommand: FirebaseFunctionCommand {
    var functionName: String { "deleteComment" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "commentId": commentId,
        ]
    }
}
