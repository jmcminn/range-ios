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
    /// storage version, optional for backward compatibility (if a pending upload is stored before the storageVersion was introduced for local files)
    @Persisted var storageVersion: String?
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
        storageVersion = mediaKey.storageVersion
    }

    var mediaKey: MediaKey {
        MediaKey.localFilesKey(
            projectId: projectId,
            uploadId: uploadId,
            fileType: fileType,
            annotated: annotated,
            storageVersion: storageVersion ?? "" // empty for backward compatibility
        )
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

    /// If it's the same file, no matter what storage version
    /// ACHTUNG: this still means that multiple PendingUploads can be equal but have different versions of annotations for example
    /// But this is what we want, don't upload intermediate versions if a newer one is added to the pending queue
    static func == (lhs: PendingUpload, rhs: PendingUpload) -> Bool {
        if lhs.projectId != rhs.projectId { return false }
        if lhs.uploadId != rhs.uploadId { return false }
        if lhs.annotated != rhs.annotated { return false }
        return true
    }
}
