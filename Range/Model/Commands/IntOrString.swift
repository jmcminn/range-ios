import Foundation
import RealmSwift

/// Utility type to represent Int or String as Codable
enum IntOrString: Codable, Equatable {
    case int(Int), string(String)

    enum IntOrStringError: Error {
        case missingValue
        case realmValueNotSupported
    }

    /// Return value as AnyRealmValue
    var anyRealmValue: AnyRealmValue {
        switch self {
        case let .int(i):
            return .int(i)
        case let .string(s):
            return .string(s)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .int(i):
            try container.encode(i)
        case let .string(s):
            try container.encode(s)
        }
    }

    init(from decoder: Decoder) throws {
        if let int = try? decoder.singleValueContainer().decode(Int.self) {
            self = .int(int)
            return
        }

        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self = .string(string)
            return
        }

        throw IntOrStringError.missingValue
    }
}
