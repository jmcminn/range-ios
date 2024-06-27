import FirebaseFirestore
import Foundation
import RealmSwift

/// Update completedBy, completedTimestamp (serverside timestamp) for given note (comment)
struct UpdateNoteCompletedCommand: Command, Codable, Equatable {
    var type: CommandType { .update } // don't make it a stored property, so it's not encoded
    var targetIds: [String] { .init([noteId]) }

    let noteId: String
    var completedById: String?
    var completedTimestamp: Date?
}

extension UpdateNoteCompletedCommand: LocalCommand {
    func apply(inRealm realm: Realm) throws {
        guard let comment = realm.object(ofType: Comment.self, forPrimaryKey: noteId) else {
            throw ModelError.commentNotFound
        }
        comment.completedTimestamp = completedTimestamp
        if let completedById {
            guard let user = realm.object(ofType: Participant.self, forPrimaryKey: completedById) else {
                throw ModelError.userNotFound
            }
            comment.completedBy = user
        } else {
            comment.completedBy = nil
        }
    }
}

/// Provide data for firebase function call
extension UpdateNoteCompletedCommand: FirebaseFunctionCommand {
    var functionName: String { "updateComment" }

    func functionData(_ projectId: String) -> Any? {
        [
            "projectId": projectId,
            "commentId": noteId,
            "completedTimestamp": completedTimestamp.map { Int($0.timeIntervalSince1970 * 1000) } as Any,
        ]
    }
}
