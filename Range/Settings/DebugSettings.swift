import Combine
import Foundation

/// Storage for hidden debug settings for prototyping new features, etc.
final class DebugSettings: ObservableObject {
    private enum Keys {
        /// should the canvas animate to center on the pin when photo pin snapped to pink pin by user pan gesture
        static let centerCanvasOnPinSnap = "centerCanvasOnPinSnap"
        /// should the haptic feedback occur when user manually selected pink pin by tapping on it
        static let hapticFeedbackOnPinTapSelection = "hapticFeedbackOnPinTapSelection"
    }

    private let defaults: UserDefaults

    @Published var centerCanvasOnPinSnap: Bool {
        didSet {
            defaults.set(centerCanvasOnPinSnap, forKey: Keys.centerCanvasOnPinSnap)
        }
    }

    @Published var hapticFeedbackOnPinTapSelection: Bool {
        didSet {
            defaults.set(hapticFeedbackOnPinTapSelection, forKey: Keys.hapticFeedbackOnPinTapSelection)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.centerCanvasOnPinSnap: true,
            Keys.hapticFeedbackOnPinTapSelection: false,
        ])

        _centerCanvasOnPinSnap = .init(initialValue: defaults.bool(forKey: Keys.centerCanvasOnPinSnap))
        _hapticFeedbackOnPinTapSelection = .init(initialValue: defaults
            .bool(forKey: Keys.hapticFeedbackOnPinTapSelection))
    }
}
