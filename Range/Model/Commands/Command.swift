import Foundation
import RealmSwift

// TODO: 44 command should be object with Locally and Firestore extensions and remove actionCommand for now?
// it can be useful later for storing in db, but for now we should be passing commands and not actionCOMmands
protocol Command {
    /// Apply the changes locally in given Realm. Will be performed in a realm write transaction
    func applyLocally(inRealm realm: Realm) throws
}
