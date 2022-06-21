import FirebaseAuth
import Foundation
import OSLog

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

func getUserId(forUser user: FirebaseAuth.User, completion: @escaping (Result<String, Error>) -> Void) {
    user.getIDTokenResult { tokenResult, error in
        if let error = error {
            Logger.auth.error("error fetching the id token result \(error.localizedDescription, privacy: .public)")
            completion(.failure(error))
            return
        }
        guard let tokenResult = tokenResult else {
            Logger.auth.error("no tokenResult")
            completion(.failure(AuthError.unknown))
            return
        }
        guard let userId = tokenResult.claims["userId"] as? String else {
            Logger.auth.error("userId not found in claims")
            completion(.failure(AuthError.userIdNotFound))
            return
        }
        completion(.success(userId))
    }
}
