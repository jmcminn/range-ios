import CoreLocation
import FirebaseFirestore
@testable import Range
import RealmSwift
import Turf
import XCTest

/// Tests applying `CreateCollaborationCommand` in local Realm db
final class CreateCollaborationCommandRealmTest: ProjectModelTestCase {
    var command: CreateCollaborationCommand {
        CreateCollaborationCommand(
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
                .init(mediaKey: _mediaKey(uploadId: "upload1"), fileSize: 1024, imageHeightToWidth: 1.0),
                .init(mediaKey: _mediaKey(uploadId: "upload2"), fileSize: 1024, imageHeightToWidth: 2.0),
            ]
        )
    }

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
        let user1 = Participant(placeholderId: "user1")
        let user2 = Participant(placeholderId: "user2")
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
        let user1 = Participant(placeholderId: "user1")
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
        let user1 = Participant(placeholderId: "user1")
        let user2 = Participant(placeholderId: "user2")
        try realm.write {
            realm.add([canvas1, user1, user2])
        }
        try realm.write {
            try command.apply(inRealm: realm)
        }
        let geometry1 = try XCTUnwrap(realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"))
        XCTAssertEqual(geometry1.annotationType, .photoMarker)
        XCTAssertEqual(geometry1.geometry, .point(Point(CLLocationCoordinate2D(latitude: 32.5, longitude: -96.5))))

        let collaboration1 = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertEqual(collaboration1.geometry.first, geometry1)
        XCTAssertEqual(geometry1.collaborations.map(\.id), ["collaboration1"])
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

/// Tests getting the parameters for `CreateCollaborationCommand`Firebase function call
final class CreateCollaborationCommandFirebaseFunctionTest: XCTestCase {
    var command: CreateCollaborationCommand {
        CreateCollaborationCommand(
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
                .init(mediaKey: _mediaKey(projectId: "p1", uploadId: "upload1"),
                      fileSize: 1024, imageHeightToWidth: 1.0),
                .init(mediaKey: _mediaKey(projectId: "p1", uploadId: "upload2"),
                      fileSize: 1024, imageHeightToWidth: 2.0),
            ]
        )
    }

    func test_functionName() throws {
        XCTAssertEqual(command.functionName, "createCollaboration")
    }

    func test_functionData() throws {
        let data = command.functionData
        let expected: [String: Any?] = [
            "canvasId": "canvas1",
            "geometryId": "geometry1", "featureId": "feature1", "collaborationId": "collaboration1",
            "coordinates": [-96.5, 32.5], "name": "name", "description": "description",
            "assigneeId": "user2", "statusId": nil, "dueDateTimestamp": 100_000,
            "tags": [
                ["id": "tag3", "name": "tag 3"],
            ],
            "followers": [],
            "uploads": [
                ["id": "upload1",
                 "fileType": "jpeg", "fileSize": 1024, "imageHeightToWidth": 1,
                 "name": nil, "description": "upload description",
                 "tags": [
                     ["id": "tag1", "name": "tag 1"],
                     ["id": "tag2", "name": "tag 2"],
                 ],
                 "annotations": nil],
                ["id": "upload2",
                 "fileType": "jpeg", "fileSize": 1024, "imageHeightToWidth": 2,
                 "name": nil, "description": "upload description",
                 "tags": [
                     ["id": "tag1", "name": "tag 1"],
                     ["id": "tag2", "name": "tag 2"],
                 ],
                 "annotations": nil],
            ],
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
