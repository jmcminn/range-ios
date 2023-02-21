import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationDescriptionCommand` in local Realm db
final class UpdateCollaborationDescriptionCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "new description"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(
            id: "collaboration1",
            timestamp: Date(),
            name: "old name",
            description: "description"
        )
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "new description"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertNil(
            realm.object(ofType: Update.self, forPrimaryKey: command.updateId),
            "Update is not created when running command in Realm"
        )
        XCTAssertEqual(collaboration1.collaborationDescription, "new description")
    }
}

/// Tests applying `UpdateCollaborationDescriptionCommand` to Firestore
final class UpdateCollaborationDescriptionCommandFirestoreTest: XCTestCase {
    func testApply_noUpload() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "new description"
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
                collaborationDescription: "description",
                tagIds: []
            ),
        ])

        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "new description"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["description": "new description"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateId), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.description.rawValue,
                "oldValue": "description",
                "newValue": "new description",
            ])
        )
    }

    /// Test for idempotency
    /// The Update is already added, so skip the command
    func testApply_noOp_updateExists() throws {
        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "new description"
        )
        // update exists
        let context = TestFirestoreCommandContext(docs: [
            .update(command.updateId),
        ])
        try command.apply(inFirestore: context)

        // the update of tags is still perfomed as updating tags multiple times to same value is ok
        XCTAssertEqual(context.operations.count, 0)
    }

    /// Test for idempotency
    /// The name is the same as in Firestore... ignore
    func testApply_noOp_nameUnchanged() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1",
                timestamp: Timestamp(),
                statusId: nil,
                name: "name",
                collaborationDescription: "description",
                tagIds: []
            ),
        ])
        // same description
        let command = UpdateCollaborationDescriptionCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            description: "description"
        )
        try command.apply(inFirestore: context)

        // the update of tags is still perfomed as updating tags multiple times to same value is ok
        XCTAssertEqual(context.operations.count, 0)
    }
}
