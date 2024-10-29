import Foundation

/// Interface for classes to implement model for pending actions. There's only one real implementation - `PendingActionsModelImpl`,
/// but we need an interface for tests.
class PendingActionsModel: ObservableObject {
    /// Before adding the action to pending actions it needs to be transformed to Data first.
    /// This is a separate function from `addAction` so the project model can invoke it first and abort the local actions if this fails
    /// (so it's kind of a 2-phase commit)
    func prepareAction(_: Action) throws -> Data {
        fatalError("function to be implemented by subclasses")
    }

    /// Store action data obtained from `prepareAction` for execution
    func addAction(data _: Data) {
        fatalError("function to be implemented by subclasses")
    }

    /// Get pending local commands for given project and target object id
    func getLocalCommands(forProjectId _: String, targetObjectId _: String,
                          operationType _: CommandOperationType) -> [LocalCommand]
    {
        fatalError("function to be implemented by subclasses")
    }
    
    /// Get number of locally created Collaborations not synced yet to backend
    func getCollaborationCreatesCount(forProjectIds _: [String]) -> Int {
        fatalError("function to be implemented by subclasses")
    }
    
    /// Get number of locally created Uploads not synced yet to backend
    func getUploadCreatesCount(forProjectIds _: [String]) -> Int {
        fatalError("function to be implemented by subclasses")
    }

    init() {
        hasPendingActions = false
        networkConditionsMet = false
    }

    @Published var hasPendingActions: Bool
    @Published var networkConditionsMet: Bool
}
