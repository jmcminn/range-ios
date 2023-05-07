import FirebaseFirestore
import Foundation
import RealmSwift

/// Delete the `Comment`
struct DeleteCommentCommand: Command, Codable, Equatable {
    var type: CommandType { .delete } // don't make it a stored property, so it's not encoded
    var targetIds: Set<String> { .init([commentId]) }

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

extension DeleteCommentCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise it's already removed
        guard try ctx.exists(.comment(commentId)) else { return }

        // ------------- WRITES ----------------
        ctx.deleteDocument(.comment(commentId))
    }
}
