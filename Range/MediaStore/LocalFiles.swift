import Foundation
import Kingfisher
import OSLog

/// Store for local files not uploaded to storage yet
/// It uses Kingfisher ImageCache but is not really a cache because the files on disk never expire (we don't want to lose files that are not uploaded).
/// We just want to reuse ImageCache file handling functionality
/// Every user has their own LocalFiles storage
class LocalFiles {
    private let cache: ImageCache

    /// A default cache serializer adjusted to prefer storing the original image data (if available instead of serializing it form UIImage)
    /// and to use 0.75 compression quality for JPEG (instead of the 1.0 default)
    let cacheSerializer: CacheSerializer

    init(userId: String) throws {
        // make sure that the "cache" is not in Library/Caches as we want it to persist any cache cleanups
        let applicationDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let localFiles = try ImageCache(name: "user_\(userId)_local", cacheDirectoryURL: applicationDirectory)
        localFiles.diskStorage.config.expiration = .never
        localFiles.diskStorage.config.autoExtAfterHashedFileName = true
        cache = localFiles

        var cacheSerializer = DefaultCacheSerializer()
        cacheSerializer.compressionQuality = 0.75
        cacheSerializer.preferCacheOriginalData = true
        self.cacheSerializer = cacheSerializer

        // TODO: after 1.8.0 this can be removed in the release after 1.8.0 (in which it's being introduced)
        do {
            try possiblyMigrateLocalFiles()
        } catch {
            Logger.cache.error("Failed to migrate local files to user local files \(error.localizedDescription)")
        }
    }

    /// Moves files from obsolete "local" directory to a cache per userId
    private func possiblyMigrateLocalFiles() throws {
        // old cache:
        let applicationDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let oldLocalFiles = try ImageCache(name: "local", cacheDirectoryURL: applicationDirectory)

        let oldDirectoryURL = oldLocalFiles.diskStorage.directoryURL
        let newDirectoryURL = cache.diskStorage.directoryURL

        Logger.cache.info(
            "Migrating local files \(oldDirectoryURL.path) to user level local files \(newDirectoryURL.path)"
        )

        let fileManager = FileManager.default
        for filePath in try fileManager.contentsOfDirectory(atPath: oldDirectoryURL.path) {
            let oldFileURL = oldDirectoryURL.appending(path: filePath)
            let newFileURL = newDirectoryURL.appending(path: filePath)
            Logger.cache.info("Moving \(oldFileURL.path) to \(newFileURL.path)")
            try fileManager.moveItem(at: oldFileURL, to: newFileURL)
        }

        Logger.cache.info("Migrated local files to user level local files")
    }

    /// Return Kingfisher image provider to use for UIImageView. This image provider gets the data from local files.
    func imageProvider(forKey key: MediaKey) -> RangeImageDataProvider {
        RangeLocalFileImageDataProvider(
            cache: cache,
            cacheSerializer: cacheSerializer,
            cacheKey: key.cacheKey,
            localFileImageDataProvider: LocalFileImageDataProvider(fileURL: fileURL(forKey: key))
        )
    }

    func store(_ data: Data, forKey key: MediaKey) async throws {
        // Since the files are not versioned, we need to remove the previous version so the app knows that
        // image needs to be reloaded
        await cache._asyncRemoveImage(forKey: key.cacheKey)
        try await cache._asyncStoreToDisk(data, forKey: key.cacheKey)
    }

    /// generate and store thumbnails for given key
    /// does nothing if it's not an image
    func generateAndStoreThumbnails(_ data: Data, forKey key: MediaKey) async throws {
        guard key.fileType.isImage else { return }
        if let thumbnail0Data = resizeImage(imageData: data, maxResolution: _thumbnail0Size) {
            try await store(thumbnail0Data, forKey: key.forThumbnail(0))
        }
        if let thumbnail1Data = resizeImage(imageData: data, maxResolution: _thumbnail1Size) {
            try await store(thumbnail1Data, forKey: key.forThumbnail(1))
        }
    }

    func hasFile(forKey key: MediaKey) -> Bool {
        cache.isCached(forKey: key.cacheKey)
    }

    func removeFile(forKey key: MediaKey) async {
        await cache._asyncRemoveImage(forKey: key.cacheKey)
    }

    /// Remove file for given key. If file is an image it also remove the thumbnails
    func removeFileAndThumbnails(forKey key: MediaKey) async {
        await removeFile(forKey: key)
        if key.fileType.isImage {
            await removeFile(forKey: key.forThumbnail(0))
            await removeFile(forKey: key.forThumbnail(1))
        }
    }

    func fileURL(forKey key: MediaKey) -> URL {
        cache.diskStorage.cacheFileURL(forKey: key.cacheKey)
    }
}
