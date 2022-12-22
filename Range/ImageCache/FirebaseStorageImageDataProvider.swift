import FirebaseStorage
import Foundation
import Kingfisher
import OSLog

/// Implements Kingfisher ImageDataProvider that allows Kingfisher cache to get images from Firebase storage. As a fallback when
/// the images is not in the cache or couldn't be downloaded it checks for the local images (not uploaded yet) - which is also a cache.
class FirebaseStorageImageDataProvider: RangeImageDataProvider {
    private let ref: StorageReference
    var cacheKey: String
    var cache: ImageCache
    let localPhotosImageDataProvider: LocalPhotosImageDataProvider

    init(localPhotosCache: ImageCache, ref: StorageReference) {
        cache = ImageCache.default
        self.ref = ref
        cacheKey = ref.fullPath
        localPhotosImageDataProvider = LocalPhotosImageDataProvider(
            localPhotosCache: localPhotosCache,
            cacheKey: cacheKey
        )
    }

    /// Loads the data from the Firebase storage.
    /// It first gets the metadata to know the size, as the size is required to get data.
    /// In case of storage failure it checks the local photos cache (maybe the photo is not uploaded yet)
    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        ref.getMetadata { [weak self] metadata, error in
            guard let self = self else { return }
            if error != nil {
                // in case of problems try local photos
                self.localPhotosImageDataProvider.data(handler: handler)
            } else {
                let metadataSize = metadata?.size ?? 0
                // just in case (?) take 2x, or 2^24 if not provided (16MB should be enough??)
                let maxSize = metadataSize > 0 ? 2 * metadataSize : 16_777_216
                self.ref.getData(maxSize: maxSize) { data, error in
                    if error != nil {
                        // in case of problems try local photos
                        self.localPhotosImageDataProvider.data(handler: handler)
                    } else {
                        handler(.success(data!))
                    }
                }
            }
        }
    }
}
