import Foundation
import Kingfisher

/// A wrapper for LocalFileImageDataProvider to add conformance to RangeImageDataProvider
struct RangeLocalFileImageDataProvider: RangeImageDataProvider {
    let cache: ImageCache
    let cacheSerializer: CacheSerializer
    let cacheKey: String
    private let localFileImageDataProvider: LocalFileImageDataProvider

    init(
        cache: ImageCache,
        cacheSerializer: CacheSerializer,
        cacheKey: String,
        localFileImageDataProvider: LocalFileImageDataProvider
    ) {
        self.cache = cache
        self.cacheSerializer = cacheSerializer
        self.cacheKey = cacheKey
        self.localFileImageDataProvider = localFileImageDataProvider
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        localFileImageDataProvider.data(handler: handler)
    }
}
