@testable import Range
import XCTest

final class MediaKeyTest: XCTestCase {
    /// Test that LocalMedia key is returned for files marked as local
    func testMediaKeyFor_LocalFiles() throws {
        /// Upload with main and annotated images in LocalFiles
        let upload = Upload(placeholderId: "u1")
        upload.fileType = .jpeg
        upload.localStorageVersion.setMainToLocalFile(annotated: false)
        upload.localStorageVersion.setMainToLocalFile(annotated: true)

        /// All media keys are from LocalFiles
        for annotated in [true, false] {
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: annotated),
                MediaKey.localFilesKey(projectId: "p1", uploadId: "u1", fileType: .jpeg, annotated: annotated)
            )
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: false, thumbnailNumber: 0),
                MediaKey.localFilesKey(
                    projectId: "p1",
                    uploadId: "u1",
                    fileType: .jpeg,
                    annotated: false,
                    thumbnailNumber: 0
                )
            )
        }
    }

    /// Test that StorageMediaKey is returned for files copied from LocalFiles
    func testMediaKey_LocalFilesMovedToMediaCache() {
        /// Upload with main and annotated images copied from LocalFiles, no firestore storageVersion
        let upload = Upload(placeholderId: "u1")
        upload.fileType = .jpeg
        upload.localStorageVersion.setMain(annotated: false, value: "1234")
        upload.localStorageVersion.setMain(annotated: true, value: "1234")

        /// All media keys are StorageMediaKeys with main file storage version
        for annotated in [true, false] {
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: annotated),
                MediaKey.mediaCacheKey(
                    projectId: "p1",
                    uploadId: "u1",
                    fileType: .jpeg,
                    annotated: annotated,
                    storageVersion: "1234"
                )
            )
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: annotated, thumbnailNumber: 0),
                MediaKey.mediaCacheKey(
                    projectId: "p1",
                    uploadId: "u1",
                    fileType: .jpeg,
                    annotated: annotated,
                    thumbnailNumber: 0,
                    storageVersion: "1234"
                )
            )
        }

        // older storageVersion added to upload, still prefer the copy from LocalFiles
        upload.storageVersion.setMain(annotated: true, value: "1230")
        XCTAssertEqual(
            MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true, thumbnailNumber: 0),
            MediaKey.mediaCacheKey(
                projectId: "p1",
                uploadId: "u1",
                fileType: .jpeg,
                annotated: true,
                thumbnailNumber: 0,
                storageVersion: "1234"
            )
        )

        // same storageVersion added to upload, still prefer the copy from LocalFiles
        upload.storageVersion.setMain(annotated: true, value: "1230")
        XCTAssertEqual(
            MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true, thumbnailNumber: 0),
            MediaKey.mediaCacheKey(
                projectId: "p1",
                uploadId: "u1",
                fileType: .jpeg,
                annotated: true,
                thumbnailNumber: 0,
                storageVersion: "1234"
            )
        )

        // storage version has now newer version, prefer the storage version, but thumbnail is not yet there
        upload.storageVersion.setMain(annotated: true, value: "1240")
        XCTAssertEqual(
            MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true),
            MediaKey.mediaCacheKey(
                projectId: "p1",
                uploadId: "u1",
                fileType: .jpeg,
                annotated: true,
                storageVersion: "1240"
            )
        )
        XCTAssertNil(MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true, thumbnailNumber: 0))

        // thumbnail storage version added
        upload.storageVersion.set(annotated: true, thumbnail: 0, value: "111")
        XCTAssertEqual(
            MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true, thumbnailNumber: 0),
            MediaKey.mediaCacheKey(
                projectId: "p1",
                uploadId: "u1",
                fileType: .jpeg,
                annotated: true,
                thumbnailNumber: 0,
                storageVersion: "111"
            )
        )
    }

    /// No info about localStorageVersion
    func testMediaKey_noLocalStorageVersion() {
        /// Upload with no storage version
        let upload = Upload(placeholderId: "u1")
        upload.fileType = .jpeg

        // fallback to "unknown" storage version for not annotated
        XCTAssertEqual(
            MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: false, thumbnailNumber: 0),
            MediaKey.mediaCacheKey(
                projectId: "p1",
                uploadId: "u1",
                fileType: .jpeg,
                annotated: false,
                thumbnailNumber: 0,
                storageVersion: "unknown",
                storeInDiskCache: false
            )
        )
        // nil for not annotated
        XCTAssertNil(MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: true, thumbnailNumber: 0))

        // storageVersion populated
        upload.storageVersion.setMain(annotated: false, value: "111")
        upload.storageVersion.set(annotated: false, thumbnail: 0, value: "222")
        upload.storageVersion.setMain(annotated: true, value: "111")
        upload.storageVersion.set(annotated: true, thumbnail: 0, value: "222")

        for annotated in [true, false] {
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: annotated),
                MediaKey.mediaCacheKey(
                    projectId: "p1",
                    uploadId: "u1",
                    fileType: .jpeg,
                    annotated: annotated,
                    storageVersion: "111"
                )
            )
            XCTAssertEqual(
                MediaKey.mediaKey(projectId: "p1", upload: upload, annotated: annotated, thumbnailNumber: 0),
                MediaKey.mediaCacheKey(
                    projectId: "p1",
                    uploadId: "u1",
                    fileType: .jpeg,
                    annotated: annotated,
                    thumbnailNumber: 0,
                    storageVersion: "222"
                )
            )
        }
    }
}
