import Foundation
import Kingfisher

/// Implements Kingfisher ImageDataProvider that allows Kingfisher cache to get images from localPhotos cache given a cache key.
class LocalPhotosImageDataProvider: ImageDataProvider {
    var cacheKey: String
    private let localFileImageDataProvider: LocalFileImageDataProvider

    init(localPhotosCache: ImageCache, cacheKey: String) {
        self.cacheKey = cacheKey
        localFileImageDataProvider = LocalFileImageDataProvider(
            fileURL: URL(fileURLWithPath: localPhotosCache.cachePath(forKey: cacheKey)),
            cacheKey: cacheKey
        )
    }

    /// In case of storage failure it checks the local photos cache (maybe the photo is not uploaded yet)
    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        localFileImageDataProvider.data(handler: handler)
    }
}
