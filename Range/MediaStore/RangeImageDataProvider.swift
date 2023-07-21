import Foundation
import Kingfisher

/// Extend ImageDataProvider with the cache field, as Range app uses 2 caches and we need to know which one is used by the provider.
protocol RangeImageDataProvider: ImageDataProvider {
    /// options to use with this data provider
    var options: KingfisherOptionsInfo { get }
}
