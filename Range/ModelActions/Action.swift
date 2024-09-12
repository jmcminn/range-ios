import Foundation
import RealmSwift

/// Lists commands to run for given user action performed for project with given projectId.
struct Action: Codable, CustomDebugStringConvertible {
    /// The projectId for which the commands should be run
    var projectId: String
    /// The command that should be performed in Firestore
    var command: ActionCommand

    var debugDescription: String {
        "projectId: \(projectId), \(command.localCommand)"
    }

    // name to be used in logs
    var name: String {
        String(describing: type(of: command.localCommand))
    }

    // description to be used in logs
    var logDescription: String {
        "projectId: \(projectId), \(name)(operations: \(operationsLogDescription)"
    }
    
    var operationsLogDescription: String {
        command.localCommand.operations.compactMap {
            guard !$0.value.isEmpty else { return nil }
            return "\($0.key):[\($0.value.joined(separator: ","))]"
        }.joined(separator: ", ")
    }

    /// Init action for given projectId and command (that should be convertible to ActionCommand)
    init(projectId: String, command: Command) {
        self.projectId = projectId
        self.command = ActionCommand(command)
    }
}

enum ActionError: Error, LocalizedError {
    // The Action is not recognized by the PendingActionsModel (in theory it can only happen during development)
    case notSupported(String)

    public var errorDescription: String? {
        switch self {
        case let .notSupported(details): return "The command is not supported: \(details)"
        }
    }
}

