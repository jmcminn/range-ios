
import Foundation
@testable import Range

/// Test implementation of PendingUploadsModel that does nothing
class TestPendingUploadsModel: PendingUploadsModel {
    func addPendingUpload(key _: String) async throws {}
}
