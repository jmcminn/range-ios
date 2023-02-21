import Foundation
import RealmSwift

var _thumbnail0Size: Int = 200
var _thumbnail1Size: Int = 650

/// Used for accessing files in LocalFiles and MediaCache
///
/// Thumbnails have numbers
/// 0 - 200x200>
/// 1 - 650x650>
/// see the [generate thumbnails function repo](https://gitlab.com/range.io/range.io/-/blob/master/modules/firebase-functions-generate-thumbnails/src/generate-thumbnails-from-upload.js#L27)
/// for more details///
struct MediaKey: CustomStringConvertible {
    var projectId: String
    var uploadId: String
    var fileType: Upload.FileType
    var thumbnailNumber: Int?

    /// The path of the file in the Storage
    var storagePath: String {
        "projects/\(projectId)/uploads/\(uploadId)" +
            (thumbnailNumber != nil ? ".thumbnail\(thumbnailNumber!)" : "")
    }

    /// cache key needs the extension so the files are stored with extension and can be opened by QuickLook
    var cacheKey: String { "\(storagePath).\(fileType.rawValue)" }
    /// for logging
    var description: String { cacheKey }

    init(projectId: String, upload: Upload, thumbnailNumber: Int? = nil) {
        self.init(
            projectId: projectId,
            uploadId: upload.id,
            fileType: upload.fileType,
            thumbnailNumber: thumbnailNumber
        )
    }

    init(projectId: String, uploadId: String, fileType: Upload.FileType, thumbnailNumber: Int? = nil) {
        self.projectId = projectId
        self.uploadId = uploadId
        self.fileType = fileType
        self.thumbnailNumber = thumbnailNumber
    }

    /// Create a copy for different thumbnail.
    func forThumbnail(_ newThumbnailNumber: Int?) -> MediaKey {
        var copy = self
        copy.thumbnailNumber = newThumbnailNumber
        return copy
    }
}
