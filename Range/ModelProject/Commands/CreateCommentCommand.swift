import FirebaseFirestore
import Foundation
import RealmSwift

struct CreateCommentCommand: Command, Codable, Equatable {
    var operations: [CommandOperationType : [String]] {
        [.create: [commentId]]
    }

    let commentId: String
    var parentId: String
    var parentType: String
    var authorId: String
    var text: String
    var isNote: Bool

    fileprivate init(
        commentId: String,
        parentId: String,
        parentType: String,
        authorId: String,
        text: String,
        isNote: Bool
    ) {
        self.commentId = commentId
        self.parentId = parentId
        self.parentType = parentType
        self.authorId = authorId
        self.text = text
        self.isNote = isNote
    }

    static func collaborationComment(collaborationId: String, authorId: String, text: String,
                                     isNote: Bool) -> CreateCommentCommand
    {
        CreateCommentCommand(
            commentId: generateRealmId(),
            parentId: collaborationId,
            parentType: "Collaboration",
            authorId: authorId,
            text: text,
            isNote: isNote
        )
    }

    static func uploadComment(uploadId: String, authorId: String, text: String) -> CreateCommentCommand {
        CreateCommentCommand(
            commentId: generateRealmId(),
            parentId: uploadId,
            parentType: "Upload",
            authorId: authorId,
            text: text,
            isNote: false
        )
    }
}

/// Apply in local Realm db
extension CreateCommentCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        let author = try realm.object(ofType: Participant.self, forPrimaryKey: authorId)
            .or(error: ModelError.userNotFound)

        let comment = Comment(
            id: commentId,
            createdAt: Date(),
            lastUpdatedAt: Date(),
            text: text,
            textIsEdited: false,
            isNote: isNote,
            completedTimestamp: nil
        )
        comment.author = author
        realm.add(comment, update: .error)

        if parentType == "Collaboration" {
            let collaboration = try realm.object(ofType: Collaboration.self, forPrimaryKey: parentId)
                .or(error: ModelError.collaborationNotFound)
            collaboration.comments.insert(comment)
        } else {
            let upload = try realm.object(ofType: Upload.self, forPrimaryKey: parentId)
                .or(error: ModelError.uploadNotFound)
            upload.comments.insert(comment)
        }
    }
}

/// Provide data for the firebase function call
extension CreateCommentCommand: FirebaseFunctionCommand {
    var functionName: String { "createComment" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "commentId": commentId,
            "parentType": parentType,
            "parentId": parentId,
            "text": text,
            "isNote": isNote,
        ]
    }
}
