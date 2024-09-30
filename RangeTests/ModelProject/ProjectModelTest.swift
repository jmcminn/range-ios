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
            realm.add(ProjectSummary(placeholderId: model.projectId))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.currentUserNotFound)
        }
    }

    func testLoadProject_noCanvas() throws {
        try realm.write {
            realm.add(ProjectSummary(placeholderId: model.projectId))
            realm.add(Participant(placeholderId: "user1"))
        }
        XCTAssertThrowsError(
            try model.loadProject(initialCanvasId: "canvas1")
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testLoadProject_noCanvasSource() throws {
        try realm.write {
            realm.add(ProjectSummary(placeholderId: model.projectId))
            realm.add(Participant(placeholderId: "user1"))
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
            realm.add(ProjectSummary(id: model.projectId, name: "project name", organizationId: "organization1",
                                     center: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
                                     description: nil, address: nil, projectType: .architecture))
            realm.add(Participant(placeholderId: "user1"))
            let canvas = Canvas(id: "canvas1", name: "")
            let canvasSource = CanvasSource(placeholderId: "canvasSource1")
            realm.add([canvas, canvasSource])
            canvas.canvasSources.insert(canvasSource)
        }
        try model.loadProject(initialCanvasId: "canvas1")
        XCTAssertEqual(model.projectSummary.id, model.projectId)
        XCTAssertEqual(model.projectSummary.name, "project name")
        XCTAssertEqual(model.projectSummary.center.longitude, -96.5, accuracy: 0.000000001)
    }
}
