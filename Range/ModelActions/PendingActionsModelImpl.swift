import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation
import Network
import OSLog
import Sentry

/// Stores Actions to be run against the server side.
/// Runs the actions when the network is available.
/// There's 1 global model (per user)  for pendings actions (not 1 per project), so each action keeps the projectId - we want to synchronize
/// the actions with the server side even if user is currently working with a different project (or hasn't opened any project)
class PendingActionsModelImpl: PendingActionsModel {
    let defaults: UserDefaults
    /// Firestore reference
    let firestore = Firestore.firestore()
    /// Firebase functions
    let firebaseFunctions = Functions.functions(region: "us-west2")

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
        /// The version of the actions stored in defaults. For tracking changes and migrating the pending actions
        static let actionsVersion = "actions.version"
        /// for storing pending actions = Array<Data>
        static let actions = "actions"
        /// How many times the current (first) action was already retried
        static let retryCount = "actions.retryCount"
        /// The timestamp for when there should be the next attempt to try action (not earlier than)
        static let nextAttemptAt = "actions.nextAttemptAt"
        /// Storing last error that caused the retry count to increase
        static let lastError = "actions.lastError"
    }

    var stopped = false

    init(userId: String) {
        defaults = UserDefaults.forUser(userId)
        // a default value for retry count when not set yet
        defaults.register(defaults: [DefaultsKey.retryCount: 0])

        let version = defaults.integer(forKey: DefaultsKey.actionsVersion)
        Logger.pendingActions.info("Version \(version)")

        // Run migration if version is 1 (or 0 = not provided, as we started versionsing from 2,
        // so no version = version 1)
        if version < 2 {
            // migrate
            Logger.pendingActions.info("Migrating \(version) to v2")
            let v1Data = pendingActions()
            let v2Data = _migrateV1PendingActions(data: v1Data)
            setPendingActions(v2Data)
            defaults.set(2, forKey: DefaultsKey.actionsVersion)
        }
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
        stopped = true
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
        defaults.array(forKey: DefaultsKey.actions) as? [Data] ?? []
    }

    /// To be invoked on the `operationQueue`
    private func setPendingActions(_ actions: [Data]) {
        defaults.set(actions, forKey: DefaultsKey.actions)
    }

    /// Resets the retry count and other properties related to retrying the failed actions
    /// Called when moving to next action
    private func resetRetryInfo() {
        defaults.set(0, forKey: DefaultsKey.retryCount)
        defaults.removeObject(forKey: DefaultsKey.nextAttemptAt)
        defaults.removeObject(forKey: DefaultsKey.lastError)
    }

    /// For easy read access to defaults
    var retryCount: Int { defaults.integer(forKey: DefaultsKey.retryCount) }
    var nextAttemptAt: Double? {
        // instead of .double(forKey:) to get nil if not present
        defaults.object(forKey: DefaultsKey.nextAttemptAt) as? Double
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
        defaults.set(retryCount + 1, forKey: DefaultsKey.retryCount)
        let nextAttemptAt = Date.now.timeIntervalSince1970 + min(pow(2, Double(retryCount)), maxBackoff)
        defaults.set(nextAttemptAt, forKey: DefaultsKey.nextAttemptAt)
        defaults.set(error.localizedDescription, forKey: DefaultsKey.lastError)
    }

    /// Checks if no action is performing currently, if there's a pending action, and if the retry conditions are met. It then performs the action
    /// or schedules perform in the future (for exponential backoff)
    /// To be invoked on the `operationQueue`
    private func maybePerformAction() {
        // stop performing actions if stopped
        guard !stopped else { return }
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
            SentrySDK.capture(error: "Pending action decoding failed") { scope in
                scope.setExtras([
                    "actionData": actionData,
                ])
                scope.setLevel(.warning)
            }
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

        Logger.pendingActions.info("Will perform action \(action.logDescription)")

        performAction(action) { [weak self] error in
            guard let self else { return }
            let goToNext: Bool // is processing of this action done?
            if let error = error {
                Logger.pendingActions.error("Error for action: \(action.debugDescription, privacy: .private)")
                let (dropAction, sentryLevel) = self.handleActionError(action, error)
                if let sentryLevel {
                    SentrySDK.capture(error: error) { scope in
                        scope.setExtras([
                            "projectId": action.projectId,
                            // the string with all command properties dumped:
                            "targetIds": action.command.localCommand.targetIds.joined(separator: ","),
                        ])
                        // the name of the struct implementing the command:
                        scope.setTag(value: String(describing: type(of: action.command.localCommand)), key: "command")
                        scope.setTag(value: dropAction.description, key: "dropped")
                        scope.setLevel(sentryLevel)
                    }
                }
                // don't remove the first pending action when stopped, the error might be caused by
                // user not authenticated or some random network errors
                goToNext = !stopped && dropAction
                if goToNext {
                    Logger.pendingActions
                        .error(
                            "Will drop errored action \(action.logDescription, privacy: .public), stopped: \(self.stopped)"
                        )
                }
            } else {
                // no error
                Logger.pendingActions.info("Action succeeded: \(action.logDescription, privacy: .public)")
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

    /// Handles the error by displaying logs, toasts, etc.
    /// Returns `true` if the action should be dropped because of the error. `false` means the operation should be retried.
    /// Returns optional SentryLevel for error reporting. If nil then it shouldn't be reported in Sentry at all
    private func handleActionError(_ action: Action, _ error: Error) -> (Bool, SentryLevel?) {
        Logger.pendingActions.debug("Action \(action.logDescription, privacy: .public) error: \(error)")
        if let error = error as? ActionError, case .notSupported = error {
            // not supported action is dropped so it's done
            Logger.pendingActions.debug("Dropping not supported action \(action.logDescription, privacy: .public)")
            // log it in Sentry as Error as this shouldn't really happen
            return (true, .error)
        } else if (error as NSError).domain == AuthErrorDomain,
                  (error as NSError).code == AuthErrorCode.networkError.rawValue
        {
            // network error, we need to retry
            Logger.pendingActions.debug(
                "Will retry action because user is offline: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
            )
            return (false, nil)
        } else if (error as NSError).domain == FirestoreErrorDomain,
                  (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
        {
            // --- FirestoreErrorDomain ------------------------------------------------------------
            // permission denied => drop the action and notify the user
            Logger.pendingActions
                .warning("Dropping action, permission denied: \(action.logDescription, privacy: .public)")
            // This is a rather technical message shown to the user but it's better than
            // nothing... Also this doesn't rollback the local action, but since the action
            // is removed from local actions the next sync will overwrite it's results (unless it was creating something)
            // So we need something better than that...
            ToastWindow.shared.showWarning(text: "You don't have permission for \(action.name), aborting!")
            // this probably shouldn't happen unless user was removed from project/org, report as warning
            // and let's see if it ever happens
            return (true, .warning)
        } else if (error as NSError).domain == FirestoreErrorDomain,
                  (error as NSError).code == FirestoreErrorCode.unavailable.rawValue
        {
            // --- FirestoreErrorDomain ------------------------------------------------------------
            // Error codes to be retried
            Logger.pendingActions.debug(
                "Will retry action: \(action.logDescription, privacy: .public) because of Firestore error: \(error, privacy: .public)"
            )
            return (false, nil)
        } else if let error = error as NSError?, error.domain == FunctionsErrorDomain,
                  let code = FunctionsErrorCode(rawValue: error.code)
        {
            // --- FunctionsErrorDomain ------------------------------------------------------------
            if code == .notFound || code == .failedPrecondition || code == .invalidArgument {
                // invalid arguments and failed preconditions probably require a fix (most
                // likely a mismatch between client side and server side validation)
                let message = error.localizedDescription
                Logger.pendingActions.error(
                    "Dropping action, callable function: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
                )
                ToastWindow.shared.showError(text: "\(action.name) failed: \(message), aborting!")
                return (true, .error)
            } else if code == .alreadyExists {
                // this is most probably a double invocation of a function, so it's ok to drop it
                Logger.pendingActions.warning(
                    "Dropping action, callable function: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
                )
                return (true, .warning)
            } else if code == .permissionDenied || code == .unauthenticated {
                ToastWindow.shared.showWarning(text: "You don't have permission for \(action.name), aborting!")
                Logger.pendingActions
                    .warning("Dropping action, permission denied: \(action.logDescription, privacy: .public)")
                // this probably shouldn't happen unless user was removed from project/org, report as warning
                // and let's see if it ever happens
                return (true, .warning)
            }
        } else if let error = error as NSError?, error.domain == NSURLErrorDomain {
            // --- NSURLErrorDomain ----------------------------------------------------------------
            // error codes reference: https://gist.github.com/samirahmed/ee52a076dd19966c4c9d
            if [
                NSURLErrorCannotConnectToHost, // -1004
                NSURLErrorNetworkConnectionLost, // -1005
                NSURLErrorNotConnectedToInternet, // -1009
            ].contains(error.code) {
                // this means we're offline and it's ok to retry
                Logger.pendingActions.debug(
                    "Will retry action because user is offline: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
                )
                return (false, nil)
            } else if error.code == -1200 {
                // this is SSL related error, let's log it as warning to observe if it doesn't escalate
                Logger.pendingActions.debug(
                    "Will retry action because user is offline: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
                )
                return (false, .warning)
            }
        }
        // there's some non-handled error, retry the action and log error in Sentry so we can add handling for it
        Logger.pendingActions.error(
            "Will retry action: \(action.logDescription, privacy: .public) error: \(error, privacy: .public)"
        )
        return (false, .error)
    }

    /// To be only called from `maybePerformAction`
    private func performAction(_ action: Action, completion: @escaping (Error?) -> Void) {
        if let functionCommand = action.command.firebaseFunctionCommand {
            Functions.functions(region: "us-west2")
                .httpsCallable(functionCommand.functionName)
                .call(functionCommand.functionData(action.projectId)) { _, error in
                    completion(error)
                }
        } else {
            // assert for debug builds but mark as obsolete in the prod app
            assertionFailure("Action command not supported \(action.name)")
            completion(ActionError.notSupported(action.name))
        }
    }
}
