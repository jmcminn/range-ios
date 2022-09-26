import Foundation
import RealmSwift

/// Add or update the `Comment`.
struct AddCommentCommand: Command, Equatable {
    let commentId: String
    var parentType: String
    var parentId: String
    var authorId: String
    var timestamp: TimeInterval
    var text: String
    var textIsEdited: Bool
    var isNote: Bool
    var completedById: String?
    var completedTimestamp: TimeInterval?

    func apply(inRealm realm: Realm) throws {
        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let comment = Comment(
            id: commentId,
            timestamp: timestamp,
            text: text,
            textIsEdited: textIsEdited,
            isNote: isNote,
            completedTimestamp: completedTimestamp
        )
        comment.author = author
        if let completedById = completedById {
            comment.completedBy = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: completedById)
        }
        realm.add(comment, update: .modified)
        collaboration.comments.insert(comment)
    }
}
