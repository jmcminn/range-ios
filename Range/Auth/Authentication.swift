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

extension Error {
    /// Extract Firebase Auth error information from given Error or fallback to localizedDescription
    func _messageForAuthError() -> String {
        // Extract information about the error from blocking function info in underlying errors
        if let e = (self as NSError).underlyingErrors.first,
           let responseInfo = (e as NSError).userInfo["FIRAuthErrorUserInfoDeserializedResponseKey"] as? [String: Any],
           let message = responseInfo["message"] as? String
        {
            // sometimes a message is just a code for error (when coming directly from auth)
            if message == "INVALID_LOGIN_CREDENTIALS" {
                return String(localized: "Your email or password is invalid")
            }
            // when coming from a blocking auth function, the message is a text but it has a json with message key embedded in it
            if let jsonStart = message.firstIndex(of: "{"), let jsonEnd = message.lastIndex(of: "}") {
                let jsonMessage = message[jsonStart ... jsonEnd]
                if let jsonMessageData = jsonMessage.data(using: .utf8) {
                    do {
                        if let jsonObject = try JSONSerialization.jsonObject(with: jsonMessageData) as? [String: Any],
                           let errorDict = jsonObject["error"] as? [String: Any],
                           let message = errorDict["message"] as? String
                        {
                            return message
                        }
                    } catch {
                        // ignore error
                    }
                }
            }
        }

        return localizedDescription
    }
}
