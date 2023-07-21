import Foundation
import Kingfisher

/// A wrapper for LocalFileImageDataProvider to add conformance to RangeImageDataProvider
struct RangeLocalFileImageDataProvider: RangeImageDataProvider {
    let options: KingfisherOptionsInfo
    let cacheKey: String
    private let localFileImageDataProvider: LocalFileImageDataProvider

    init(
        cache: ImageCache,
        cacheSerializer: CacheSerializer,
        cacheKey: String,
        localFileImageDataProvider: LocalFileImageDataProvider
    ) {
        options = [
            .targetCache(cache),
            .cacheSerializer(cacheSerializer),
            .forceRefresh,
            // force refresh is needed as we're overwriting annotated images with same key and expect to always see the fresh version
        ]
        self.cacheKey = cacheKey
        self.localFileImageDataProvider = localFileImageDataProvider
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        localFileImageDataProvider.data(handler: handler)
    }
}
