import Foundation
import RealmSwift

struct AddStatusCommand: Command {
    let statusId: String
    let name: String
    let color: String
    let isInitial: Bool
    let isCompleted: Bool

    func applyLocally(inRealm realm: Realm) throws {
        let status = Status(id: statusId, name: name, hexColor: color, isInitial: isInitial, isCompleted: isCompleted)
        realm.add(status, update: .modified)
    }
}
