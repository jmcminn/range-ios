import Foundation
import RealmSwift

struct AddCommentCommand: Command, Equatable {
    let commentId: String
    var parentType: String
    var parentId: String
    var authorId: String
    var timestamp: TimeInterval
    var text: String
    var isCompleted: Bool?

    func apply(inRealm realm: Realm) throws {
        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let comment = Comment(id: commentId, timestamp: timestamp, text: text, isCompleted: isCompleted)
        comment.author = author
        realm.add(comment, update: .modified)
        collaboration.comments.insert(comment)
    }
}
