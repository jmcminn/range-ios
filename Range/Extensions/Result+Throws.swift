import Foundation

/// Convert from Result to throwing getter
extension Result {
    ///    It evaluates the result and treats the failure case as an error to be thrown
    func get() throws -> Success {
        switch self {
        case let .success(success):
            return success
        case let .failure(failure):
            throw failure
        }
    }
}
