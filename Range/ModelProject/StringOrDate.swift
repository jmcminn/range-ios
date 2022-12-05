import FirebaseFirestore
import Foundation
import RealmSwift

/// Utility type to represent String or Date as Codable
/// This type can decode Firestore.Timestamp as Date
/// It also has a function to encode Date as Firestore.Timestamp
///
/// Warning: if we want to support Int (which is not needed now) it will collide when decoding with Date... in this case we need more explicit
/// control over type (so when decoding we need to somehow pass the expected type)
enum StringOrDate: Codable, Equatable {
    case string(String), date(Date)

    enum StringOrDateError: Error {
        case missingValue
        case realmValueNotSupported
    }

    /// Return value as AnyRealmValue
    var anyRealmValue: AnyRealmValue {
        switch self {
        case let .string(s):
            return .string(s)
        case let .date(d):
            return .date(d)
        }
    }

    /// Returns the corresponding associated value wrapping Date in Firestore.Timestamp (other types are unchanged)
    /// Suitable for syncing the value to Firestore
    var withDateAsTimestamp: Any {
        switch self {
        case let .string(s):
            return s
        case let .date(d):
            return Timestamp(date: d)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(s):
            try container.encode(s)
        case let .date(d):
            try container.encode(d)
        }
    }

    init(from decoder: Decoder) throws {
        if let string = try? decoder.singleValueContainer().decode(String.self) {
            self = .string(string)
            return
        }
        if let date = try? decoder.singleValueContainer().decode(Date.self) {
            self = .date(date)
            return
        }
        if let timestamp = try? decoder.singleValueContainer().decode(Timestamp.self) {
            self = .date(timestamp.dateValue())
        }

        throw StringOrDateError.missingValue
    }
}
