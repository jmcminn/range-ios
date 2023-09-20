import Combine
import FirebaseFunctions
import Foundation

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

    let photoAnnotationsEnabled: Bool

    let appVersion: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // show photo annotations when the debug options are available (dev, demo)
        photoAnnotationsEnabled = try! AppConfiguration.bool(for: "ShowDebugOptions")

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

    static func createOrganizationTest() {
        Functions.functions(region: "us-west2").httpsCallable("createOrganization").call([
            "name": "Test organization",
            "industry": "Testing",
        ]) { result, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "organization created")
            }
            if let result = result {
                print("createOrganization result: \(result.data)")
            }
        }
    }

    static func changeOrganizationRoleTest() {
        Functions.functions(region: "us-west2").httpsCallable("changeOrganizationRole").call([
            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "userId": "a3dff7cb-1db3-4fb0-bcab-4fe150f182ed", // Tom
            "organizationRole": "Admin",
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "role changed")
            }
        }
    }

    static func addOrganizationParticipantTest() {
        Functions.functions(region: "us-west2").httpsCallable("addOrganizationParticipant").call([
            "organizationId": "c39f1e8b-cabb-44c9-822e-e0d7ee92a90d", // Range
//            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "userId": "8931bee0-0e8d-46ed-99cc-0b655b068e95", // sam
            "organizationRole": "Collaborator",
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "organization participant added")
            }
        }
    }

    static func removeOrganizationParticipantTest() {
        Functions.functions(region: "us-west2").httpsCallable("removeOrganizationParticipant").call([
            "organizationId": "c39f1e8b-cabb-44c9-822e-e0d7ee92a90d", // Range
//            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "userId": "8931bee0-0e8d-46ed-99cc-0b655b068e95", // sam
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "organization participant removed")
            }
        }
    }

    static func addProjectParticipantTest() {
        Functions.functions(region: "us-west2").httpsCallable("addProjectParticipant").call([
            "projectId": "474503d1-1adc-4268-88fe-2a797148f16d", // Vanderbilt project
//            "projectId": "ab901606-3a6a-4f35-a095-478caa3841ef", // TomRa project
            "userId": "8931bee0-0e8d-46ed-99cc-0b655b068e95", // sam
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "project participant added")
            }
        }
    }

    static func removeProjectParticipantTest() {
        Functions.functions(region: "us-west2").httpsCallable("removeProjectParticipant").call([
            "projectId": "474503d1-1adc-4268-88fe-2a797148f16d", // Vanderbilt project
//            "projectId": "ab901606-3a6a-4f35-a095-478caa3841ef", // TomRa project
            "userId": "8931bee0-0e8d-46ed-99cc-0b655b068e95", // sam
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "project participant removed")
            }
        }
    }

    static func inviteToOrganizationTest() {
        Functions.functions(region: "us-west2").httpsCallable("inviteToOrganization").call([
            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "inviteeEmail": "rafal@range.io", //
            "organizationRole": "Collaborator",
        ]) { result, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "invited to organization")
            }
            if let result = result {
                print("inviteToOrganization result: \(result.data)")
            }
        }
    }

    static func inviteExistingUserToOrganizationTest() {
        Functions.functions(region: "us-west2").httpsCallable("inviteToOrganization").call([
            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "inviteeEmail": "sam@sam.com", //
            "organizationRole": "Collaborator",
        ]) { result, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "invited to organization")
            }
            if let result = result {
                print("inviteToOrganization result: \(result.data)")
            }
        }
    }

    static func inviteMemberToOrganizationTest() {
        Functions.functions(region: "us-west2").httpsCallable("inviteToOrganization").call([
            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "inviteeEmail": "tom@tom.com", //
            "organizationRole": "Collaborator",
        ]) { result, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "invited to organization")
            }
            if let result = result {
                print("inviteToOrganization result: \(result.data)")
            }
        }
    }

    static func resendInvitationTest() {
        Functions.functions(region: "us-west2").httpsCallable("resendInvitation").call([
            "organizationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
            "invitationId": "9c72a608-9f71-41d0-980d-2334987d9994",
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "invitation resent")
            }
        }
    }

    static func acceptInvitationTest() {
        Functions.functions(region: "us-west2").httpsCallable("acceptInvitation").call([
            "invitationId": "84fc607b-1d23-449d-bb28-036941502492", // TomRa
        ]) { _, error in
            DebugSettings.handCallableError(error: error)
            if error == nil {
                ToastWindow.shared.showSuccess(text: "invitation accept")
            }
        }
    }

    private static func handCallableError(error: Error?) {
        if let error = error as NSError?, error.domain == FunctionsErrorDomain {
            let code = FunctionsErrorCode(rawValue: error.code)
            let message = error.localizedDescription
            let details = error.userInfo[FunctionsErrorDetailsKey]
            print("testCallable error: \(code?.rawValue) \(message) \(details ?? "")")
        } else if let error = error {
            print("testCallable error: \(error)")
        }
        if let error = error {
            ToastWindow.shared.showError(text: error.localizedDescription)
        }
    }
}
