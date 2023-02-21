import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationAssigneeCommand` in local Realm db
final class UpdateCollaborationAssigneeCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: nil
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noUser() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        // setup collaboration1
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )

        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.userNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        let user2 = Participant(id: "user2", firstName: "name", lastName: "", avatarUrl: nil, email: "")
        // setup collaboration1
        try realm.write {
            realm.add([collaboration1, user2])
        }
        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertNil(
            realm.object(ofType: Update.self, forPrimaryKey: command.updateId),
            "Update is not created when running command in Realm"
        )
        XCTAssertEqual(collaboration1.assignee, user2)
    }
}

/// Tests applying `UpdateCollaborationAssigneeCommand` to Firestore
final class UpdateCollaborationAssigneeCommandFirestoreTest: XCTestCase {
    func testApply_noCollaboration() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
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
        let context = TestFirestoreCommandContext(
            docs: [.participant("user2")],
            docsData: [
                .collaboration("collaboration1"): FirestoreCollaboration(
                    featureId: "feature1",
                    timestamp: Timestamp(),
                    statusId: nil,
                    name: "old name",
                    collaborationDescription: nil,
                    tagIds: []
                ),
            ]
        )

        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["assignee": "user2"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateId), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.assignee.rawValue,
                "newValue": "user2",
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
                assigneeId: "user2"
            ),
        ])

        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: nil
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["assignee": FieldValue.delete()])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateId), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.assignee.rawValue,
                "oldValue": "user2",
            ])
        )
    }

    /// Test for idempotency
    /// The Update is already added, so skip the command
    func testApply_noOp_updateExists() throws {
        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
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
    func testApply_noOp_assigneeUnchanged() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1",
                timestamp: Timestamp(),
                statusId: nil,
                name: "old name",
                collaborationDescription: nil,
                tagIds: [],
                assigneeId: "user2"
            ),
        ])
        // same assignee
        let command = UpdateCollaborationAssigneeCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            assigneeId: "user2"
        )
        try command.apply(inFirestore: context)

        // the update of tags is still perfomed as updating tags multiple times to same value is ok
        XCTAssertEqual(context.operations.count, 0)
    }
}
