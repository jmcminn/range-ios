import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `UpdateGeometryArchivedCommand` in local Realm db
final class UpdateGeometryArchivedCommandRealmTest: XCTestCase {
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
        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: true)
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.geometryNotFound)
        }
    }

    func testApply_archive_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        try realm.write {
            realm.add(geometry)
        }
        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: true)
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertNotNil(geometry.archivedTimestamp)
    }

    func testApply_unarchive_successful() throws {
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))),
            archivedTimestamp: Date.now
        )
        try realm.write {
            realm.add(geometry)
        }
        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: false)
        try realm.write {
            try command.apply(inRealm: realm)
        }
        XCTAssertNil(geometry.archivedTimestamp)
    }
}

/// Tests applying `UpdateGeometryArchivedCommand` to Firestore
final class UpdateGeometryArchivedCommandFirestoreTest: XCTestCase {
    func testApply_noGeometry() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: true)
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("geometry doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_archive_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.geometry("geometry1")])

        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: true)

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.geometry("geometry1"), [
                "archivedTimestamp": FieldValue.serverTimestamp(),
            ])
        )
    }

    func testApply_unarchive_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.geometry("geometry1")])

        let command = UpdateGeometryArchivedCommand(geometryId: "geometry1", archive: false)

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 1)
        AssertOperationsEqual(
            context.operations[0],
            .update(.geometry("geometry1"), [
                "archivedTimestamp": FieldValue.delete(),
            ])
        )
    }
}
