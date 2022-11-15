import FirebaseFirestore
import Foundation
import RealmSwift

/// Update text and set textIsEdited to `true`
struct UpdateCommentTextCommand: Command, Codable, Equatable {
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

/// Apply the `Comment` update in Firestore.
extension UpdateCommentTextCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard let comment = try ctx.getDocument(.comment(commentId), as: FirebaseComment.self)
        else {
            throw FirestoreCommandError.obsolete("comment doesn't exist")
        }
        guard comment.text != text else {
            // do nothing, the text is the same
            return
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [
                FirebaseComment.CodingKeys.text.rawValue: text,
                FirebaseComment.CodingKeys.textIsEdited.rawValue: true,
            ],
            forDocument: .comment(commentId)
        )
    }
}
