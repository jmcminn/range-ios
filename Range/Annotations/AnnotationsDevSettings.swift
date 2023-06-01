import Combine
import Foundation

/// Storage for hidden dev settings for prototyping new annotations features
final class AnnotationsDevSettings: ObservableObject {
    private enum Keys {
        /// boolean whether to reduce the number of polyline segments resulting from user pan gesture using the Douglas-Peucker algorithm
        static let simplifyScribbleLine = "simplifyScribbleLine"
        /// boolean, whether to interpolate points from user gesture with bezier curves using Catmull-Rom algorithm
        static let interpolateScribbleLine = "interpolateScribbleLine"
    }

    private let defaults: UserDefaults

    @Published var simplifyScribbleLine: Bool {
        didSet {
            defaults.set(simplifyScribbleLine, forKey: Keys.simplifyScribbleLine)
        }
    }

    @Published var interpolateScribbleLine: Bool {
        didSet {
            defaults.set(interpolateScribbleLine, forKey: Keys.interpolateScribbleLine)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.simplifyScribbleLine: true,
            Keys.interpolateScribbleLine: true,
        ])

        _simplifyScribbleLine = .init(initialValue: defaults.bool(forKey: Keys.simplifyScribbleLine))
        _interpolateScribbleLine = .init(initialValue: defaults.bool(forKey: Keys.interpolateScribbleLine))
    }
}
