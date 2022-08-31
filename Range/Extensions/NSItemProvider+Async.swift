import Foundation

/// Extension adding async variant of `NSItemProvider.loadDataRepresentation`
extension NSItemProvider {
    func _asyncLoadDataRepresentation(forTypeIdentifier typeIdentifier: String) async throws -> Data {
        try await withUnsafeThrowingContinuation { continuation in
            self.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data!)
            }
        } as Data
    }
}
