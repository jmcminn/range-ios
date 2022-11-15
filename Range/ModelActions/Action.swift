import Foundation
import RealmSwift

/// Lists commands to run for given user action performed for project with given projectId.
struct Action: Codable, CustomDebugStringConvertible {
    /// The projectId for which the commands should be run
    var projectId: String
    /// The command that should be performed in Firestore
    var command: ActionCommand

    var debugDescription: String {
        "projectId: \(projectId), \(command.firestoreCommand)"
    }

    /// Init action for given projectId and command (that should be convertible to ActionCommand)
    init(projectId: String, command: Command) {
        self.projectId = projectId
        self.command = ActionCommand(command)
    }
}
