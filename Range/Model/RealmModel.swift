import Foundation
import RealmSwift

/// convenience function for generating new realm id
func generateRealmId() -> String {
    UUID().uuidString.lowercased()
}

/// For providers of LocalCommands for given target object id
typealias RealmModelLocalCommandsProvider = (String) -> [LocalCommand]

/// To be adopted by classes implementing model based on Realm local db.
/// By adopting this protocol the model gets the `write` function to write to Realm and also `sync` function to sync firestore changes to model.
protocol RealmModel: NSObject {
    /// Background serial queue to perform write operations.
    var writeQueue: DispatchQueue { get }
    /// Realm operating on `writeQueue`, initialized on model start
    var writeRealm: Realm! { get }
    /// For models that support local updates this provider provides local updates (not yet applied remotely) for given object id
    var localCommandsProvider: RealmModelLocalCommandsProvider? { get }
}

extension RealmModel {
    /// Runs given closure on the writeQueue in the writeRealm transaction as an async function
    func write(_ closure: @escaping (Realm) throws -> Void) async throws {
        try await _asyncOnQueue(queue: writeQueue) { [self] in
            // at this point writeRealm is set or it threw an error
            try writeRealm!.write {
                try closure(writeRealm!)
            }
        }
    }
}
