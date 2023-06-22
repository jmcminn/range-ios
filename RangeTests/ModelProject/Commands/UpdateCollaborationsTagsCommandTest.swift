import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationsTagsCommand` in local Realm db
final class UpdateCollaborationsTagsCommandRealmTest: XCTestCase {
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
        let command = UpdateCollaborationsTagsCommand(collaborationIds: ["collaboration1"], tags: [])
        XCTAssertThrowsError(
            try command.apply(inRealm: realm)
        ) { error in
            XCTAssertEqual(error as! ModelError, ModelError.collaborationNotFound)
        }
    }

    func testApply_successful() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "", description: nil)
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        // setup collaboration1 with tag1 and tag2
        try realm.write {
            realm.add([collaboration1, tag1, tag2])
            collaboration1.tags.append(objectsIn: [tag1, tag2])
            tag1.collaborations.insert(collaboration1)
            tag2.collaborations.insert(collaboration1)
        }
        // update to tag2, tag3
        let command = UpdateCollaborationsTagsCommand(
            collaborationIds: ["collaboration1"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        let tag3 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag3"), "tag3 not found")
        XCTAssertEqual(tag3.name, "tag 3")
        XCTAssertTrue(tag1.collaborations.isEmpty)
        for tag in [tag2, tag3] {
            XCTAssertEqual(tag.collaborations.map(\.id), ["collaboration1"])
        }
        XCTAssertEqual(collaboration1.tags.map(\.id), ["tag2", "tag3"])
    }

    /// Test that new tags are added but not duplicated (not added if already there)
    func testApply_add() throws {
        let collaboration1 = Collaboration(id: "collaboration1", timestamp: Date(), name: "", description: nil)
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        // setup collab1 with tag1 and tag2
        try realm.write {
            realm.add([collaboration1, tag1, tag2])
            collaboration1.tags.append(objectsIn: [tag1, tag2])
            tag1.collaborations.insert(collaboration1)
            tag2.collaborations.insert(collaboration1)
        }
        // add tag2, tag3
        let command = UpdateCollaborationsTagsCommand(
            collaborationIds: ["collaboration1"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ],
            add: true // add instead of replace
        )
        try realm.write {
            try command.apply(inRealm: realm)
        }

        let tag3 = try XCTUnwrap(realm.object(ofType: Tag.self, forPrimaryKey: "tag3"), "tag3 not found")
        XCTAssertEqual(tag3.name, "tag 3")
        for tag in [tag1, tag2, tag3] {
            XCTAssertEqual(tag.collaborations.map(\.id), ["collaboration1"])
        }
        XCTAssertEqual(collaboration1.tags.map(\.id), ["tag1", "tag2", "tag3"])
    }
}

/// Tests applying `UpdateCollaborationsTagsCommand` to Firestore
final class UpdateCollaborationsTagsCommandFirestoreTest: XCTestCase {
    func testApply_noCollaboration() throws {
        // no data exists
        let context = TestFirestoreCommandContext(docs: [])

        let command = UpdateCollaborationsTagsCommand(collaborationIds: ["collaboration1"], tags: [])
        XCTAssertThrowsError(
            try command.apply(inFirestore: context)
        ) { error in
            guard case .obsolete("collaboration doesn't exist") = error as? FirestoreCommandError else {
                XCTFail("unexpected error: \(error)"); return
            }
        }
    }

    func testApply_successful() throws {
        // collab 1 and 2 exist, collaboration3 doesn't exist
        // there's also tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .tagName("tag1"), .tagName("tag2"),
        ], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1", timestamp: Timestamp(), statusId: "status1",
                name: "name", collaborationDescription: nil, tagIds: ["tag1", "tag2"]
            ),
            .collaboration("collaboration2"): FirestoreCollaboration(
                featureId: "feature2", timestamp: Timestamp(), statusId: "status1",
                name: "name", collaborationDescription: nil, tagIds: []
            ),
        ])

        let command = UpdateCollaborationsTagsCommand(
            collaborationIds: ["collaboration1", "collaboration2", "collaboration3"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ]
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 3)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .update(.collaboration("collaboration1"), ["tags": ["tag2", "tag3"]])
        )
        AssertOperationsEqual(
            context.operations[2],
            .update(.collaboration("collaboration2"), ["tags": ["tag2", "tag3"]])
        )
    }

    /// Test that new tags are added but not duplicated (not added if already there)
    func testApply_add() throws {
        // collaboration 1 with tag1 and tag2 already in firestore
        let context = TestFirestoreCommandContext(docs: [
            .tagName("tag1"), .tagName("tag2"),
        ], docsData: [
            .collaboration("collaboration1"): FirestoreCollaboration(
                featureId: "feature1", timestamp: Timestamp(), statusId: "status1",
                name: "name", collaborationDescription: nil, tagIds: ["tag1", "tag2"]
            ),
        ])

        let command = UpdateCollaborationsTagsCommand(
            collaborationIds: ["collaboration1"],
            tags: [
                .init(id: "tag2", name: "tag 2"),
                .init(id: "tag3", name: "tag 3"),
            ],
            add: true
        )
        try command.apply(inFirestore: context)

        XCTAssertEqual(context.operations.count, 2)
        AssertOperationsEqual(
            context.operations[0],
            .set(.tagName("tag3"), ["name": "tag 3"])
        )
        AssertOperationsEqual(
            context.operations[1],
            .update(.collaboration("collaboration1"), ["tags": ["tag1", "tag2", "tag3"]])
        )
    }
}
