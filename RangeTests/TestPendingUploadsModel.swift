import Foundation
@testable import Range

/// Test implementation of PendingUploadsModel that does nothing
class TestPendingUploadsModel: PendingUploadsModel {
    override func addPendingUpload(forKey _: MediaKey) async throws {}
}
