import Combine
import Foundation
import OSLog

/// Storage for user settings
final class UserSettings: ObservableObject {
    /// callback for the controller using UserSettings
    var signOutAction: (() -> Void)?

    enum Keys {
        /// whether to upload on cellular (true) or only on wifi (when false)
        static let uploadUsingCellular = "uploadUsingCellular"
        /// whether to save the images used for uploads to device (only for taken photos, not for the ones selected from camera roll)
        static let saveImagesToDevice = "saveImagesToDevice"
    }

    private let knockClient: KnockClient
    private let defaults: UserDefaults

    @Published var uploadUsingCellular: Bool {
        didSet { defaults.set(uploadUsingCellular, forKey: Keys.uploadUsingCellular) }
    }

    @Published var saveImagesToDevice: Bool {
        didSet { defaults.set(saveImagesToDevice, forKey: Keys.saveImagesToDevice) }
    }

    /// Whether the emailNotifications setting is being updated now
    @Published var updatingEmailNotifications: Bool = false

    @Published var emailNotifications: Bool {
        didSet {
            // only update if not currently updating. this is to prevent the infinite loop of
            // emailNotifications set if the operation fails and the value is reset while updating it
            if !updatingEmailNotifications {
                updateEmailNotifications(emailNotifications)
            }
        }
    }

    init(userId: String, knockClient: KnockClient) {
        self.knockClient = knockClient
        defaults = UserDefaults.forUser(userId)

        defaults.register(defaults: [
            Keys.uploadUsingCellular: true,
            Keys.saveImagesToDevice: false,
        ])

        _uploadUsingCellular = .init(initialValue: defaults.bool(forKey: Keys.uploadUsingCellular))
        _saveImagesToDevice = .init(initialValue: defaults.bool(forKey: Keys.saveImagesToDevice))

        /// temporarily set to false until the value is retrieved from Knock
        _emailNotifications = .init(initialValue: false)
        refreshEmailNotifications()
    }

    /// Fetch email notifications preference from Knock and update the UserSettings value
    func refreshEmailNotifications() {
        updatingEmailNotifications = true
        Task { @MainActor in
            do {
                self.emailNotifications = try await knockClient.getEmailNotificationsPreference()
            } catch {
                ToastWindow.shared.showError(text: "Failed to fetch Email Notifications settings")
                Logger.knock
                    .error("Failed to getEmailNotificationsPreference \(error.localizedDescription, privacy: .public)")
            }
            updatingEmailNotifications = false
        }
    }

    /// When user changes the setting propagate it to Knock. If propagation fails reset back to previous value
    private func updateEmailNotifications(_ enabled: Bool) {
        updatingEmailNotifications = true
        Task { @MainActor in
            do {
                try await knockClient.setEmailNotificationsPreference(enabled)
            } catch {
                // bring back the previous value if update failed
                emailNotifications = !enabled
                ToastWindow.shared.showError(text: "Failed to update Email Notifications settings")
                Logger.knock
                    .error("Failed to setEmailNotificationsPreference \(error.localizedDescription, privacy: .public)")
            }
            updatingEmailNotifications = false
        }
    }
}
