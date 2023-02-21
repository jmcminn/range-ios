import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `UpdateGeometryLocationCommand` in local Realm db
final class UpdateGeometryLocationCommandRealmTest: XCTestCase {
    let pendingUploadsModel = TestPendingUploadsModel()
    let pendingActionsModel = TestPendingActionsModel()
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            localFiles: LocalFiles(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    func testApply_noGeometry() throws {
        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas1",
            coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.geometryNotFound)
        }
    }

    func testApply_noCanvas() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            realm.add(geometry)
        }

        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testApply_archive_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let canvas1 = PDFCanvas(placeholderId: "canvas1")
        let canvas2 = PDFCanvas(placeholderId: "canvas2")
        try realm.write {
            realm.add([geometry, canvas1, canvas2])
            canvas1.geometries.insert(geometry)
        }
        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertTrue(canvas1.geometries.isEmpty)
        XCTAssertTrue(canvas2.geometries.contains(geometry))
        XCTAssertEqual(geometry.geometry, .point(Point(CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5))))
    }
}

/// Tests applying `UpdateGeometryLocationCommand` to Firestore
final class UpdateGeometryLocationCommandFirestoreTest: XCTestCase {
    func testApply_noGeometry() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas1",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("geometry doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noCanvas() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [.geometry("geometry1")])

        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas1",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("canvas doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.geometry("geometry1"), .canvas("canvas2")])

        let command = try UpdateGeometryLocationCommand(
            geometryId: "geometry1",
            canvasId: "canvas2",
            coordinates: CLLocationCoordinate2D(latitude: 33.5, longitude: -96.5)
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.geometry("geometry1"), [
                "canvas": "canvas2",
                "coordinates": "[-96.5,33.5]",
            ])
        )
    }
}
