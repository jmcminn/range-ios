import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationStatusCommand` in local Realm db
final class UpdateCollaborationStatusCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_noStatus() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        // setup collaboration
        try realm.write {
            realm.add(collaboration1)
        }
        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.statusNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "old name", description: nil)
        let status1 = Status(id: "status1", name: "Status 1", hexColor: "#123456", isInitial: false, isCompleted: false)
        // setup collaboration and status
        try realm.write {
            realm.add([collaboration1, status1])
        }
        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertNil(
            realm.object(ofType: Update.self, forPrimaryKey: command.updateId),
            "Update is not created when running command in Realm"
        )
        XCTAssertEqual(collaboration1.status, status1)
    }
}

/// Tests applying `UpdateCollaborationStatusCommand` to Firestore
final class UpdateCollaborationStatusCommandFirestoreTest: XCTestCase {
    func testApply_noCollaboration() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("collaboration doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_noStatus() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(docs: [], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1",
                timestamp: Timestamp(),
                statusId: nil,
                name: "old name",
                collaborationDescription: nil,
                tagIds: []
            ),
        ])

        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("status doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(
            docs: [.statusName("status1")],
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

        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["statusName": "status1"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateId), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.statusName.rawValue,
                "newValue": "status1",
            ])
        )
    }

    /// Test for idempotency
    /// The Update is already added, so skip the command
    func testApply_noOp_updateExists() throws {
        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
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
    /// The status is the same as in Firestore... ignore
    func testApply_noOp_nameUnchanged() throws {
        // collaboration exists
        let context = TestFirestoreCommandContext(
            docs: [.statusName("status1")],
            docsData: [
                .collaboration("collaboration1"): FirestoreCollaboration(
                    featureId: "feature1",
                    timestamp: Timestamp(),
                    statusId: "status1",
                    name: "old name",
                    collaborationDescription: nil,
                    tagIds: []
                ),
            ]
        )
        // same status
        let command = UpdateCollaborationStatusCommand(
            authorId: "user1",
            collaborationId: "collaboration1",
            statusId: "status1"
        )
        try command.apply(inFirestore: context)

        // the update of tags is still perfomed as updating tags multiple times to same value is ok
        XCTAssertEqual(context.operations.count, 0)
    }
}
