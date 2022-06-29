import Foundation

/// Convert from Optional to throwing `or`
extension Optional {
    /// Unwraps `self` if it is non-`nil`.
    /// Throws the given error if `self` is `nil`.
    func or(error: Error) throws -> Wrapped {
        switch self {
        case let x?: return x
        case nil: throw error
        }
    }
}
