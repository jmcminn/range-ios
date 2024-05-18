import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

/// Tests applying `UpdateCollaborationTagsCommand` in local Realm db
final class UpdateCollaborationTagsCommandRealmTest: ProjectModelTestCase {
    func testApply_noCollaboration() throws {
        let command = UpdateCollaborationTagsCommand(collaborationId: "collaboration1", tags: [])
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
        let command = UpdateCollaborationTagsCommand(
            collaborationId: "collaboration1",
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
        let command = UpdateCollaborationTagsCommand(
            collaborationId: "collaboration1",
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

/// Tests getting the parameters for the Firebase function call
final class UpdateCollaborationTagsCommandFirebaseFunctionTest: XCTestCase {
    func test_functionName() throws {
        let command = UpdateCollaborationTagsCommand(
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1")]
        )
        XCTAssertEqual(command.functionName, "updateCollaboration")
    }

    func test_functionData() throws {
        let command = UpdateCollaborationTagsCommand(
            collaborationId: "collaboration1",
            tags: [
                .init(id: "tag1", name: "tag 1"),
                .init(id: "tag2", name: "tag 2")
            ]
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "tags": [
                ["id": "tag1", "name": "tag 1"],
                ["id": "tag2", "name": "tag 2"]
            ],
            "addTags": false
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
    
    func test_functionData_add() throws {
        let command = UpdateCollaborationTagsCommand(
            collaborationId: "collaboration1",
            tags: [.init(id: "tag1", name: "tag 1")],
            add: true
        )
        let data = command.functionData("project1") as? [String: Any?]
        let expected: [String: Any?] = [
            "projectId": "project1",
            "collaborationId": "collaboration1",
            "tags": [["id": "tag1", "name": "tag 1"]],
            "addTags": true
        ]
        // There's no easy way to compare heterogenous dictionaries in swift, cast to NSDictionary
        // so the compiler stops saying that the types are not comparable, etc.
        XCTAssertEqual(try XCTUnwrap(data) as NSDictionary, expected as NSDictionary)
    }
}
