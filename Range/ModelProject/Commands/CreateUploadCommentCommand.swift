import FirebaseFirestore
import Foundation
import RealmSwift

struct CreateUploadCommentCommand: Command, Codable, Equatable {
    var type: CommandType { .create } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([commentId]) }

    let commentId: String
    var uploadId: String
    var authorId: String
    var text: String
}

/// Apply in local Realm db
extension CreateUploadCommentCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let upload = try realm.object(ofType: Upload.self, forPrimaryKey: uploadId)
            .or(error: ModelError.uploadNotFound)
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)

        let comment = Comment(
            id: commentId,
            timestamp: Date(),
            text: text,
            textIsEdited: false,
            isNote: false,
            completedTimestamp: nil
        )
        comment.author = author
        realm.add(comment, update: .error)
        upload.comments.insert(comment)
    }
}

extension CreateUploadCommentCommand: FirestoreCommand {
    func apply(inFirestore ctx: FirestoreCommandContext) throws {
        // ------------- READS -----------------
        // check that upload and author exist, otherwise abort (the command cannot be applied)
        guard try ctx.exists(.upload(uploadId)) else {
            throw FirestoreCommandError.obsolete("upload doesn't exist")
        }
        guard try ctx.exists(.participant(authorId)) else {
            throw FirestoreCommandError.obsolete("user doesn't exist")
        }
        guard try !ctx.exists(.comment(commentId)) else {
            // already added
            return
        }

        // ------------- WRITES ----------------
        let firestoreObject = FirestoreComment(
            parentId: uploadId,
            parentType: "Upload",
            authorId: authorId,
            timestamp: Timestamp(),
            text: text,
            textIsEdited: false,
            isNote: false
        )
        var data = try Firestore.Encoder().encode(firestoreObject)
        data[FirestoreComment.CodingKeys.timestamp.rawValue] = FieldValue.serverTimestamp()
        ctx.setData(data, forDocument: .comment(commentId))
    }
}
