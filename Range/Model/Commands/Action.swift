import Foundation
import RealmSwift

// TODO: 90 not needed?
// class Action: Object {
//    /// ObjectId is used for id as it can be sorted (grows
//    @Persisted(primaryKey: true) var _id: ObjectId
//    //// The command to execute
//    @Persisted var command: ActionCommand
//    /// How many times it was tried already
//    @Persisted var retryCount: Int = 0
//    /// Next attempt if we need to retry. Initially it's nil meaning asap
//    @Persisted var nextAttemptAt: TimeInterval? = nil
//    /// If failed the error message is kept here for reference
//    @Persisted var lastErrorMessage: String?
//
//    init(_ command: ActionCommand) {
//        self.command = command
//    }
//
//    func shouldPerform(at time: TimeInterval) -> Bool {
//        // perform if it was not performed yet
//        if retryCount == 0 { return true }
//        if let nextAttemptAt = nextAttemptAt {
//            return time >= nextAttemptAt
//        } else {
//            // next attempt not scheduled, perform now
//            return true
//        }
//    }
//
//    /// Default initializer required by Realm.
//    override init() {
//        super.init()
//    }
// }
