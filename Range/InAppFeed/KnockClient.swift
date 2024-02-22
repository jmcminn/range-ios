import FirebaseFunctions
import Foundation
import Knock

/// Class holding the current Knock client. The client is refreshed when the user token expires
class KnockClient {
    let userId: String
    private var internalClient: Knock?

    init(userId: String) {
        self.userId = userId
    }

    func get() async throws -> Knock {
        if let internalClient {
            return internalClient
        } else {
            guard let knockKey: String = try? AppConfiguration.value(for: "KnockKey"), knockKey.isEmpty == false else {
                throw "No knock key provided! Not starting knock"
            }

            let result = try await Functions.functions(region: "us-west2")
                .httpsCallable("updateKnockUserToken")
                .call()
            guard let data = result.data as? [String: Any], let userToken = data["token"] as? String else {
                throw "Cannot connect to in app notifications"
            }

            internalClient = try Knock(publishableKey: knockKey, userId: userId, userToken: userToken)
            return internalClient!
        }
    }
}
