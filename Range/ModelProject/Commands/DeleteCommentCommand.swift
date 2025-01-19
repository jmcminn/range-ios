import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Comment`
struct DeleteCommentCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType: [String]] {
        [.delete: [commentId]]
    }

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

    var functionData: [String: Any?]? {
        ["commentId": commentId]
    }
}
