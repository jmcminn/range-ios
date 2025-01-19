import FirebaseFirestore
import Foundation
import RealmSwift

/// Update text and set textIsEdited to `true`
struct UpdateCommentTextCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.update: [commentId]]
    }

    let commentId: String
    var text: String
}

extension UpdateCommentTextCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let comment = realm.object(ofType: Comment.self, forPrimaryKey: commentId) else {
            throw ModelError.commentNotFound
        }
        comment.text = text
        // don't mark comment as edited, this is only done by remote command
    }
}

/// Provide data for firebase function call
extension UpdateCommentTextCommand: FirebaseFunctionCommand {
    var functionName: String { "updateComment" }

    var functionData: [String: Any?]? {
        [
            "commentId": commentId,
            "text": text,
        ]
    }
}
