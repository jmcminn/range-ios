
import Foundation
@testable import Range

/// Test implementation of PendingUploadsModel that does nothing
class TestPendingUploadsModel: PendingUploadsModel {
    func addPendingUpload(_: Data, key _: String) async throws {}
}
