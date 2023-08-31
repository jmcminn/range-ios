import FirebaseFirestore
import Foundation
import Network
import OSLog
import Sentry

/// Stores Actions to be run against the server side.
/// Runs the actions when the network is available.
/// There's 1 global model (per user)  for pendings actions (not 1 per project), so each action keeps the projectId - we want to synchronize
/// the actions with the server side even if user is currently working with a different project (or hasn't opened any project)
class PendingActionsModelImpl: PendingActionsModel {
    /// Firestore reference
    let firestore = Firestore.firestore()
    /// for encoding/decoding actions as JSON data to store in UserDefaults
    let jsonEncoder = JSONEncoder()
    let jsonDecoder = JSONDecoder()

    /// Background serial queue to perform operations actions (or add actions to perform)
    let operationQueue = DispatchQueue(label: "pending-actions-operation-queue")

    /// Only one action can be performed at a time.
    /// This is indicating if an action is currently being performed.
    /// To be set/get on the `operationQueue` only
    var performingAction: Bool = false

    /// for monitoring network access
    let networkMonitor = NWPathMonitor()

    /// maximum backoff for retrying actions (in seconds)
    private let maxBackoff: TimeInterval = 64

    /// Keys for storing pending actions data in UserDefaults
    enum DefaultsKey {
        /// for storing pending actions = Array<Data>
        static let actions = "actions"
        /// How many times the current (first) action was already retried
        static let retryCount = "actions.retryCount"
        /// The timestamp for when there should be the next attempt to try action (not earlier than)
        static let nextAttemptAt = "actions.nextAttemptAt"
        /// Storing last error that caused the retry count to increase
        static let lastError = "actions.lastError"
    }

    init() {
        // a default value for retry count when not set yet
        UserDefaults.standard.register(defaults: [DefaultsKey.retryCount: 0])
    }

    /// Before adding the action to pending actions it needs to be transformed to Data first.
    /// This is a separate function from `addAction` so the project model can invoke it first and abort the local actions if this fails
    /// (so it's kind of a 2-phase commit)
    func prepareAction(_ action: Action) throws -> Data {
        try jsonEncoder.encode(action)
    }

    /// Store action data obtained from `prepareAction` in UserDefaults
    func addAction(data: Data) {
        operationQueue.sync {
            addPendingAction(data: data)
        }
        // try performing now
        operationQueue.async {
            self.maybePerformAction()
        }
    }

    /// Get pending local commands for given project and target object id
    func getLocalCommands(forProjectId projectId: String, targetObjectId: String) -> [LocalCommand] {
        operationQueue.sync {
            let actionsData = pendingActions()
            let actions: [Action] = actionsData
                .compactMap { // Data => Action
                    do {
                        return try jsonDecoder.decode(Action.self, from: $0)
                    } catch {
                        Logger.pendingActions.error("Couldn't decode pending action \($0).")
                        return nil
                    }
                }
                .filter { $0.projectId == projectId }
            let localCommands = actions
                .map(\.command.localCommand) // Action => LocalCommand
                .filter { $0.targetIds.contains(targetObjectId) }
            return localCommands
        }
    }

    /// Starts synchronization - observe network and perform any pending actions
    func start() {
        // check if there are any pending actions
        operationQueue.async {
            self.maybeScheduleNextAttempt()
            self.maybePerformAction()
        }
        networkMonitor.pathUpdateHandler = { [weak self] _ in
            guard let self = self else { return }
            // network conditions have changed, check if actions can be performed and try, maybe
            // something is pending
            if self._networkConditionsMet() {
                self.maybePerformAction()
            }
        }
        networkMonitor.start(queue: operationQueue)
    }

    func stop() {
        networkMonitor.cancel()
    }

    /// Return true if network connected
    private func _networkConditionsMet() -> Bool {
        networkMonitor.currentPath.status == .satisfied
    }

    /// Adds pending action data to the end of the pending actions array
    /// To be invoked on the `operationQueue`
    private func addPendingAction(data: Data) {
        var actions = pendingActions()
        actions.append(data)
        setPendingActions(actions)
    }

    /// When action is done this removes the first action from the pending actions array
    /// To be invoked on the `operationQueue`
    private func removeFirstPendingAction() {
        var actions = pendingActions()
        if !actions.isEmpty {
            actions.removeFirst()
            setPendingActions(actions)
        }
    }

    /// To be invoked on the `operationQueue`
    private func pendingActions() -> [Data] {
        UserDefaults.standard.array(forKey: DefaultsKey.actions) as? [Data] ?? []
    }

    /// To be invoked on the `operationQueue`
    private func setPendingActions(_ actions: [Data]) {
        UserDefaults.standard.set(actions, forKey: DefaultsKey.actions)
    }

    /// Resets the retry count and other properties related to retrying the failed actions
    /// Called when moving to next action
    private func resetRetryInfo() {
        UserDefaults.standard.set(0, forKey: DefaultsKey.retryCount)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.nextAttemptAt)
        UserDefaults.standard.removeObject(forKey: DefaultsKey.lastError)
    }

    /// For easy read access to defaults
    var retryCount: Int { UserDefaults.standard.integer(forKey: DefaultsKey.retryCount) }
    var nextAttemptAt: Double? {
        // instead of .double(forKey:) to get nil if not present
        UserDefaults.standard.object(forKey: DefaultsKey.nextAttemptAt) as? Double
    }

    /// Based on the retryCount/nextAttemptAt decide if now is a good time to try applying pending action
    private func shouldAttempt() -> Bool {
        if retryCount == 0 {
            // not tried yet
            return true
        }
        if let nextAttemptAt = nextAttemptAt {
            return Date.now >= Date(timeIntervalSince1970: nextAttemptAt)
        } else {
            // next attempt not scheduled, perform now
            return true
        }
    }

    /// if nextAttemptAt is set it schedules the next `maybePerformAction` based on it
    private func maybeScheduleNextAttempt() {
        guard let nextAttemptAt = nextAttemptAt else { return }
        // schedule next attempt based on nextAttemptAt
        let nextTryIn = nextAttemptAt - Date.now.timeIntervalSince1970
        guard nextTryIn > 0 else { return }
        Logger.pendingActions.debug("Backoff, schedule next attempt in \(nextTryIn)seconds")
        operationQueue.asyncAfter(deadline: .now() + nextTryIn) { [weak self] in
            self?.maybePerformAction()
        }
    }

    /// Increase the retry count and handle the exponential backoff
    /// Called when the action failed
    private func increaseRetryCount(error: Error) {
        UserDefaults.standard.set(retryCount + 1, forKey: DefaultsKey.retryCount)
        let nextAttemptAt = Date.now.timeIntervalSince1970 + min(pow(2, Double(retryCount)), maxBackoff)
        UserDefaults.standard.set(nextAttemptAt, forKey: DefaultsKey.nextAttemptAt)
        UserDefaults.standard.set(error.localizedDescription, forKey: DefaultsKey.lastError)
    }

    /// Checks if no action is performing currently, if there's a pending action, and if the retry conditions are met. It then performs the action
    /// or schedules perform in the future (for exponential backoff)
    /// To be invoked on the `operationQueue`
    private func maybePerformAction() {
        // action is performing, do nothing
        guard !performingAction else { return }

        // get 1st action data
        guard let actionData = pendingActions().first else { return }

        // try to decode to Action or drop it if cannot be decoded
        let action: Action
        do {
            action = try jsonDecoder.decode(Action.self, from: actionData)
        } catch {
            // drop this action if it fails to decode
            Logger.pendingActions.error("Couldn't decode pending action \(actionData). Dropping action!")
            // remove this action from the 'queue' and clean the retry info so next action starts fresh
            removeFirstPendingAction()
            resetRetryInfo()
            // try next one, but async as this needs to return
            operationQueue.async {
                self.maybePerformAction()
            }
            return
        }

        // try if action should be run based on the retryCount/nextAttemptAt, if not then schedule
        // `maybePerformAction` based on nextAttemptAt
        guard shouldAttempt() else {
            // these variables need to be declared here as otherwise the autoformatter is not happy :(
            // (when using properties in the log string)
            let retryCount = retryCount
            let nextAttemptAt = nextAttemptAt != nil ? Date(timeIntervalSince1970: nextAttemptAt!)
                .debugDescription : "n/a"
            Logger.pendingActions.debug("Backoff, retryCount: \(retryCount), nextAttemptAt: \(nextAttemptAt)")
            return
        }
        // mark that action is being performed
        performingAction = true

        performAction(action) { error in
            let goToNext: Bool // is processing of this action done?
            if let error = error {
                Logger.pendingActions.debug("Action error: \(error)")
                let obsolete: Bool
                if let error = error as? FirestoreCommandError, case .obsolete = error {
                    // obsolete action is dropped so it's done
                    obsolete = true
                    Logger.pendingActions
                        .warning("Dropping obsolete action \(action.debugDescription, privacy: .private)")
                } else if (error as NSError).domain == FirestoreErrorDomain,
                          (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
                {
                    // permission denied => drop the action and notify the user
                    obsolete = true
                    Logger.pendingActions
                        .warning(
                            "Dropping action, permission denied: \(action.debugDescription, privacy: .private)"
                        )
                    let actionName = String(describing: type(of: action.command.localCommand))
                    // This is a rather technical message shown to the user but it's better than
                    // nothing... Also this doesn't rollback the local action, but since the action
                    // is removed from local actions the next sync will overwrite it's results (unless it was creating something)
                    // So we need something better than that...
                    ToastWindow.shared.showError(text: "You don't have permission for \(actionName), aborting!")
                } else {
                    // there's some non-obsolete error, retry the action
                    obsolete = false
                }
                SentrySDK.capture(error: error) { scope in
                    scope.setExtras([
                        "projectId": action.projectId,
                        // the string with all command properties dumped:
                        "targetIds": action.command.localCommand.targetIds.joined(separator: ","),
                    ])
                    // the name of the struct implementing the command:
                    scope.setTag(value: String(describing: type(of: action.command.localCommand)), key: "command")
                    scope.setTag(value: obsolete.description, key: "obsolete")
                }
                goToNext = obsolete
            } else {
                // no error
                Logger.pendingActions.debug("Action succeeded: \(action.debugDescription, privacy: .private)")
                goToNext = true
            }
            self.operationQueue.sync {
                if goToNext {
                    // remove this action from the 'queue' and clean the retry info so next action starts fresh
                    self.removeFirstPendingAction()
                    self.resetRetryInfo()
                } else {
                    // failed, handle retry count for exponential backoff (error is not nil when goToNext = false)
                    self.increaseRetryCount(error: error!)
                    self.maybeScheduleNextAttempt()
                }
            }
            // at the end, no matter what result, mark as not performing
            self.operationQueue.async {
                self.performingAction = false
                // maybe there's a next pending action already waiting
                if goToNext {
                    self.maybePerformAction()
                }
            }
        }
    }

    /// To be only called from `maybePerformAction`
    private func performAction(_ action: Action, completion: @escaping (Error?) -> Void) {
        firestore.runTransaction { transaction, errorPointer -> Any? in
            let context = TransactionalFirestoreCommandContext(
                transaction: transaction,
                firestore: self.firestore,
                projectId: action.projectId
            )
            do {
                try action.command.firestoreCommand.apply(inFirestore: context)
            } catch let error as NSError {
                errorPointer?.pointee = error
                return false
            }
            // don't return nil, it's supposed to work but it crashes
            return true
        } completion: { _, error in
            completion(error)
        }
    }
}
