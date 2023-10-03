import FirebaseRemoteConfig
import Foundation
import OSLog

// Defaults loaded into remoteConfig so they're available before it's fetched
private var featureFlagsDefaults: [String: NSObject] = [
    "ran1564VimeoUrl": "https://vimeo.com/rangehq" as NSString,
]

// Called on app start. Fetches the config values once (we don't really have any feature flags
// that we want to observe for changes currently, so it's enough to fetch at the start)
func setupRemoteConfig() {
    let remoteConfig = RemoteConfig.remoteConfig()
    remoteConfig.setDefaults(featureFlagsDefaults)
    remoteConfig.fetchAndActivate { _, error in
        if let error = error {
            Logger.firebase.error("Error fetching firebase remote config: \(error)")
        }
    }
}

/// Feature flag for the link to the "about range" vimeo url
var aboutRangeVimeoUrl: String {
    RemoteConfig.remoteConfig().configValue(forKey: "ran1564VimeoUrl").stringValue!
}
