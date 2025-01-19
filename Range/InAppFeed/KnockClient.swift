import FirebaseFunctions
import Foundation
import Knock

/// Class holding the current Knock client. The client is refreshed when the user token expires
class KnockClient {
    let userId: String

    // it holds the Knock.shared after the setup and signin
    private var internalClient: Knock?

    init(userId: String) {
        self.userId = userId
    }

    /// Reset the Knock API client. The next call to `get` till fetch new user token and reinitiate the Knock
    func reset() {
        Knock.shared.resetInstanceCompletely()
        internalClient = nil
    }

    /// Get the current Knock client.
    /// If not initialized yet it'll initialize it.
    func get() async throws -> Knock {
        if let internalClient {
            return internalClient
        } else {
            guard let knockKey: String = try? AppConfiguration.value(for: "KnockKey"), knockKey.isEmpty == false else {
                throw "No knock key provided! Not starting knock"
            }

            let result = try await Functions.functions(region: "us-west2")
                .httpsCallable("genericOnCall")
                .call(["functionName": "updateKnockUserToken"])
            guard let data = result.data as? [String: Any], let userToken = data["token"] as? String else {
                throw "Cannot connect to in app notifications"
            }

            try await Knock.shared.setup(publishableKey: knockKey, pushChannelId: nil)
            await Knock.shared.signIn(userId: userId, userToken: userToken)

            internalClient = Knock.shared

            return internalClient!
        }
    }
}
