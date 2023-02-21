import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

class FirestoreUploadRealmSyncTest: XCTestCase {
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

    // MARK: - upsert tests

    func testUpsert_wrongParentType() throws {
        let firestoreUpload = FirestoreUpload(
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: Timestamp(),
            name: "name",
            uploadDescription: "description",
            correlationId: "upload1",
            tagIds: ["tag1"]
        )
        XCTAssertThrowsError(
            try realm.write {
                try firestoreUpload.upsert(withId: "upload1", inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }

    // Adds a parent and author placeholders if not found
    func testUpsert_createPlaceholders() throws {
        let firestoreUpload = FirestoreUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user2",
            timestamp: Timestamp(),
            correlationId: "upload1",
            tagIds: []
        )
        try realm.write {
            try firestoreUpload.upsert(withId: "upload1", inRealm: realm)
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

    func testUpsert_successful() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date.now,
            name: "Collaboration1",
            description: ""
        )
        let collaboration2 = Collaboration(
            id: "collaboration2",
            timestamp: Date.now,
            name: "Collaboration2",
            description: ""
        )
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.uploads.count, 0)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 2. add upload to collaboration1
        var firestoreUpload1 = FirestoreUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: Timestamp(seconds: 1, nanoseconds: 0),
            name: "upload 1",
            uploadDescription: "upload 1 description",
            correlationId: "upload1",
            tagIds: []
        )
        try realm.write {
            try firestoreUpload1.upsert(withId: "upload1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        let upload1 = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"), "upload1 not found")
        XCTAssertEqual(upload1.timestamp.timeIntervalSince1970, 1)
        XCTAssertEqual(upload1.name, "upload 1")
        XCTAssertEqual(upload1.uploadDescription, "upload 1 description")
        XCTAssertEqual(upload1.author, user1)

        // 3. update upload1
        firestoreUpload1.name = "upload 1 ..."
        try realm.write {
            try firestoreUpload1.upsert(withId: "upload1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        XCTAssertEqual(upload1.name, "upload 1 ...")

        // 4. add another upload to collaboration1
        let firestoreUpload2 = FirestoreUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: Timestamp(),
            name: "upload 2",
            uploadDescription: "upload 2 description",
            correlationId: "upload2",
            tagIds: []
        )
        try realm.write {
            try firestoreUpload2.upsert(withId: "upload2", inRealm: realm)
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

        // given an upload with tag1 and tag2 and a duplicate of tag1
        var firestoreUpload = FirestoreUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: Timestamp(),
            correlationId: "upload1",
            tagIds: ["tag1", "tag2", "tag1"]
        )
        try realm.write {
            try firestoreUpload.upsert(withId: "upload1", inRealm: realm)
        }
        // tags have the upload attached
        let upload = try XCTUnwrap(realm.object(ofType: Upload.self, forPrimaryKey: "upload1"))
        XCTAssertEqual(upload.tags.map(\.id), ["tag1", "tag2"])
        XCTAssertEqual(tag1.uploads.count, 1)
        XCTAssertEqual(tag2.uploads.count, 1)
        XCTAssertEqual(tag3.uploads.count, 0)

        // when switching upload tags
        firestoreUpload.tagIds = ["tag2", "tag3"]
        try realm.write {
            try firestoreUpload.upsert(withId: "upload1", inRealm: realm)
        }

        // then tag <-> upload links are updated
        XCTAssertEqual(upload.tags.map(\.id), ["tag2", "tag3"])
        XCTAssertEqual(tag1.uploads.count, 0)
        XCTAssertEqual(tag2.uploads.count, 1)
        XCTAssertEqual(tag3.uploads.count, 1)
    }
}
