import Foundation
import RealmSwift

/// Update text and set textIsEdited to `true`
struct UpdateCommentTextCommand: Command, Equatable {
    let commentId: String
    var text: String

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore.
        fatalError("UpdateCommentTextCommand.apply(inRealm:) has not been implemented")
    }
}
