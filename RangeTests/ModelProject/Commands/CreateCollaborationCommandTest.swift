import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `CreateCollaborationCommand` in local Realm db
final class CreateCollaborationCommandRealmTest: ProjectModelTestCase {
    let command = CreateCollaborationCommand(
        authorId: "user1",
        canvasId: "canvas1",
        geometryId: "geometry1",
        featureId: "feature1",
        collaborationId: "collaboration1",
        coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
        name: "name",
        collaborationDescription: "description",
        assigneeId: "user2",
        dueDateTimestamp: Date(timeIntervalSince1970: 100),
        tags: [.init(id: "tag3", name: "tag 3")],
        uploadTags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
        uploadDescription: "upload description",
        uploads: [
            .init(id: "upload1", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 1.0),
            .init(id: "upload2", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 2.0),
        ]
    )

    func testApply_noCanvas() throws {
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.canvasNotFound)
        }
    }

    func testApply_noUser() throws {
        let canvas1 = Canvas(id: "canvas1", name: "")
        try realm.write {
            realm.add(canvas1)
        }
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_noStatus() throws {
        let canvas1 = Canvas(id: "canvas1", name: "")
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        let user2 = Participant(id: "user2", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([canvas1, user1, user2])
        }

        var command = command
        command.statusId = "status1"
        XCTAssertThrowsError(
            try realm.write {
                try command.apply(inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.statusNotFound)
        }
    }

    func testApply_noAssignee() throws {
        let canvas1 = Canvas(id: "canvas1", name: "")
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([canvas1, user1])
        }

        XCTAssertThrowsError(
            try realm.write {
                try command.apply(inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_successful() throws {
        let canvas1 = Canvas(id: "canvas1", name: "")
        let user1 = Participant(id: "user1", firstName: "", lastName: "", avatarUrl: nil, email: "")
        let user2 = Participant(id: "user2", firstName: "", lastName: "", avatarUrl: nil, email: "")
        try realm.write {
            realm.add([canvas1, user1, user2])
        }
        try realm.write {
            try command.apply(inRealm: realm)
        }
        let geometry1 = try XCTUnwrap(realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"))
        XCTAssertEqual(geometry1.annotationType, .photoMarker)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))))

        let feature1 = try XCTUnwrap(realm.object(ofType: Feature.self, forPrimaryKey: "feature1"))
        XCTAssertEqual(feature1.geometry.first, geometry1)
        XCTAssertEqual(geometry1.features.map(\.id), ["feature1"])

        let collaboration1 = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertEqual(collaboration1.feature.first, feature1)
        XCTAssertEqual(feature1.collaborations.map(\.id), ["collaboration1"])
        XCTAssertEqual(collaboration1.assignee, user2)
        XCTAssertEqual(collaboration1.name, "name")
        XCTAssertEqual(collaboration1.collaborationDescription, "description")
        XCTAssertEqual(collaboration1.dueDateTimestamp?.timeIntervalSince1970, 100)
        XCTAssertEqual(collaboration1.tags.map(\.id), ["tag3"])

        let tag1 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag1"), "tag1 not found")
        XCTAssertEqual(tag1.name, "tag 1")
        let tag2 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag2"), "tag2 not found")
        XCTAssertEqual(tag2.name, "tag 2")
        let upload1 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"), "upload1 not found")
        let upload2 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload2"), "upload2 not found")
        for upload in [upload1, upload2] {
            XCTAssertEqual(upload.author, user1)
            XCTAssertNil(upload.name)
            XCTAssertEqual(upload.uploadDescription, "upload description")
            XCTAssertEqual(upload.collaboration.first, collaboration1)
            XCTAssertEqual(upload.correlationId, upload.id)
            XCTAssertEqual(upload.fileType, .jpeg)
            XCTAssertEqual(upload.tags.map(\.id), ["tag1", "tag2"])
        }
        XCTAssertEqual(upload1.imageHeightToWidth, 1)
        XCTAssertEqual(upload2.imageHeightToWidth, 2)
        for tag in [tag1, tag2] {
            XCTAssertEqual(tag.uploads.map(\.id), ["upload1", "upload2"])
        }
        XCTAssertEqual(collaboration1.uploads.map(\.id), ["upload1", "upload2"])

        let tag3 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag3"), "tag2 not found")
        XCTAssertEqual(tag3.name, "tag 3")
        XCTAssertEqual(tag3.collaborations.map(\.id), ["collaboration1"])
    }
}

/// Tests applying `CreateCollaborationCommand` in to Firestore (using a mock for FirestoreCommandContext)
final class CreateCollaborationCommandFirestoreTest: XCTestCase {
    let command = CreateCollaborationCommand(
        authorId: "user1",
        canvasId: "canvas1",
        geometryId: "geometry1",
        featureId: "feature1",
        collaborationId: "collaboration1",
        coordinates: CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5),
        name: "name",
        collaborationDescription: "description",
        assigneeId: "user2",
        dueDateTimestamp: Date(timeIntervalSince1970: 100),
        tags: [.init(id: "tag3", name: "tag 3")],
        uploadTags: [.init(id: "tag1", name: "tag 1"), .init(id: "tag2", name: "tag 2")],
        uploadDescription: "upload description",
        uploads: [
            .init(id: "upload1", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 1.0),
            .init(id: "upload2", fileType: .jpeg, fileSize: 1024, imageHeightToWidth: 2.0),
        ]
    )

    func testApply_noCanvas() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("canvas doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noUser() throws {
        // canvas exists but user doesn't
        let context = TestFirestoreCommandContext(docs: [.canvas("canvas1")])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("user doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noAssignee() throws {
        // canvas exists but user doesn't
        let context = TestFirestoreCommandContext(docs: [
            .canvas("canvas1"),
            .participant("user1"),
            .tagName("tag1"),
        ])

        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("user doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // canvas and user exist
        // there's also tag1 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .canvas("canvas1"),
            .participant("user1"), .participant("user2"),
            .tagName("tag1"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 7)
        AssertOperationsEqual(
            context.operations[0],
            .set(.geometry("geometry1"), [
                "canvas": "canvas1",
                "annotationType": "photoMarker",
                "coordinates": "[-96.5,32.5]",
            ])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.feature("feature1"), [
                "geometry": "geometry1",
                "name": "",
            ])
        )
        AssertOperationsEqual(
            context.operations[2],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[3],
            .set(.collaboration("collaboration1"), [
                "feature": "feature1",
                "author": "user1",
                "timestamp": FieldValue.serverTimestamp(),
                "name": "name",
                "description": "description",
                "assignee": "user2",
                "dueDateTimestamp": Timestamp(seconds: 100, nanoseconds: 0),
                "tags": ["tag3"],
            ])
        )
        AssertOperationsEqual(
            context.operations[4],
            .set(.tagName("tag2"), ["name": "tag 2"])
        )
        AssertOperationsEqual(
            context.operations[5],
            .set(.upload("upload1"), [
                "parent": "collaboration1", "parentType": "Collaboration",
                "correlation": "upload1", "author": "user1", "timestamp": FieldValue.serverTimestamp(),
                "tags": ["tag1", "tag2"], "description": "upload description",
                "fileType": "jpeg", "imageHeightToWidth": 1.0, "fileSize": 1024,
            ])
        )
        AssertOperationsEqual(
            context.operations[6],
            .set(.upload("upload2"), [
                "parent": "collaboration1", "parentType": "Collaboration",
                "correlation": "upload2", "author": "user1", "timestamp": FieldValue.serverTimestamp(),
                "tags": ["tag1", "tag2"], "description": "upload description",
                "fileType": "jpeg", "imageHeightToWidth": 2.0, "fileSize": 1024,
            ])
        )
    }

    /// Test for idempotency
    /// All objects already exist, meaning this operation was already run
    func testApply_noOp() throws {
        // all objects exist
        let context = TestFirestoreCommandContext(docs: [
            .canvas("canvas1"),
            .participant("user1"), .participant("user2"),
            .geometry("geometry1"),
            .feature("feature1"),
            .collaboration("collaboration1"),
            .tagName("tag1"), .tagName("tag2"), .tagName("tag3"),
            .upload("upload1"), .upload("upload2"),
        ])

        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 0)
    }
}
