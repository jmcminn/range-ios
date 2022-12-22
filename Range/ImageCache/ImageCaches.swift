import FirebaseStorage
import Foundation
import Kingfisher

/// the key / path for the upload in given project
/// if thumbnailNumber is provided it returns the key for thumbnail
func uploadKey(projectId: String, uploadId: String, thumbnailNumber: Int? = nil) -> String {
    var key = "projects/\(projectId)/uploads/\(uploadId)"
    if let thumbnailNumber = thumbnailNumber {
        key = thumbnailKey(forUploadKey: key, thumbnailNumber: thumbnailNumber)
    }
    return key
}

/// Given key add the suffix to obtain key for thumbnail with given number
func thumbnailKey(forUploadKey key: String, thumbnailNumber: Int = 0) -> String {
    "\(key).thumbnail\(thumbnailNumber)"
}

/// Handling of images in app - caching, fetching from storage, etc.
///
/// Thumbnails have numbers
/// 0 - 200x200>
/// 1 - 650x650>
/// see the [generate thumbnails function repo](https://gitlab.com/range.io/range.io/-/blob/master/modules/firebase-functions-generate-thumbnails/src/generate-thumbnails-from-upload.js#L27)
/// for more details
class ImageCaches {
    /// Firebase storage for uploading photos
    let storage = Storage.storage()

    /// Using Kingfisher image cache for local images store (configured disk cache to never expire)
    /// This could be implemented in different way than Kingfisher cache, we just need a non-expiring disk store to images
    /// but since Kingfisher provides a mechanism for images store on the disk, let's use it
    let localPhotosCache = ImageCache(name: "local-photos")

    /// The default cache for the images. Should be created outside of this class when it's actually used for displaying uploads...
    let downloadsCache = ImageCache.default

    init() {
        localPhotosCache.diskStorage.config.expiration = .never
    }

    /// Returns image data provider for localphoto.
    /// Returns an instance of LocalPhotosImageDataProvider
    func imageProvider(forLocalPhotoWithCacheKey cacheKey: String) -> RangeImageDataProvider {
        LocalPhotosImageDataProvider(localPhotosCache: localPhotosCache, cacheKey: cacheKey)
    }

    /// Returns image data provider for given cache key.
    /// Returns an instance of FirebaseStoreImageDataProvider which allows Kingfisher images cache to load the image from Firebase.
    func imageProvider(forPhotoWithCacheKey cacheKey: String) -> RangeImageDataProvider {
        let ref = storage.reference(withPath: cacheKey)
        return FirebaseStorageImageDataProvider(localPhotosCache: localPhotosCache, ref: ref)
    }

    /// Move the image data from localPhotosCache to downloadsCache
    func moveDataFromLocalPhotosToDownloadsCache(forKey key: String) async throws {
        let cachePath = localPhotosCache.cachePath(forKey: key)
        let data = try Data(contentsOf: URL(fileURLWithPath: cachePath))
        try await downloadsCache._asyncStoreToDisk(data, forKey: key)
        // removeImage doesn't throw, so let's fire and forget
        localPhotosCache.removeImage(forKey: key)
    }
}
