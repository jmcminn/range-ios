import Foundation

/// Interface for classes to implement model for `PendingUpload`. There's only one real implementation - `FirebasePendingUploadsModel`,
/// but we need an interface for tests.
protocol PendingUploadsModel: AnyObject {
    /// Add data for given key to pending uploads. The image with given cache key should be in the Images.localPhotosCache
    func addPendingUpload(key: String) async throws
}
