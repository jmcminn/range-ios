import Foundation
import Kingfisher

/// Image data provider that fetches images using MediaCache (so from storage)
struct RangeMediaCacheImageDataProvider: RangeImageDataProvider {
    let cache: ImageCache
    let cacheKey: String
    private let mediaKey: MediaKey
    unowned let mediaCache: MediaCache

    init(cache: ImageCache, mediaKey: MediaKey, mediaCache: MediaCache) {
        self.cache = cache
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
