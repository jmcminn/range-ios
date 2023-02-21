import Foundation
import Kingfisher

/// Store for local files not uploaded to storage yet
/// It uses Kingfisher ImageCache but is not really a cache because the files on disk never expire (we don't want to lose files that are not uploaded).
/// We just want to reuse ImageCache file handling functionality
class LocalFiles {
    private let cache: ImageCache

    init() throws {
        // make sure that the "cache" is not in Library/Caches as we want it to persist any cache cleanups
        let applicationDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let localFiles = try ImageCache(name: "local", cacheDirectoryURL: applicationDirectory)
        localFiles.diskStorage.config.expiration = .never
        localFiles.diskStorage.config.autoExtAfterHashedFileName = true
        cache = localFiles
    }

    /// Return Kingfisher image provider to use for UIImageView. This image provider gets the data from local files.
    func imageProvider(forKey key: MediaKey) -> RangeImageDataProvider {
        RangeLocalFileImageDataProvider(
            cache: cache,
            cacheKey: key.cacheKey,
            localFileImageDataProvider: LocalFileImageDataProvider(fileURL: fileURL(forKey: key))
        )
    }

    func store(_ data: Data, forKey key: MediaKey) async throws {
        try await cache._asyncStoreToDisk(data, forKey: key.cacheKey)
    }

    func hasFile(forKey key: MediaKey) -> Bool {
        cache.isCached(forKey: key.cacheKey)
    }

    func removeFile(forKey key: MediaKey) {
        cache.removeImage(forKey: key.cacheKey)
    }

    func fileURL(forKey key: MediaKey) -> URL {
        cache.diskStorage.cacheFileURL(forKey: key.cacheKey)
    }
}
