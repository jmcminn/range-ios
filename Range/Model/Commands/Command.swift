import Foundation
import RealmSwift

/// A protocol for commands - command objects for performing changes on the Realm db.
/// Some commands have extensions to apply them to the backend.
protocol Command {
    /// Apply the changes locally in given Realm. Will be performed in a realm write transaction
    func apply(inRealm realm: Realm) throws
}
