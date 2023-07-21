import FirebaseStorage
import Foundation
import Kingfisher
import OSLog

/// MediaCache provides a way to download data from Storage and expose imageProvider to be used in UI.
/// For direct access to files use the getCachedFileURL which downloads the file (if not there yet) and returns the local file URL.
class MediaCache {
    /// local files storage (the files that are not uploaded yet)
    private let localFiles: LocalFiles

    /// Cache for all uploads fetched from Firebase Storage (stores images and non-images)
    private let mediaCache = ImageCache(name: "media")

    /// Firebase storage for media files
    let storage = Storage.storage()

    init(localFiles: LocalFiles) {
        self.localFiles = localFiles
        mediaCache.diskStorage.config.autoExtAfterHashedFileName = true
    }

    /// Return Kingfisher image provider to use for UIImageView. This image provider uses MediaCache which means
    /// it'll download files if needed from Storage.
    /// It also passes it's `mediaCache` as the cache to use for caching the downloaded images.
    ///
    /// ACHTUNG: MediaCache acts as a common entry point for handling (displaying) the images from LocalFiles and from MediaCache
    /// so it checks if the key isFromLocalFiles and forwards the call to LocalFiles in this case
    func imageProvider(forKey key: MediaKey) -> RangeImageDataProvider {
        if key.isFromLocalFiles {
            return localFiles.imageProvider(forKey: key)
        } else {
            return RangeMediaCacheImageDataProvider(
                cache: mediaCache,
                cacheSerializer: localFiles.cacheSerializer,
                mediaKey: key,
                mediaCache: self
            )
        }
    }

    /// Downloads the file for given key from Storage
    /// To be used from ImageProvider that is operating on the `mediaCache`. If it's called it means the file is not in `mediaCache`
    /// and also this function should not store it there as it will be done by the logic using image provider.
    func getDataForImageProvider(forKey key: MediaKey) async throws -> Data {
        try await downloadData(forKey: key)
    }

    private func downloadData(forKey key: MediaKey) async throws -> Data {
        Logger.cache.trace("Downloading \(key) from storage")
        let storageRef = storage.reference(withPath: key.storagePath)
        let metadata = try await storageRef.getMetadata()
        let data = try await storageRef.data(maxSize: metadata.size)
        return data
    }

    func hasFile(forKey key: MediaKey) -> Bool {
        if !key.isFromLocalFiles, mediaCache.isCached(forKey: key.cacheKey) {
            return true
        }
        if key.isFromLocalFiles, localFiles.hasFile(forKey: key) {
            return true
        }
        return false
    }

    /// Returns local file URL for given key either localFiles or mediaCache. If not there download from Storage.
    /// This function is to be used directly when local URL of the cached file is needed. For displaying images use the imageProvider(forKey:)
    @MainActor
    func getCachedFileURL(forKey key: MediaKey) async throws -> URL {
        // 1. try local files (the file is not uploaded yet)
        if key.isFromLocalFiles, localFiles.hasFile(forKey: key) {
            Logger.cache.trace("Reading \(key) from local files")
            return localFiles.fileURL(forKey: key)
        }

        guard !key.isFromLocalFiles else { throw "Requested key is not a storage key" }

        // 2. try the media cache
        if mediaCache.imageCachedType(forKey: key.cacheKey) == .disk {
            Logger.cache.trace("Reading \(key) from media cache")
            return mediaCache.diskStorage.cacheFileURL(forKey: key.cacheKey)
        }

        // 3. download from storage
        let data = try await downloadData(forKey: key)

        // 4. store in media cache
        try await mediaCache._asyncStoreToDisk(data, forKey: key.cacheKey)

        // 5. return the URL to the local file in media cache
        return mediaCache.diskStorage.cacheFileURL(forKey: key.cacheKey)
    }

    func store(_ data: Data, forKey key: MediaKey) async throws {
        try await mediaCache._asyncStoreToDisk(data, forKey: key.cacheKey)
    }

    /// Move file from LocalFiles to MediaCache
    func moveFileFromLocalFilesToMediaCache(from localKey: MediaKey, to storageKey: MediaKey) async throws {
        guard localFiles.hasFile(forKey: localKey) else { return }
        let data = try Data(contentsOf: localFiles.fileURL(forKey: localKey))
        try await store(data, forKey: storageKey)
        await localFiles.removeFile(forKey: localKey)
    }
}
