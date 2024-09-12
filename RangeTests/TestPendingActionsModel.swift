import Foundation
@testable import Range

/// Test implementation of PendingActionsModel that records `prepareAction` calls but otherwise does nothing
class TestPendingActionsModel: PendingActionsModel {
    private(set) var preparedActions = [Action]()

    override func prepareAction(_ action: Action) throws -> Data {
        preparedActions.append(action)
        return Data()
    }

    override func addAction(data _: Data) {}

    override func getLocalCommands(
        forProjectId _: String,
        targetObjectId _: String,
        operationType _: CommandOperationType
    ) -> [LocalCommand] { [] }
}
