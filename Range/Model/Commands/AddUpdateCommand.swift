import Foundation
import RealmSwift

/// Add or update the `Update`.
struct AddUpdateCommand: Command, Equatable {
    let updateId: String
    var parentId: String
    var parentType: String
    var timestamp: Date
    var userId: String
    var field: Update.Field
    var oldValue: StringOrDate?
    var newValue: StringOrDate?

    func apply(inRealm realm: Realm) throws {
        let collaboration = realm.objectOrPlaceholder(ofType: Collaboration.self, forPrimaryKey: parentId)
        let user = realm.objectOrPlaceholder(ofType: Participant.self, forPrimaryKey: userId)
        let oldValue: AnyRealmValue = oldValue?.anyRealmValue ?? .none
        let newValue: AnyRealmValue = newValue?.anyRealmValue ?? .none
        let update = Update(
            id: updateId,
            timestamp: timestamp,
            field: field,
            oldValue: oldValue,
            newValue: newValue
        )
        update.user = user
        realm.add(update, update: .modified)
        collaboration.updates.insert(update)
    }
}
