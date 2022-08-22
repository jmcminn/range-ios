import Foundation

extension UserDefaults {
    enum UserDefaultsConstants: String {
        case lastPhotoPinId
        /// last user's choice if annotation (tags/description) is enabled in the photo flow
        case annotationEnabled
        /// last user's choice if multi photo session is enabled in the photo flow
        case multiPhotoSessionEnabled
    }

    /// stores the last select geometry id for a photo to use it as a default for the next photo
    static var lastPhotoPinId: String? {
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

    static var annotationEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsConstants.annotationEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.annotationEnabled.rawValue)
        }
    }

    static var multiPhotoSessionEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: UserDefaultsConstants.multiPhotoSessionEnabled.rawValue)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.multiPhotoSessionEnabled.rawValue)
        }
    }
}
