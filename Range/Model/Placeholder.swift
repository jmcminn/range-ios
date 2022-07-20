import Foundation
import OSLog
import RealmSwift

/// Protocol to be implemented by Realm objects that can be initiated as placeholders
public protocol WithPlaceholder {
    /// Init a placeholder object with given (real) id
    init(placeholderId: String)
}

/// Extend Realm with convenience method for creating placeholder objects
public extension Realm {
    ///
    /// Retrieves the single instance of a given object type with the given primary key from the Realm.
    /// If no instance with the given primary key exists then creates a placeholder objects, adds it to the Realm and returns.
    ///
    /// - returns: An object of type `type`, or placeholder object of type `type` if no instance with the given primary key exists.
    ///
    func objectOrPlaceholder<Element: Object & WithPlaceholder>(ofType type: Element.Type,
                                                                forPrimaryKey key: String) -> Element
    {
        if let object = object(ofType: type, forPrimaryKey: key) {
            return object
        } else {
            Logger.model.debug("\(type) not found for id \(key, privacy: .public), creating a placeholder.")
            let object = type.init(placeholderId: key)
            add(object)
            return object
        }
    }
}
