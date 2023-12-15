import Foundation

/// Protocol defining actions that projects flow can perform.
/// Required by the views sending actions, so they can use selectors for these functions.
/// See https://swiftrocks.com/understanding-the-ios-responder-chain.html for more info
@objc protocol ProjectsFlowActions: AnyObject {
    /// start the flow for creating the project
    func createProjectAction()
}

extension ProjectsFlowController: ProjectsFlowActions {
    func createProjectAction() {
        print("TODO: 2240")
    }
}
