import Combine
import Foundation

/// Storage for user settings
final class UserSettings: ObservableObject {
    /// callback for the controller using UserSettings
    var signOutAction: (() -> Void)?

    private enum Keys {
        /// whether to upload on cellular (true) or only on wifi (when false)
        static let uploadUsingCellular = "uploadUsingCellular"
        /// whether to save the images used for uploads to device (only for taken photos, not for the ones selected from camera roll)
        static let saveImagesToDevice = "saveImagesToDevice"
        /// show archived collaborations
        static let showArchivedCollaborations = "showArchivedCollaborations"
    }

    private let defaults: UserDefaults

    @Published var uploadUsingCellular: Bool {
        didSet {
            defaults.set(uploadUsingCellular, forKey: Keys.uploadUsingCellular)
        }
    }

    @Published var saveImagesToDevice: Bool {
        didSet {
            defaults.set(saveImagesToDevice, forKey: Keys.saveImagesToDevice)
        }
    }

    @Published var showArchivedCollaborations: Bool {
        didSet {
            defaults.set(showArchivedCollaborations, forKey: Keys.showArchivedCollaborations)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.uploadUsingCellular: true,
            Keys.saveImagesToDevice: false,
            Keys.showArchivedCollaborations: false,
        ])

        _uploadUsingCellular = .init(initialValue: defaults.bool(forKey: Keys.uploadUsingCellular))
        _saveImagesToDevice = .init(initialValue: defaults.bool(forKey: Keys.saveImagesToDevice))
        _showArchivedCollaborations = .init(initialValue: defaults.bool(forKey: Keys.showArchivedCollaborations))
    }
}
