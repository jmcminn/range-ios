import FirebaseFirestore
import Foundation
import RealmSwift

struct CreateCollaborationCommentCommand: Command, Codable, Equatable {
    let commentId: String
    var collaborationId: String
    var authorId: String
    var text: String
    var isNote: Bool
}

/// Apply in local Realm db
extension CreateCollaborationCommentCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let collaboration = try realm.object(ofType: Collaboration.self, forPrimaryKey: collaborationId)
            .or(error: ModelError.collaborationNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)

        let comment = Comment(
            id: commentId,
            timestamp: Date(),
            text: text,
            textIsEdited: false,
            isNote: isNote,
            completedTimestamp: nil
        )
        comment.author = author
        realm.add(comment, update: .error)
        collaboration.comments.insert(comment)
    }
}

extension CreateCollaborationCommentCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that collaboration and author exist, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.collaboration(collaborationId)) else {
            throw FirestoreCommandError.obsolete("collaboration doesn't exist")
        }
        guard try ctx.exists(.participant(authorId)) else {
            throw FirestoreCommandError.obsolete("user doesn't exist")
        }
        guard try !ctx.exists(.comment(commentId)) else {
            // already added
            return
        }

        // ------------- WRITES ----------------
        let firestoreObject = FirebaseComment(
            parentId: collaborationId,
            parentType: "Collaboration",
            authorId: authorId,
            timestamp: Timestamp(),
            text: text,
            textIsEdited: false,
            isNote: isNote
        )
        var data = try Firestore.Encoder().encode(firestoreObject)
        data[FirebaseComment.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
        ctx.setData(data, forDocument: .comment(commentId))
    }
}
