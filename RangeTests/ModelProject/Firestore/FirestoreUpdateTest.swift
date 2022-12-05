import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

class FirestoreUpdateRealmSyncTest: XCTestCase {
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
            imageCaches: ImageCaches(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // MARK: - encode/decode tests

    func testDecode_unsupportedValueType() {
        let inputString = """
        {
            "parent": "13083d62-03a1-43d7-8eb0-ca5bb8b357f3",
            "parentType": "Collaboration",
            "timestamp": { "seconds": 1649228400, "nanoseconds": 0 },
            "user": "9e06df97-aa0f-4e0f-8c78-8892bfb126ec",
            "field": "name",
            "oldValue": false
        }
        """
        guard let inputData = inputString.data(using: .utf8) else {
            XCTFail("no input data"); return
        }
        XCTAssertThrowsError(
            try JSONDecoder().decode(FirestoreUpdate.self, from: inputData)
        ) { error in
            guard let error = error as? StringOrDate.StringOrDateError, case .missingValue = error else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    // MARK: - upsert tests

    func testUpsert_wrongParentType() throws {
        let firestoreUpdate = FirestoreUpdate(
            parentId: "feature1",
            parentType: "Feature",
            timestamp: Timestamp(),
            userId: "user1",
            field: "name"
        )
        XCTAssertThrowsError(
            try realm.write {
                try firestoreUpdate.upsert(withId: "update1", inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }

    func testUpsert_unsupportedField() throws {
        let firestoreUpdate = FirestoreUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Timestamp(),
            userId: "user1",
            field: "length"
        )
        XCTAssertThrowsError(
            try realm.write {
                try firestoreUpdate.upsert(withId: "update1", inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error.localizedDescription, "length field not supported")
        }
    }

    // Adds a parent and author placeholders if not found
    func testUpsert_createPlaceholders() throws {
        let firestoreUpdate = FirestoreUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Timestamp(),
            userId: "user2",
            field: "name"
        )
        try realm.write {
            try firestoreUpdate.upsert(withId: "update1", inRealm: realm)
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

        // 2. add update to collaboration1
        let firestoreUpdate1 = FirestoreUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Timestamp(seconds: 1, nanoseconds: 0),
            userId: "user1",
            field: "name",
            oldValue: nil,
            newValue: .string("after")
        )
        try realm.write {
            try firestoreUpdate1.upsert(withId: "update1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.updates.count, 1)
        XCTAssertEqual(collaboration2.updates.count, 0)
        let update1 = try XCTUnwrap(realm.object(ofType: Update.self, forPrimaryKey: "update1"), "update1 not found")
        XCTAssertEqual(update1.timestamp.timeIntervalSince1970, 1)
        XCTAssertEqual(update1.user, user1)
        XCTAssertEqual(update1.field, Update.Field.name)
        XCTAssertEqual(update1.oldValue, .none)
        XCTAssertEqual(update1.newValue, .string("after"))

        // 4. add another update to collaboration1
        let firestoreUpdate2 = FirestoreUpdate(
            parentId: "collaboration1",
            parentType: "Collaboration",
            timestamp: Timestamp(),
            userId: "user1",
            field: "name",
            oldValue: .string("before"),
            newValue: nil
        )
        try realm.write {
            try firestoreUpdate2.upsert(withId: "update2", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.updates.count, 2)
        XCTAssertEqual(collaboration2.updates.count, 0)
        let update2 = try XCTUnwrap(realm.object(ofType: Update.self, forPrimaryKey: "update2"), "update2 not found")
        XCTAssertEqual(update2.field, Update.Field.name)
        XCTAssertEqual(update2.oldValue, .string("before"))
        XCTAssertEqual(update2.newValue, .none)
    }
}
