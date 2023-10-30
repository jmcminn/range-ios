@testable import Range
import XCTest

extension XCTestCase {
    func _mediaKey(projectId: String, uploadId: String) -> MediaKey {
        MediaKey(projectId: projectId,
                 uploadId: uploadId,
                 fileType: .jpeg, annotated: false, storageVersion: "1", storeInDiskCache: false,
                 isFromLocalFiles: false)
    }
}
