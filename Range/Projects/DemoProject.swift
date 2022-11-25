import Foundation

/// Defines a hardcoded information for a demo project to show in the app (until there's a real implementation of project selection)
/// The project with given id needs to exist in the Firestore
struct DemoProject {
    /// real project id
    var id: String
    /// name of the project (to display on the demo project selection)
    var name: String
    /// id for the hardcoded canvas to show
    var canvasId: String

    static let vanderbilt = DemoProject(
        id: "474503d1-1adc-4268-88fe-2a797148f16d",
        name: "5451 Vanderbilt Ave",
        canvasId: "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930"
    )
    static let preserve = DemoProject(
        id: "7fd7c334-9ba2-4cba-9b02-0821a9028d0c",
        name: "The Preserve",
        canvasId: "af6872c7-aa39-487a-9ee5-ff532300ab75"
    )
}
