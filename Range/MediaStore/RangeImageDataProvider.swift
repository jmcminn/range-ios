import Foundation
import Kingfisher

/// Extend ImageDataProvider with the cache field, as Range app uses 2 caches and we need to know which one is used by the provider.
protocol RangeImageDataProvider: ImageDataProvider {
    /// The cache to use for fetching images
    var cache: ImageCache { get }
    /// The cache serializer to use
    var cacheSerializer: CacheSerializer { get }
}
