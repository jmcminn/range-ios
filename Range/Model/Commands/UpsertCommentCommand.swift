import Foundation
import RealmSwift

/// Local command to upsert the `Comment` into Realm db
struct UpsertCommentCommand: LocalCommand, Equatable {
    let commentId: String
    var parentType: String
    var parentId: String
    var authorId: String
    var timestamp: Date
    var text: String
    var textIsEdited: Bool
    var isNote: Bool
    var completedById: String?
    var completedTimestamp: Date?

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
