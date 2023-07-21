import CoreLocation
@testable import Range
import RealmSwift
import XCTest

class ProjectModelTest: ProjectModelTestCase {
    func testLoadProject_emptyProject() throws {
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.summaryNotFound)
        }
    }

    func testLoadProject_noCurrentUser() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5), description: nil, address: nil))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.currentUserNotFound)
        }
    }

    func testLoadProject_noCanvas() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "project name", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5), description: nil,
                address: nil))
            realm.add(Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: ""))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testLoadProject_noCanvasSource() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "project name", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5), description: nil, address: nil))
            realm.add(Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: ""))
            realm.add(Canvas(id: "canvas1", name: ""))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasSourceNotFound)
        }
    }

    func testLoadProject_successful() throws {
        try realm.write {
            realm.add(ProjectSummary(id: model.projectId, name: "project name", center:
                CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5), description: nil, address: nil))
            realm.add(Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: ""))
            let canvas = Canvas(id: "canvas1", name: "")
            let canvasSource = CanvasSource(
                id: "canvasSource1", name: "",
                data: .pdf(PdfCanvasSourceData(pageNumber: 0, userDefinedScale: 1))
            )
            realm.add([canvas, canvasSource])
            canvas.canvasSources.insert(canvasSource)
        }
        try model.loadProject(initialCanvasId: "canvas1")
        XCTAssertEqual(model.projectSummary.id, model.projectId)
        XCTAssertEqual(model.projectSummary.name, "project name")
        XCTAssertEqual(model.projectSummary.center.longitude, -96.5, accuracy: 0.000000001)
    }
}
