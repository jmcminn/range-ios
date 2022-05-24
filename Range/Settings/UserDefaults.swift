import Foundation

enum UserDefaultsConstants: String {
    case lastPhotoPinId
}

/// stores the last select geometry id for a photo to use it as a default for the next photo
var lastPhotoPinId: String? {
    get {
        UserDefaults.standard.string(forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
    }
    set {
        if let id = newValue {
            UserDefaults.standard.set(id, forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
        } else {
            UserDefaults.standard.removeObject(forKey: UserDefaultsConstants.lastPhotoPinId.rawValue)
        }
    }
}
