import Foundation
import OSLog

extension UserDefaults {
    // UserDefaults instance for given user (we want to separate defaults so every user
    // logged in on this device has their own preferences/settings)
    static func forUser(_: String) -> UserDefaults {
        // TODO: 2976 replace with defaults for given userId
        UserDefaults.standard
//        UserDefaults(suiteName: "\(Bundle.main.bundleIdentifier ?? "").\(userId)") ?? .standard
    }

}
