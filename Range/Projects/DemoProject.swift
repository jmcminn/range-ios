import Foundation

/// Defines a hardcoded information for a demo project to show in the app (until there's a real implementation of project selection)
/// The project with given id needs to exist in the Firestore
struct DemoProject {
    /// real project id
    var id: String
    /// name of the project (to display on the demo project selection)
    var name: String
    /// demo canvas data
    var canvas: DemoCanvas

    static let vanderbilt = DemoProject(
        id: "474503d1-1adc-4268-88fe-2a797148f16d",
        name: "5451 Vanderbilt Ave",
        canvas: DemoCanvas(
            id: "e5db7eb2-bd9f-44ba-9c90-e6e6e528b930",
            localFileName: "5451 VANDERBILT AVE-A1.1A.pdf",
            pageNumber: 0
        )
    )
    static let preserve = DemoProject(
        id: "7fd7c334-9ba2-4cba-9b02-0821a9028d0c",
        name: "The Preserve",
        canvas: DemoCanvas(
            id: "af6872c7-aa39-487a-9ee5-ff532300ab75",
            localFileName: "The Preserve v01.pdf",
            pageNumber: 1
        )
    )
}

/// Defines a hardcoded information for a demo canvas of a demo project
/// The canvas with given id needs to exist in the Firestore. The localFileName is used instead of `Canvas.url` as canvas pdf
/// downloading is not implemented yet.
struct DemoCanvas {
    /// Real canvas id
    var id: String
    /// The name of a local file from "DemoResources" folder.
    var localFileName: String
    /// 0-based PDF page number to show
    var pageNumber: Int
}
