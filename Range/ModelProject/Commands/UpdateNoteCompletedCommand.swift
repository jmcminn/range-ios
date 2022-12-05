import FirebaseFirestore
import Foundation
import RealmSwift

/// Update completedBy, completedTimestamp (serverside timestamp) for given note (comment)
struct UpdateNoteCompletedCommand: Command, Codable, Equatable {
    let noteId: String
    var completedById: String?
}

extension UpdateNoteCompletedCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let comment = realm.object(ofType: Comment.self, forPrimaryKey: noteId) else {
            throw ModelError.commentNotFound
        }
        if let completedById = completedById {
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: completedById) else {
                throw ModelError.userNotFound
            }
            comment.completedBy = user
            // do not set completedTimestamp as this is only done by the remote command
        } else {
            comment.completedBy = nil
            comment.completedTimestamp = nil
        }
    }
}

/// Apply the `Comment` update in Firestore.
extension UpdateNoteCompletedCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that target exists, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.comment(noteId)) else {
            throw FirestoreCommandError.obsolete("comment doesn't exist")
        }
        if let completedById = completedById {
            guard try ctx.exists(.participant(completedById)) else {
                throw FirestoreCommandError.obsolete("user doesn't exist")
            }
        }

        // ------------- WRITES ----------------
        ctx.updateData(
            [
                FirestoreComment.CodingKeys.completedById.rawValue: completedById ?? FieldValue.delete(),
                FirestoreComment.CodingKeys.completedTimestamp.rawValue: completedById != nil
                    ? FieldValue.serverTimestamp()
                    : FieldValue.delete(),
            ],
            forDocument: .comment(noteId)
        )
    }
}
