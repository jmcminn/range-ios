import Foundation

/// Interface for classes to implement model for `PendingUpload`. There's only one real implementation - `FirebasePendingUploadsModel`,
/// but we need an interface for tests.
class PendingUploadsModel: ObservableObject {
    /// Add data for given key to pending uploads. The image with given key should be in the LocalFiles
    func addPendingUpload(forKey: MediaKey) async throws {
        fatalError("function to be implemented by subclasses")
    }
    
    init() {
        hasPendingUploads = false
        networkConditionsMet = false
    }

    @Published var hasPendingUploads: Bool
    @Published var networkConditionsMet: Bool
}
