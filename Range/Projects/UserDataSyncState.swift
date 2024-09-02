import Combine
import Foundation

class UserDataSyncState: ObservableObject {
    enum State {
        case offlinePending // there's some pending items with not met network conditions
        case onlineSync // there's some pending items with network conditions met to sync
        case noPending // there's no pending data or uploads to sync
    }

    private let pendingActionsModel: PendingActionsModel
    private let pendingUploadsModel: PendingUploadsModel

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    @Published var state: State = .noPending

    init(pendingActionsModel: PendingActionsModel, pendingUploadsModel: PendingUploadsModel) {
        self.pendingActionsModel = pendingActionsModel
        self.pendingUploadsModel = pendingUploadsModel
        Publishers.CombineLatest4(
            pendingActionsModel.$hasPendingActions,
            pendingActionsModel.$networkConditionsMet,
            pendingUploadsModel.$hasPendingUploads,
            pendingUploadsModel.$networkConditionsMet
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in self?.maybeUpdateState() }
        .store(in: &subscriptions)
    }

    private func maybeUpdateState() {
        let newState = calculateState()

        // switch to syncing state with delay. In case the user is online we
        // don't want to show the sync indicator on each operation
        if newState == .onlineSync {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self else { return }
                self.state = calculateState()
            }
        } else {
            state = newState
        }
    }

    private func calculateState() -> State {
        let hasPendingActions = pendingActionsModel.hasPendingActions
        let pendingActionsNetworkConditionsMet = pendingActionsModel.networkConditionsMet
        let hasPendingUploads = pendingUploadsModel.hasPendingUploads
        let pendingUploadsNetworkConditionsMet = pendingUploadsModel.networkConditionsMet

        // if (offline and has pending) for at least one model => then show offline
        // else if has pending for at least one model => then show online
        // else nothing
        // So: it doesn't matter if the action is being done now or not... (because the UI
        // doesn't care, there are only 3 different UI states)
        if (hasPendingActions && !pendingActionsNetworkConditionsMet) ||
            (hasPendingUploads && !pendingUploadsNetworkConditionsMet)
        {
            return .offlinePending
        } else if hasPendingActions || hasPendingUploads {
            return .onlineSync
        } else {
            return .noPending
        }
    }
}
