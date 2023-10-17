import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import RealmSwift

enum CommandType: Codable {
    case create, update, delete
}

/// Just a marker interface for being a command = something that can be `run` by `ProjectModel`
/// This is implemented by commands that are run after user actions (so implement local and firestore updates)
/// Not all commands are marked with this protocol - the ones that only run locally in response to update/create event
/// received from Firestore are only marked as LocalCommand and run by `ProjectModelFirestoreSync`
protocol Command {
    /// the type of the command
    var type: CommandType { get }
    /// the ids of objects that are the target of the command (the object(s) being created/updated/deleted)
    var targetIds: [String] { get }
}

/// A protocol for local commands - command objects for performing changes on the Realm db.
protocol LocalCommand: Command {
    /// Apply the changes locally in given Realm. Will be performed in a realm write transaction
    func apply(inRealm realm: Realm) throws
}

/// A protocol for commands that add files to PendingUploadsModel
protocol PendingUploadCommand: Command {
    /// Add pending uploads to given PendingUploadsModel
    func addPendingUploads(_: PendingUploadsModel) async throws
}

enum FirestoreCommandError: Error, LocalizedError {
    // not applied because some preconditions are not met and will not be met,
    // the command should be ignored (removed from pending)
    case obsolete(String)

    public var errorDescription: String? {
        switch self {
        case let .obsolete(details): return "The command is obsolete: \(details)"
        }
    }
}

/// A protocol for commands that can be applied to Firestore.
protocol FirestoreCommand {
    /// Apply the changes in a Firestore transaction
    ///
    /// This function should throw a special FirestoreCommandError.obsolete error if it decided it's not doing any updates
    /// because it's obsolete for some reason (for example it wanted to update the name for collaboration that doesn't exist anymore).
    /// This could have been achieved by just doing nothing but throwing this error makes it more explicit and allows for some special
    /// behavior (like notifying the user...)
    func apply(inFirestore context: FirestoreCommandContext) throws
}
