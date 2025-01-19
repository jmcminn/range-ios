import Combine
import FirebaseFunctions
import Foundation
import SwiftUI

/// global variable for debug settings
var _debugSettings = DebugSettings()

/// Storage for hidden debug settings for prototyping new features, etc.
final class DebugSettings: ObservableObject {
    private enum Keys {
        /// open last opened project when starting the app (if false then start with projects screen)
        static let openLastProjectOnStart = "opeanLastProjectOnStart"
        /// should the pins use the mapbox view annotations (native views) or annotations (mapbox layer views)
        static let nativeViewsForPins = "nativeViewsForPins"
        /// should the canvas animate to center on the pin when photo pin snapped to pink pin by user pan gesture
        static let centerCanvasOnPinSnap = "centerCanvasOnPinSnap"
        /// should the haptic feedback occur when user manually selected pink pin by tapping on it
        static let hapticFeedbackOnPinTapSelection = "hapticFeedbackOnPinTapSelection"
        /// when set to `true` the photos in the collaboration feed are sized based on their aspect ratio to cover the whole width
        /// when `false` the space for photos is always 4:3 (width:height) and the photo is fitted in
        static let dynamicImageHeightInCollabFeed = "dynamicImageHeightInCollabFeed"
        /// whether the feed should be sorted ascending by timestamp (so newest items at the bottom) or descending (most recent items at the top)
        static let feedSortedAscendingByTimestamp = "feedSortedAscendingByTimestamp"
    }

    private let defaults: UserDefaults

    @Published var openLastProjectOnStart: Bool {
        didSet {
            defaults.set(openLastProjectOnStart, forKey: Keys.openLastProjectOnStart)
        }
    }

    @Published var nativeViewsForPins: Bool {
        didSet {
            defaults.set(nativeViewsForPins, forKey: Keys.nativeViewsForPins)
        }
    }

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

    @Published var dynamicImageHeightInCollabFeed: Bool {
        didSet {
            defaults.set(dynamicImageHeightInCollabFeed, forKey: Keys.dynamicImageHeightInCollabFeed)
        }
    }

    @Published var feedSortedAscendingByTimestamp: Bool {
        didSet {
            defaults.set(feedSortedAscendingByTimestamp, forKey: Keys.feedSortedAscendingByTimestamp)
        }
    }

    let appVersion: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        defaults.register(defaults: [
            Keys.openLastProjectOnStart: false,
            Keys.nativeViewsForPins: true,
            Keys.centerCanvasOnPinSnap: true,
            Keys.hapticFeedbackOnPinTapSelection: true,
            Keys.dynamicImageHeightInCollabFeed: true,
            Keys.feedSortedAscendingByTimestamp: true,
        ])

        let releaseVersionNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildVersionNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        appVersion = releaseVersionNumber + " (" + buildVersionNumber + ")"
        _openLastProjectOnStart = .init(initialValue: defaults.bool(forKey: Keys.openLastProjectOnStart))
        _nativeViewsForPins = .init(initialValue: defaults.bool(forKey: Keys.nativeViewsForPins))
        _centerCanvasOnPinSnap = .init(initialValue: defaults.bool(forKey: Keys.centerCanvasOnPinSnap))
        _hapticFeedbackOnPinTapSelection = .init(initialValue: defaults
            .bool(forKey: Keys.hapticFeedbackOnPinTapSelection))
        _dynamicImageHeightInCollabFeed = .init(initialValue: defaults
            .bool(forKey: Keys.dynamicImageHeightInCollabFeed))
        _feedSortedAscendingByTimestamp = .init(initialValue: defaults
            .bool(forKey: Keys.feedSortedAscendingByTimestamp))
    }

    static func toggleLightDarkMode() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow else { return }
        window.overrideUserInterfaceStyle = window.traitCollection.userInterfaceStyle == .dark ? .light : .dark
    }

    static func showTypeScale() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow else { return }

        guard let vc = window.rootViewController?._topViewController() else { return }
        TypeScaleCardViewController().installAndShowCard(in: vc)
    }
}
