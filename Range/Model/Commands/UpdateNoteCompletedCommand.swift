import Foundation
import RealmSwift

/// Update completedBy, completedTimestamp for given note (comment)
struct UpdateNoteCompletedCommand: Command, Equatable {
    let noteId: String
    var completedById: String?
    var completedTimestamp: TimeInterval?

    func apply(inRealm _: Realm) throws {
        // this command is not run locally, only applied to firestore.
        fatalError("UpdateNoteCompletedCommand.apply(inRealm:) has not been implemented")
    }
}
