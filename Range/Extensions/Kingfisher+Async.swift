import Foundation
import Kingfisher
import UIKit

extension ImageCache {
    /// Stores the data in the cache, performed as an async function
    func _asyncStoreToDisk(_ data: Data, forKey key: String) async throws {
        try await withUnsafeThrowingContinuation { continuation in
            self.storeToDisk(data, forKey: key) { result in
                if case let .failure(error) = result.diskCacheResult {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        } as Void
    }

    /// This function does not throw as storing in the memory cache doesn't throw and the errors when storing on disk
    /// are ignored (do we need them?)
    func _asyncStore(image: UIImage, forKey key: String) async {
        await withUnsafeContinuation { continuation in
            self.store(image, forKey: key) { _ in
                continuation.resume()
            }
        } as Void
    }

    func _asyncRetrieveImage(forKey key: String) async throws -> UIImage? {
        try await withUnsafeThrowingContinuation { continuation in
            self.retrieveImage(forKey: key) { result in
                switch result {
                case let .failure(error):
                    continuation.resume(throwing: error)
                case let .success(cacheResult):
                    switch cacheResult {
                    case let .disk(image), let .memory(image):
                        continuation.resume(returning: image)
                    case .none:
                        continuation.resume(returning: nil)
                    }
                }
            }
        } as UIImage?
    }
}
