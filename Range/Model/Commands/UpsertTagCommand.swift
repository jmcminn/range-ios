import Foundation
import RealmSwift

/// Add or update the `Tag` in local Realm db.
struct UpsertTagCommand: LocalCommand, Equatable {
    let tagId: String
    var name: String

    func apply(inRealm realm: Realm) throws {
        let tag = Tag(id: tagId, name: name)
        realm.add(tag, update: .modified)
    }
}
