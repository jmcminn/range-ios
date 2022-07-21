import Foundation
import RealmSwift

struct AddTagCommand: Command, Equatable {
    let tagId: String
    var name: String

    func apply(inRealm realm: Realm) throws {
        let tag = Tag(id: tagId, name: name)
        // if the tag has local lastApplied keep it
        if let existingTag = realm.object(ofType: Tag.self, forPrimaryKey: tagId) {
            tag.lastApplied = existingTag.lastApplied
        }
        realm.add(tag, update: .modified)
    }
}
