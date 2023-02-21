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
    /// It also passes it's `mediaCache` as the cache to use for caching the downloaded images. It's a little complicated
    func imageProvider(forKey key: MediaKey) -> RangeImageDataProvider {
        RangeMediaCacheImageDataProvider(cache: mediaCache, mediaKey: key, mediaCache: self)
    }

    /// Either gets the file from LocalFiles or downloads the file for given key from Storage
    /// To be used from ImageProvider that is operating on the `mediaCache`. If it's called it means the file is not in `mediaCache`
    /// and also this function should not store it there as it will be done by the logic using image provider.
    func getDataForImageProvider(forKey key: MediaKey) async throws -> Data {
        if localFiles.hasFile(forKey: key) {
            Logger.cache.trace("Reading \(key) from local files")
            return try Data(contentsOf: localFiles.fileURL(forKey: key))
        }

        return try await downloadData(forKey: key)
    }

    private func downloadData(forKey key: MediaKey) async throws -> Data {
        Logger.cache.trace("Downloading \(key) from storage")
        let storageRef = storage.reference(withPath: key.storagePath)
        let metadata = try await storageRef.getMetadata()
        let data = try await storageRef.data(maxSize: metadata.size)
        return data
    }

    func hasFile(forKey key: MediaKey) -> Bool {
        mediaCache.isCached(forKey: key.cacheKey) || localFiles.hasFile(forKey: key)
    }

    /// Returns local file URL for given key either localFiles or mediaCache. If not there download from Storage.
    /// This function is to be used directly when local URL of the cached file is needed. For displaying images use the imageProvider(forKey:)
    @MainActor
    func getCachedFileURL(forKey key: MediaKey) async throws -> URL {
        // 1. try local files (the file is not uploaded yet)
        if localFiles.hasFile(forKey: key) {
            Logger.cache.trace("Reading \(key) from local files")
            return localFiles.fileURL(forKey: key)
        }

        // 2. try the media cache
        if mediaCache.isCached(forKey: key.cacheKey) {
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
    func moveFileFromLocalFilesToMediaCache(forKey key: MediaKey) async throws {
        guard localFiles.hasFile(forKey: key) else { return }
        let data = try Data(contentsOf: localFiles.fileURL(forKey: key))
        try await store(data, forKey: key)
        localFiles.removeFile(forKey: key)
    }
}
