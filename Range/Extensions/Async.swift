import Foundation
import RealmSwift

/// Runs given closure on given queue as an async function
func _asyncOnQueue<T>(queue: DispatchQueue, _ closure: @escaping () throws -> T) async throws -> T {
    try await withUnsafeThrowingContinuation { continuation in
        queue.async {
            do {
                continuation.resume(returning: try closure())
            } catch {
                continuation.resume(throwing: error)
            }
        }
    } as T
}

/// Runs given closure on the writeQueue in the writeRealm transaction as an async function
func _asyncRealmWriteOnQueue<T>(queue: DispatchQueue, realm: Realm,
                                _ closure: @escaping (Realm) throws -> T) async throws -> T
{
    try await _asyncOnQueue(queue: queue) {
        try realm.write {
            try closure(realm)
        }
    }
}
