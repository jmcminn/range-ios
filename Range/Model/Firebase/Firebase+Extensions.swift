import Firebase
import FirebaseDatabaseSwift

/// Some helper methods for Firebase DatabaseReference
extension DatabaseReference {
    /// Wraps observeSingleEvent in an async method that returns the DataSnapshot or throws
    func _observeSingleEvent(_ eventType: DataEventType) async throws -> DataSnapshot {
        try await withUnsafeThrowingContinuation { continuation in
            observeSingleEvent(of: eventType) { snapshot in
                continuation.resume(returning: snapshot)
            } withCancel: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    /// Wraps observe to run the closure on the provided queue
    /// Additionally make the eventType parameter variadic, so a closure can be attached to multiple event types.
    func _observe(_ eventTypes: DataEventType..., on queue: DispatchQueue,
                  _ closure: @escaping (DataEventType, DataSnapshot) -> Void)
    {
        for eventType in eventTypes {
            observe(eventType) { dataSnapshot in
                queue.async {
                    closure(eventType, dataSnapshot)
                }
            }
        }
    }
}

extension DataEventType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .childAdded: return "added"
        case .childRemoved: return "removed"
        case .childChanged: return "changed"
        case .childMoved: return "moved"
        case .value: return "value"
        @unknown default: return "unknown"
        }
    }
}
