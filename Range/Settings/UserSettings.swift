import Combine
import Foundation

/// Storage for user settings
final class UserSettings: ObservableObject {
    /// callback for the controller using UserSettings
    var signOutAction: (() -> Void)?

    private enum Keys {
        /// whether to save the images used for uploads to device (only for taken photos, not for the ones selected from camera roll)
        static let saveImagesToDevice = "saveImagesToDevice"
    }

    private let defaults: UserDefaults

    @Published var saveImagesToDevice: Bool {
        didSet {
            defaults.set(saveImagesToDevice, forKey: Keys.saveImagesToDevice)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.saveImagesToDevice: false,
        ])

        _saveImagesToDevice = .init(initialValue: defaults.bool(forKey: Keys.saveImagesToDevice))
    }
}
