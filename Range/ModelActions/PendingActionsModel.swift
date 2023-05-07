import Foundation

/// Interface for classes to implement model for pending actions. There's only one real implementation - `PendingActionsModelImpl`,
/// but we need an interface for tests.
protocol PendingActionsModel: AnyObject {
    /// Before adding the action to pending actions it needs to be transformed to Data first.
    /// This is a separate function from `addAction` so the project model can invoke it first and abort the local actions if this fails
    /// (so it's kind of a 2-phase commit)
    func prepareAction(_ action: Action) throws -> Data

    /// Store action data obtained from `prepareAction` for execution
    func addAction(data: Data)

    /// Get pending local commands for given project and target object id
    func getLocalCommands(forProjectId projectId: String, targetObjectId: String) -> [LocalCommand]
}
