import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `DeleteCollaborationsCommand` in local Realm db
final class DeleteCollaborationsCommandRealmTest: XCTestCase {
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

    func testApply_noCollaboration() throws {
        let command = DeleteCollaborationsCommand(geometryIds: ["geometry1"], collaborationIds: ["collaboration1"])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noFeature() throws {
        let collaboration = Collaboration(id: "collaboration1", timestamp: Date(), name: "", description: nil)
        try realm.write {
            realm.add(collaboration)
        }

        let command = DeleteCollaborationsCommand(geometryIds: ["geometry1"], collaborationIds: ["collaboration1"])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.featureNotFound)
        }
    }

    func testApply_noGeometry() throws {
        let collaboration = Collaboration(id: "collaboration1", timestamp: Date(), name: "", description: nil)
        let feature = Feature(id: "feature1", name: "", description: nil)
        try realm.write {
            realm.add([collaboration, feature])
            feature.collaborations.insert(collaboration)
        }

        let command = DeleteCollaborationsCommand(geometryIds: ["geometry1"], collaborationIds: ["collaboration1"])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.geometryNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration = Collaboration(id: "collaboration1", timestamp: Date(), name: "", description: nil)
        let feature = Feature(id: "feature1", name: "", description: nil)
        let geometry = Geometry(
            id: "geometry1",
            annotationType: .photoMarker,
            geometry: .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5)))
        )
        let comment = Comment(
            id: "comment1", timestamp: Date(), text: "",
            textIsEdited: false, isNote: false, completedTimestamp: nil
        )
        let upload = Upload(
            id: "upload1",
            timestamp: Date(),
            name: nil,
            description: nil,
            correlationId: "upload1",
            fileType: .jpeg,
            imageHeightToWidth: 1,
            fileSize: 1024
        )
        let update = Update(id: "update1", timestamp: Date(), field: .name, oldValue: .none, newValue: .string("name"))
        let tag = Tag(id: "tag1", name: "tag 1")
        try realm.write {
            realm.add([collaboration, feature, geometry, comment, upload, update, tag])
            feature.collaborations.insert(collaboration)
            geometry.features.insert(feature)
            collaboration.comments.insert(comment)
            collaboration.uploads.insert(upload)
            collaboration.updates.insert(update)
            collaboration.tags.append(tag)
            upload.tags.append(tag)
        }
        let command = DeleteCollaborationsCommand(geometryIds: ["geometry"], collaborationIds: ["collaboration1"])
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertTrue(geometry.isInvalidated)
        XCTAssertTrue(feature.isInvalidated)
        XCTAssertTrue(collaboration.isInvalidated)
        XCTAssertTrue(comment.isInvalidated)
        XCTAssertTrue(upload.isInvalidated)
        XCTAssertTrue(update.isInvalidated)
        XCTAssertEqual(tag.collaborations.count, 0)
        XCTAssertEqual(tag.uploads.count, 0)
        XCTAssertNil(realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"))
        XCTAssertNil(realm.object(ofType: Feature.self, forPrimaryKey: "feature1"))
        XCTAssertNil(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertNil(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
        XCTAssertNil(realm.object(ofType: Comment.self, forPrimaryKey: "comment1"))
        XCTAssertNil(realm.object(ofType: Update.self, forPrimaryKey: "update1"))
    }
}

/// Tests applying `DeleteCollaborationCommand` to Firestore
final class DeleteCollaborationCommandFirestoreTest: XCTestCase {
    func testApply_noOp_noCollaboration() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = DeleteCollaborationsCommand(geometryIds: ["geometry1"], collaborationIds: ["collaboration1"])
        try command.apply(inFirestore: context)
        XCTAssertEqual(context.operations.count, 0)
    }

    func testApply_successful() throws {
        let context = TestFirestoreCommandContext(docs: [.geometry("geometry1"), .geometry("geometry2")])

        let command = DeleteCollaborationsCommand(
            geometryIds: ["geometry1", "geometry2", "geometry3"],
            collaborationIds: ["collaboration1", "collaboration2", "collaboration3"]
        )

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(context.operations[0], .delete(.geometry("geometry1")))
        AssertOperationsEqual(context.operations[1], .delete(.geometry("geometry2")))
    }
}
