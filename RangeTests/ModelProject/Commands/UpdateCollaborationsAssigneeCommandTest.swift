import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationsAssigneeCommand` in local Realm db
final class UpdateCollaborationsAssigneeCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
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
        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
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
        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
            assigneeId: "user2"
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        XCTAssertNil(
            realm.object(ofType: Update.self, forPrimaryKey: command.updateIds[0]),
            "Update is not created when running command in Realm"
        )
        XCTAssertEqual(collaboration1.assignee, user2)
    }
}

/// Tests applying `UpdateCollaborationsAssigneeCommand` to Firestore
final class UpdateCollaborationsAssigneeCommandFirestoreTest: XCTestCase {
    func testApply_noCollaboration() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
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
                .collaboration("collaboration2"): FirestoreCollaboration(
                    featureId: "feature2",
                    timestamp: Timestamp(),
                    statusId: nil,
                    name: "name",
                    collaborationDescription: nil,
                    tagIds: []
                ),
            ]
        )

        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1", "collaboration2"],
            assigneeId: "user2"
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 4)
        AssertOperationsEqual(
            context.operations[0],
            .update(.collaboration("collaboration1"), ["assignee": "user2"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .set(.update(command.updateIds[0]), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.assignee.rawValue,
                "newValue": "user2",
            ])
        )
        AssertOperationsEqual(
            context.operations[2],
            .update(.collaboration("collaboration2"), ["assignee": "user2"])
        )
        AssertOperationsEqual(
            context.operations[3],
            .set(.update(command.updateIds[1]), [
                "parent": "collaboration2",
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

        let command = UpdateCollaborationsAssigneeCommand(
            authorId: "user1",
            collaborationIds: ["collaboration1"],
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
            .set(.update(command.updateIds[0]), [
                "parent": "collaboration1",
                "parentType": "Collaboration",
                "timestamp": FieldValue.serverTimestamp(),
                "user": "user1",
                "field": Update.Field.assignee.rawValue,
                "oldValue": "user2",
            ])
        )
    }
}
