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
struct MediaKey: CustomStringConvertible, Equatable, Codable {
    let projectId: String
    let uploadId: String
    let fileType: Upload.FileType
    /// Whether to show the annotated or the original photo, only used for images.
    let annotated: Bool
    /// optional thumbnail number (main file if nil)
    private(set) var thumbnailNumber: Int?
    /// Storage version (required for MediaCache, nil for LocalFiles)
    let storageVersion: String?
    /// Flag to decide if the file should be stored in disk cache (for backward compatibility we may have files that have no storageVersion,
    /// we still want to display them, but we'll store them in memory cache only, as disk cache is storageVersion based)
    /// Only for MediaCache keys (isFromLocalFiles = false)
    let storeInDiskCache: Bool
    /// Is the file from LocalFiles (true) or MediaCache (false)
    var isFromLocalFiles: Bool { storageVersion == nil }
    /// cache key needs the extension so the files are stored with extension and can be opened by QuickLook
    var cacheKey: String {
        if let storageVersion = storageVersion {
            return "\(storagePath).\(storageVersion).\(fileType.rawValue)"
        } else {
            return "\(storagePath).\(fileType.rawValue)"
        }
    }

    /// The path under which the file should be stored in Storage
    var storagePath: String {
        "projects/\(projectId)/uploads/\(uploadId)" +
            (annotated ? ".annotated" : "") +
            (thumbnailNumber != nil ? ".thumbnail\(thumbnailNumber!)" : "")
    }

    /// for logging
    var description: String { cacheKey }

    init(
        projectId: String,
        uploadId: String,
        fileType: Upload.FileType,
        annotated: Bool,
        thumbnailNumber: Int? = nil,
        storageVersion: String?,
        storeInDiskCache: Bool
    ) {
        self.projectId = projectId
        self.uploadId = uploadId
        self.fileType = fileType
        self.annotated = annotated
        self.thumbnailNumber = thumbnailNumber
        self.storageVersion = storageVersion
        self.storeInDiskCache = storeInDiskCache
    }

    /// Create a copy for different thumbnail
    /// This is only supported for LocalFiles as thumbnail for MediaCache needs access to storage version so cannot be constructed
    /// based on thumbnail number only
    func forThumbnail(_ newThumbnailNumber: Int?) -> MediaKey {
        assert(isFromLocalFiles, "Can only create a copy of MediaKey with new thumbnail number for LocalFiles")
        guard isFromLocalFiles
        else { fatalError("Can only create a copy of MediaKey with new thumbnail number for LocalFiles") }
        var copy = self
        copy.thumbnailNumber = newThumbnailNumber
        return copy
    }
}

/// Factory functions
extension MediaKey {
    /// Create MediaKey for LocalFiles access
    static func localFilesKey(
        projectId: String,
        uploadId: String,
        fileType: Upload.FileType,
        annotated: Bool,
        thumbnailNumber: Int? = nil
    ) -> MediaKey {
        MediaKey(
            projectId: projectId,
            uploadId: uploadId,
            fileType: fileType,
            annotated: annotated,
            thumbnailNumber: thumbnailNumber,
            storageVersion: nil,
            storeInDiskCache: false
        )
    }

    /// Factory function for keys that are to be handled by MediaCache. If the file can either be local (created on this device) or not, then
    /// use the `mediaKey` function to obtain a proper key.
    static func mediaCacheKey(
        projectId: String,
        uploadId: String,
        fileType: Upload.FileType,
        annotated: Bool,
        thumbnailNumber: Int? = nil,
        storageVersion: String,
        storeInDiskCache: Bool = true
    ) -> MediaKey {
        MediaKey(
            projectId: projectId,
            uploadId: uploadId,
            fileType: fileType,
            annotated: annotated,
            thumbnailNumber: thumbnailNumber,
            storageVersion: storageVersion,
            storeInDiskCache: storeInDiskCache
        )
    }

    /// Factory methods to produce proper key based on Upload properties
    /// It can return a MediaKey for LocalFiles or MediaCache depending on the Upload.
    /// It detects if Upload has annotations and prefers annotated version. Otherwise it constructs key for not annotated version
    /// It returns `nil` if it cannot infer the storageVersion from the Upload
    static func autoAnnotatedMediaKey(projectId: String, upload: Upload, thumbnailNumber: Int? = nil) -> MediaKey? {
        let annotated =
            upload.annotations != nil &&
            (upload.storageVersion.getMain(annotated: true) != nil
                || upload.localStorageVersion.getMain(annotated: true) != nil)

        return mediaKey(projectId: projectId, upload: upload, annotated: annotated, thumbnailNumber: thumbnailNumber)
    }

    /// It can return a MediaKey for LocalFiles or MediaCache depending on the Upload.
    /// It returns `nil` if it cannot infer the storageVersion from the Upload. It can only happen for annotated photos as for the original
    /// ones if storageVersion is missing we still provide the MediaKey with an "unknown" storage version and disable `storeInDiskCache`
    /// This is done for backward compatibility with uploads that have no storageVersion. If the Uploads are migrated to always have
    /// the storageVersion for the main image (not the annotated) then "unknown" hack can be removed and nil returned in case
    /// the Upload has no storageVersion yet.
    static func mediaKey(projectId: String, upload: Upload, annotated: Bool,
                         thumbnailNumber: Int? = nil) -> MediaKey?
    {
        // Upload can be in 3 states
        //
        // A) The file is not yet uploaded to Storage
        //    So the file is in LocalFiles - this is indicated by the Upload.localStorageVersion
        //    having a value of "main" or "annotated" with "localFile" prefix
        //
        //    For this case this constructor will create key with inLocalFiles=true. So it's just a convenience
        //    constructor for clients (UI components) to not care if the file is local or not
        // -------------------
        //
        // B) The file was uploaded from this device to Storage
        //    In this case the main file and thumbnails were moved from LocalFiles to MediaCache for immediate
        //    access (so the files don't have to be downloaded). Because the app only uploads the main file
        //    it doesn't know the thumbnails storage version, so all the files are stored with main storage version
        //
        //    For this case the constructor will handle the localStorageVersion to properly handle the thumbnails
        //    version to avoid redownloading files.
        //    Important consideration - if storageVersion contains a version newer than localStorageVersion
        //    then localStorageVersion is ignored
        // -------------------
        //
        // C) The file was not uploaded from this device, so the only information about the file is
        //    the storage version and the file should be handled by MediaCache
        //
        //    This is the default mode of the MediaKey
        // -------------------
        // Please note that the above states apply equally to main and annotated images.

        // check case A) - if it's local file
        if let localStorageVersion = upload.localStorageVersion.getMain(annotated: annotated),
           _isStorageVersionLocalFile(version: localStorageVersion)
        {
            return localFilesKey(
                projectId: projectId,
                uploadId: upload.id,
                fileType: upload.fileType,
                annotated: annotated,
                thumbnailNumber: thumbnailNumber
            )
        }

        // otherwise check B) - if it was uploaded from this device
        let localMainStorageVersion = upload.localStorageVersion.getMain(annotated: annotated)
        let mainStorageVersion = upload.storageVersion.getMain(annotated: annotated)
        if let localMainStorageVersion = localMainStorageVersion {
            // check if local is "newer" - based on generation (compared as Strings
            if mainStorageVersion == nil ||
                (Int64(mainStorageVersion!) ?? 0) <= (Int64(localMainStorageVersion) ?? 0)
            {
                // files added to MediaCache from LocalFiles, use local main storage version no matter
                // if it's the main file or thumbnail
                return mediaCacheKey(
                    projectId: projectId,
                    uploadId: upload.id,
                    fileType: upload.fileType,
                    annotated: annotated,
                    thumbnailNumber: thumbnailNumber,
                    storageVersion: localMainStorageVersion,
                    storeInDiskCache: true
                )
            }
        }

        // otherwise C) - use the storageVersion
        var storageVersion: String?
        if let thumbnailNumber = thumbnailNumber {
            storageVersion = upload.storageVersion.get(annotated: annotated, thumbnail: thumbnailNumber)
        } else {
            storageVersion = upload.storageVersion.getMain(annotated: annotated)
        }
        // For backward compatibility for files that have no storageVersion assume some main storageVersion
        // Such files are not stored in the MediaCache but still need to be downloaded (in memory only)
        if storageVersion == nil, annotated == false {
            storageVersion = "unknown"
        }
        guard let storageVersion = storageVersion else { return nil }
        return mediaCacheKey(
            projectId: projectId,
            uploadId: upload.id,
            fileType: upload.fileType,
            annotated: annotated,
            thumbnailNumber: thumbnailNumber,
            storageVersion: storageVersion,
            storeInDiskCache: storageVersion != "unknown"
        )
    }
}
