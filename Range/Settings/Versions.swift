import Foundation

///
final class Versions {
    /// Minimum version compatible with backend ("1.0.9").
    var requiredMinimumVersion: String? {
        get {
            UserDefaults.standard.string(forKey: "requiredMinimumVersion")
        }
        set {
            if let requiredMinimumVersion = newValue {
                UserDefaults.standard.set(requiredMinimumVersion, forKey: "requiredMinimumVersion")
            } else {
                UserDefaults.standard.removeObject(forKey: "requiredMinimumVersion")
            }
        }
    }

    /// The version of the current app installation ("1.0.9", etc.)
    let appVersion: String
    /// The display value for app version (including app name and build number)
    let fullAppVersionDisplayName: String
    /// if appVersion is lower than requiredMinimumVersion then this installation is considered as expired and cannot be used by user
    var isAppVersionExpired: Bool {
        guard let requiredMinimumVersion else { return false }
        return appVersion.compare(requiredMinimumVersion, options: .numeric) == .orderedAscending
    }

    init() {
        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? ""
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildVersionNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        fullAppVersionDisplayName = "\(appName) v\(appVersion) (\(buildVersionNumber))"
    }
}
