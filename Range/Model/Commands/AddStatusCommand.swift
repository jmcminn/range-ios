import Foundation
import RealmSwift

struct AddStatusCommand: Command, Equatable {
    let statusId: String
    var name: String
    var color: String
    var isInitial: Bool
    var isCompleted: Bool

    func apply(inRealm realm: Realm) throws {
        let status = Status(id: statusId, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted)
        realm.add(status, update: .modified)
    }
}
