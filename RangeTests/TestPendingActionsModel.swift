import Foundation
@testable import Range

/// Test implementation of PendingActionsModel that records `prepareAction` calls but otherwise does nothing
class TestPendingActionsModel: PendingActionsModel {
    private(set) var preparedActions = [Action]()

    func prepareAction(_ action: Action) throws -> Data {
        preparedActions.append(action)
        return Data()
    }

    func addAction(data _: Data) {}

    func getLocalCommands(forProjectId _: String, targetObjectId _: String) -> [LocalCommand] { [] }
}
