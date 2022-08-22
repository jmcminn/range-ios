import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddUploadCommandTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    @MainActor
    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            images: Images(projectId: ""),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // Adds a parent and author placeholders if not found
    func testApplyInRealm_createPlaceholders() throws {
        let cmd = AddUploadCommand(
            uploadId: "upload1",
            correlationId: "upload1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user2",
            timestamp: 1,
            name: nil,
            uploadDescription: nil,
            url: nil,
            tagIds: []
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        let collaboration = try XCTUnwrap(
            realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"),
            "collaboration1 not found"
        )
        XCTAssertTrue(collaboration.placeholder)
        let author = try XCTUnwrap(
            realm.object(ofType: Participant.self, forPrimaryKey: "user2"),
            "user2 not found"
        )
        XCTAssertTrue(author.placeholder)
    }

    func testAddUploadToCollaboration_successful() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        let collaboration2 = Collaboration(id: "collaboration2", name: "Collaboration2", description: "")
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.uploads.count, 0)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 2. add upload to collaboration1
        var cmd1 = AddUploadCommand(
            uploadId: "upload1",
            correlationId: "upload1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user1",
            timestamp: 1,
            name: "upload 1",
            uploadDescription: "upload 1 description",
            url: URL(string: "https://range.io/image"),
            tagIds: []
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        let upload1 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"), "upload1 not found")
        XCTAssertEqual(upload1.timestamp, 1)
        XCTAssertEqual(upload1.name, "upload 1")
        XCTAssertEqual(upload1.uploadDescription, "upload 1 description")
        XCTAssertEqual(upload1.author, user1)
        XCTAssertEqual(upload1.url?.absoluteString, "https://range.io/image")

        // 3. update upload1
        cmd1.name = "upload 1 ..."
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        XCTAssertEqual(upload1.name, "upload 1 ...")

        // 4. add another upload to collaboration1
        let cmd2 = AddUploadCommand(
            uploadId: "upload2",
            correlationId: "upload1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user1",
            timestamp: 1,
            name: "upload 2",
            uploadDescription: "upload 2 description",
            url: URL(string: "https://range.io/image"),
            tagIds: []
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
        }
        XCTAssertEqual(collaboration1.uploads.count, 2)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 5. remove upload2
        try realm.write {
            let upload2 = try XCTUnwrap(
                realm.object(ofType: Upload.self, forPrimaryKey: "upload2"),
                "upload2 not found"
            )
            realm.delete(upload2)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        XCTAssertEqual(collaboration1.uploads.first, upload1)
    }

    func testApplyInRealm_updateTags() throws {
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        let tag3 = Tag(id: "tag3", name: "tag 3")
        try realm.write {
            realm.add([tag1, tag2, tag3])
        }

        // given an upload with tag1 and tag2
        var cmd = AddUploadCommand(
            uploadId: "upload1",
            correlationId: "upload1",
            parentType: "Collaboration",
            parentId: "collaboration1",
            authorId: "user1",
            timestamp: 1,
            name: "upload 1",
            uploadDescription: "upload 1 description",
            url: URL(string: "https://range.io/image"),
            tagIds: ["tag1", "tag2"]
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        // tags have the upload attached
        let upload = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
        XCTAssertEqual(upload.tags.map(\.id), ["tag1", "tag2"])
        XCTAssertEqual(tag1.uploads.count, 1)
        XCTAssertEqual(tag2.uploads.count, 1)
        XCTAssertEqual(tag3.uploads.count, 0)

        // when switching upload tags
        cmd.tagIds = ["tag2", "tag3"]
        try realm.write {
            try cmd.apply(inRealm: realm)
        }

        // then tag <-> upload links are updated
        XCTAssertEqual(upload.tags.map(\.id), ["tag2", "tag3"])
        XCTAssertEqual(tag1.uploads.count, 0)
        XCTAssertEqual(tag2.uploads.count, 1)
        XCTAssertEqual(tag3.uploads.count, 1)
    }
}
