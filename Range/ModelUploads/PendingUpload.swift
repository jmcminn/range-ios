import Foundation
import RealmSwift

/// Object stored in Uploads Realm.
/// Keeps the data about the files that need to be uploaded to Firebase storage
class PendingUpload: Object {
    /// ObjectId is used for id as it can be sorted
    @Persisted(primaryKey: true) var _id: ObjectId
    /// project id
    @Persisted var projectId: String
    /// upload id
    @Persisted var uploadId: String
    /// is it the annotated version of the photo
    @Persisted var annotated: Bool
    /// File type
    @Persisted var fileType: Upload.FileType
    /// Whether this PendingUpload is currently being uploaded
    @Persisted var isUploading: Bool = false
    /// How many times it was tried already
    @Persisted var retryCount: Int = 0
    /// Next attempt if we need to retry. Initially it's nil meaning asap
    @Persisted var nextAttemptAt: TimeInterval? = nil
    /// If failed the error message is kept here for reference
    @Persisted var lastErrorMessage: String?

    /// Init with given mediaKey (which is also a cache key)
    init(_ mediaKey: MediaKey) {
        projectId = mediaKey.projectId
        uploadId = mediaKey.uploadId
        annotated = mediaKey.annotated
        fileType = mediaKey.fileType
    }

    var mediaKey: MediaKey {
        MediaKey.localFilesKey(projectId: projectId, uploadId: uploadId, fileType: fileType, annotated: annotated)
    }

    /// Default initializer required by Realm.
    override init() {
        super.init()
    }

    /// Should this pending uploads be executed at given `time` based on the `retryCount` and `nextAttemptAt`?
    func shouldPerform(at time: TimeInterval) -> Bool {
        // perform if it was not performed yet
        if retryCount == 0 { return true }
        if let nextAttemptAt = nextAttemptAt {
            return time >= nextAttemptAt
        } else {
            // next attempt not scheduled, perform now
            return true
        }
    }

    /// If it's the same file
    static func == (lhs: PendingUpload, rhs: PendingUpload) -> Bool {
        if lhs.projectId != rhs.projectId { return false }
        if lhs.uploadId != rhs.uploadId { return false }
        if lhs.annotated != rhs.annotated { return false }
        if lhs.isUploading != rhs.isUploading { return false }
        return true
    }
}
