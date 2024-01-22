import Foundation

// see: https://www.swiftbysundell.com/articles/async-and-concurrent-forEach-and-map/
extension Sequence {
    /// A `map` version that allows for async transformations.
    /// Please note that the transforms for all elements still run in sequence
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var values = [T]()
        for element in self {
            try await values.append(transform(element))
        }
        return values
    }

    /// A `map`version that allows for async transformation and runs them all concurrently
    func concurrentMap<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            Task {
                try await transform(element)
            }
        }
        return try await tasks.asyncMap { task in
            try await task.value
        }
    }

    /// A `map`version that allows for async transformation and runs them all concurrently using MainActor
    @MainActor
    func concurrentMapOnMain<T>(_ transform: @escaping (Element) async throws -> T) async throws -> [T] {
        let tasks = map { element in
            Task { @MainActor in
                try await transform(element)
            }
        }
        return try await tasks.asyncMap { task in
            try await task.value
        }
    }
}
