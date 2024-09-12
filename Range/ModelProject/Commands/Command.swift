import FirebaseFirestore
import FirebaseFirestoreSwift
import Foundation
import RealmSwift

enum CommandOperationType: Codable {
    case create, update, delete
}

/// Just a marker interface for being a command = something that can be `run` by `ProjectModel`
/// This is implemented by commands that are run after user actions (so implement local and firestore updates)
/// Not all commands are marked with this protocol - the ones that only run locally in response to update/create event
/// received from Firestore are only marked as LocalCommand and run by `ProjectModelFirestoreSync`
protocol Command {
    /// the ids of objects that are created/updated/deleted by given Command
    /// A command can for example update the collaboration tags, in which case this will be:
    /// {
    ///   .update: [<collaborationId>],
    ///   .create: [<list of newly created tag ids>]
    /// }
    var operations: [CommandOperationType: [String]] { get }
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

/// A protocol for commands that can be applied by calling a Firebase callable function
protocol FirebaseFunctionCommand {
    /// The name of the function to be called
    var functionName: String { get }
    /// Parameters to be passed to function (for given projectId)
    func functionData(_ projectId: String) -> Any?
}
