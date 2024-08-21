import Combine
import Foundation

class UserDataSyncState: ObservableObject {
    enum State {
        case offlinePending // there's some pending items with not met network conditions
        case onlineSync // there's some pending items with network conditions met to sync
        case noPending // there's no pending data or uploads to sync
    }

    /// combine observers
    private var subscriptions = Set<AnyCancellable>()

    // TODO: 3026 debounce the listener a little bit if it switches between actions
    @Published var state: State = .noPending

    init(pendingActionsModel: PendingActionsModel, pendingUploadsModel: PendingUploadsModel) {
        Publishers.CombineLatest4(
            pendingActionsModel.$hasPendingActions,
            pendingActionsModel.$networkConditionsMet,
            pendingUploadsModel.$hasPendingUploads,
            pendingUploadsModel.$networkConditionsMet
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] values in self?.updateDataSyncState(values.0, values.1, values.2, values.3) }
        .store(in: &subscriptions)
    }

    private func updateDataSyncState(
        _ hasPendingActions: Bool,
        _ pendingActionsNetworkConditionsMet: Bool,
        _ hasPendingUploads: Bool,
        _ pendingUploadsNetworkConditionsMet: Bool
    ) {
        // if (offline and has pending) for at least one model => then show offline
        // else if has pending for at least one model => then show online
        // else nothing
        // So: it doesn't matter if the action is being done now or not... (because the UI
        // doesn't care, there are only 3 different UI states)
        if (hasPendingActions && !pendingActionsNetworkConditionsMet) ||
            (hasPendingUploads && !pendingUploadsNetworkConditionsMet)
        {
            state = .offlinePending
        } else if hasPendingActions || hasPendingUploads {
            state = .onlineSync
        } else {
            state = .noPending
        }
    }
}
