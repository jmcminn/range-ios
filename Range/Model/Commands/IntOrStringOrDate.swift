import Foundation
import RealmSwift

/// Utility type to represent Int, String or Date as Codable
enum IntOrStringOrDate: Codable, Equatable {
    case int(Int), string(String), date(Date)

    enum IntOrStringOrDateError: Error {
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
        case let .date(d):
            return .date(d)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .int(i):
            try container.encode(i)
        case let .string(s):
            try container.encode(s)
        case let .date(d):
            try container.encode(d)
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
        if let date = try? decoder.singleValueContainer().decode(Date.self) {
            self = .date(date)
            return
        }

        throw IntOrStringOrDateError.missingValue
    }
}
