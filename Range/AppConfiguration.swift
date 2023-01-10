import Foundation

/// Helper enum for reading app configuration data
enum AppConfiguration {
    enum Error: Swift.Error {
        case missingKey, invalidValue
    }

    /// Bool needs a special handling because it cannot be expressed in Info.plist property derived from user defined build setting.
    /// So instead it'll be a String of NO/YES (by convention)
    static func bool(for key: String) throws -> Bool {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }

        guard let stringValue = object as? String else {
            throw Error.invalidValue
        }

        if stringValue == "YES" {
            return true
        } else if stringValue == "NO" {
            return false
        } else {
            throw Error.invalidValue
        }
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw Error.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { fallthrough }
            return value
        default:
            throw Error.invalidValue
        }
    }
}
