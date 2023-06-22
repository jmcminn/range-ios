import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationsDueDateCommand` in local Realm db
final class UpdateCollaborationsDueDateCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationsDueDateCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            dueDateTimestamp: nil
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationsDueDateCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            dueDateTimestamp: Date(timeIntervalSince1970: 100)
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertNil(
            realm.object(ofType: Update.self, forPrimaryKey: command.updateIds[0]),
            "Update is not created when running command in Realm"
        )
        XCTAssertEqual(collaboration1.dueDateTimestamp?.timeIntervalSince1970, 100)
    }
}

/// Tests applying `UpdateCollaborationDueDateCommand` to Firestore
final class UpdateCollaborationsDueDateCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationsDueDateCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            dueDateTimestamp: nil
        )
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("collaboration doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1",
                timestamp: Timestamp(),
                statusId: nil,
                name: "name",
                collaborationDescription: nil,
                tagIds: []
            ),
            .collaboration("collaboration2"): FirestoreCollaboration(
                featureId: "feature2",
                timestamp: Timestamp(),
                statusId: nil,
                name: "name",
                collaborationDescription: nil,
                tagIds: [],
                dueDateTimestamp: Timestamp(seconds: 100, nanoseconds: 0)

            ),
        ])

        let command = UpdateCollaborationsDueDateCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            dueDateTimestamp: Date(timeIntervalSince1970: 100)
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["dueDateTimestamp": Timestamp(seconds: 100, nanoseconds: 0)])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateIds[0]), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.dueDateTimestamp.rawValue,
                "newValue": Timestamp(seconds: 100, nanoseconds: 0),
            ])
        )
    }

    func testApply_successful_unset() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1",
                timestamp: Timestamp(),
                statusId: nil,
                name: "old name",
                collaborationDescription: nil,
                tagIds: [],
                dueDateTimestamp: Timestamp(seconds: 100, nanoseconds: 0)
            ),
        ])

        let command = UpdateCollaborationsDueDateCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            dueDateTimestamp: nil
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["dueDateTimestamp": FieldValue.delete()])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateIds[0]), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.dueDateTimestamp.rawValue,
                "oldValue": Timestamp(seconds: 100, nanoseconds: 0),
            ])
        )
    }
}
