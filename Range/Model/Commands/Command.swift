import Foundation
import RealmSwift

// TODO: 44 command should be object with Locally and Firestore extensions and remove actionCommand for now?
// it can be useful later for storing in db, but for now we should be passing commands and not actionCOMmands

// protocol Command: Equatable, Codable {
//    func applyLocally(writer: ProjectModelWriter) async throws
// }

class Command {}

protocol LocalCommand {
    func applyLocally(writer: ProjectModelWriter) async throws
}
