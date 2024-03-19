import Foundation

extension KnockClient {
    func getEmailNotificationsPreference() async throws -> Bool {
        let preferenceSet = try await get()._getUserPreferences(preferenceId: "default")
        guard let email = preferenceSet.channel_types.email else {
            // if not present it means true (at least judging by the Knock preferences UI)
            return true
        }
        switch email {
        case let .left(bool): return bool
        case .right:
            // unknown format, assume true
            return true
        }
    }

    func setEmailNotificationsPreference(_ enabled: Bool) async throws {
        let preferenceSet = try await get()._getUserPreferences(preferenceId: "default")
        var updatedPreferenceSet = preferenceSet
        updatedPreferenceSet.channel_types.email = .left(enabled)
        _ = try await get()._setUserPreferences(preferenceId: "default", preferenceSet: updatedPreferenceSet)
    }
}
