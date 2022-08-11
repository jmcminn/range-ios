import FirebaseStorage
import FirebaseStorageSwift
import Foundation
import Kingfisher
import OSLog

/// Implements Kingfisher ImageDataProvider that allows Kingfisher cache to get images from Firebase storage. As a fallback when
/// the images is not in the cache or couldn't be downloaded it checks for the local images (not uploaded yet) - which is also a cache.
class FirebaseStorageImageProvider: ImageDataProvider {
    private unowned let localPhotosCache: ImageCache
    private let ref: StorageReference
    var cacheKey: String

    init(localPhotosCache: ImageCache, ref: StorageReference) {
        self.localPhotosCache = localPhotosCache
        self.ref = ref
        cacheKey = ref.fullPath
    }

    /// Loads the data from the Firebase storage.
    /// It first gets the metadata to know the size, as the size is required to get data.
    /// In case of storage failure it checks the local photos cache (maybe the photo is not uploaded yet)
    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        ref.getMetadata { [weak self] metadata, error in
            guard let self = self else { return }
            if let error = error {
                // in case of problems try local photos
                self.dataFromLocalPhotos(orError: error, handler: handler)
            } else {
                let metadataSize = metadata?.size ?? 0
                // just in case (?) take 2x, or 2^24 if not provided (16MB should be enough??)
                let maxSize = metadataSize > 0 ? 2 * metadataSize : 16_777_216
                self.ref.getData(maxSize: maxSize) { data, error in
                    if let error = error {
                        // in case of problems try local photos
                        self.dataFromLocalPhotos(orError: error, handler: handler)
                    } else {
                        handler(.success(data!))
                    }
                }
            }
        }
    }

    /// Gets the data for given ref from local photos cache (in case it's not implemented yet). Returns given error if failed.
    private func dataFromLocalPhotos(orError: Error, handler: @escaping (Result<Data, Error>) -> Void) {
        let key = ref.fullPath
        let cachePath = localPhotosCache.cachePath(forKey: key)
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: cachePath))
            Logger.storage.debug(
                """
                retrieved \(key, privacy: .public) from local photos cache, storage
                request failed: \(orError.localizedDescription, privacy: .public)
                """
            )
            handler(.success(data))
        } catch {
            // report original error
            Logger.storage.debug(
                """
                failed to retrieve \(key, privacy: .public) from local photos cache:
                \(error.localizedDescription, privacy: .public),
                storage request failed: \(orError.localizedDescription, privacy: .public)
                """
            )
            handler(.failure(orError))
        }
    }
}
