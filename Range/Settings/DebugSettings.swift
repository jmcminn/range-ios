import Combine
import Foundation

/// Storage for hidden debug settings for prototyping new features, etc.
final class DebugSettings: ObservableObject {
    private enum Keys {
        static let centerScreenOnPinSnap = "centerScreenOnPinSnap"
    }

    private let defaults: UserDefaults

    @Published var centerScreenOnPinSnap: Bool {
        didSet {
            defaults.set(centerScreenOnPinSnap, forKey: Keys.centerScreenOnPinSnap)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.centerScreenOnPinSnap: true,
        ])

        _centerScreenOnPinSnap = .init(initialValue: defaults.bool(forKey: Keys.centerScreenOnPinSnap))
    }
}
