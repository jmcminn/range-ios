import Foundation
import RealmSwift

struct AddCommentCommand: Command {
    let commentId: String
    let parentType: String
    let parentId: String
    let authorId: String
    let timestamp: TimeInterval
    let text: String
    let isCompleted: Bool?

    func applyLocally(inRealm realm: Realm) throws {
        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let author = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: authorId)
        let comment = Comment(id: commentId, timestamp: timestamp, text: text, isCompleted: isCompleted)
        comment.author = author
        realm.add(comment, update: .modified)
        collaboration.comments.insert(comment)
    }
}
