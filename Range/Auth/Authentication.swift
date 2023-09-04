import FirebaseAuth
import Foundation
import OSLog

// for convenience (and because Xcode complains that there's no type named 'User' in module 'FirebaseAuth'
// while there is and it builds successfully, so let's limit the complaining to this line
typealias FirebaseUser = FirebaseAuth.User

// possible errors for authentication
enum AuthError: Error {
    case unknown
    case userIdNotFound
}

// auth error extension to provide localized descriptions of errors
extension AuthError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unknown:
            return "Unknown error"
        case .userIdNotFound:
            // TODO: when does user get userId... is it possible to be in this state?
            return "User not activated"
        }
    }
}

extension FirebaseUser {
    /// Returns userId stored in user custom claims of throws if not found
    func _getUserId() async throws -> String {
        let tokenResult = try await getIDTokenResult()
        guard let userId = tokenResult.claims["userId"] as? String else {
            Logger.auth.error("userId not found in claims \(tokenResult.claims)")
            throw AuthError.userIdNotFound
        }
        return userId
    }
}
