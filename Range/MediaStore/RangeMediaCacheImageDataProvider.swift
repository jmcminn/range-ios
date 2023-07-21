import Foundation
import Kingfisher

/// Image data provider that fetches images using MediaCache (so from storage)
struct RangeMediaCacheImageDataProvider: RangeImageDataProvider {
    let options: KingfisherOptionsInfo
    let cacheKey: String
    private let mediaKey: MediaKey
    unowned let mediaCache: MediaCache

    init(cache: ImageCache,
         cacheSerializer: CacheSerializer,
         mediaKey: MediaKey, mediaCache: MediaCache)
    {
        var options: KingfisherOptionsInfo = [
            .targetCache(cache),
            .cacheSerializer(cacheSerializer),
        ]
        self.options = options
        self.mediaKey = mediaKey
        cacheKey = mediaKey.cacheKey
        self.mediaCache = mediaCache
    }

    func data(handler: @escaping (Result<Data, Error>) -> Void) {
        Task {
            do {
                let data = try await mediaCache.getDataForImageProvider(forKey: mediaKey)
                handler(.success(data))
            } catch {
                handler(.failure(error))
            }
        }
    }
}
