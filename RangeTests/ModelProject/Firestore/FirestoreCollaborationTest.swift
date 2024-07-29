import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

class FirestoreCollaborationTest: ProjectModelTestCase {
    // MARK: - upsert tests

    // Adds a feature and status placeholders if not found
    func testUpsert_createPlaceholders() throws {
        let firestoreCollaboration = FirestoreCollaboration(
            createdById: "user1",
            createdAt: Date(), 
            descriptionString: "",
            geometryId: "geometry1",
            lastUpdatedAt: Date(),
            name: "Collaboration1",
            statusId: "status1",
            tagIds: []
        )
        try realm.write {
            try firestoreCollaboration.upsert(withId: "collaboration1", inRealm: realm)
        }
        let geometry = try XCTUnwrap(
            realm.object(ofType: Geometry.self, forPrimaryKey: "geometry1"),
            "geometry1 not found"
        )
        XCTAssertTrue(geometry.placeholder)
        let status = try XCTUnwrap(
            realm.object(ofType: Status.self, forPrimaryKey: "status1"),
            "status1 not found"
        )
        XCTAssertTrue(status.placeholder)
    }

    func testUpsert_successful() throws {
        // 1. create 2 features and a status
        let status1 = Status(id: "status1", name: "Status", hexColor: "#000000", isInitial: true, isCompleted: false)
        let geometry1 = Geometry(placeholderId: "geometry1")
        let geometry2 = Geometry(placeholderId: "geometry2")
        let tag = Tag(id: "tag1", name: "tag 1")
        try realm.write {
            realm.add([status1, geometry1, geometry2, tag])
        }
        XCTAssertEqual(geometry1.collaborations.count, 0)
        XCTAssertEqual(geometry2.collaborations.count, 0)

        // 2. add collaboration to feature1
        var firestoreCollaboration1 = FirestoreCollaboration(
            createdById: "user1",
            createdAt: Date(timeIntervalSince1970: 1), 
            descriptionString: "",
            geometryId: "geometry1",
            lastUpdatedAt: Date(),
            name: "Collaboration1",
            statusId: "status1",
            tagIds: ["tag1"]
        )
        try realm.write {
            try firestoreCollaboration1.upsert(withId: "collaboration1", inRealm: realm)
        }
        XCTAssertEqual(geometry1.collaborations.count, 1)
        XCTAssertEqual(geometry2.collaborations.count, 0)
        let collaboration1 = try XCTUnwrap(
            realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"),
            "collaboration1 not found"
        )
        XCTAssertEqual(collaboration1.createdAt.timeIntervalSince1970, 1)
        XCTAssertEqual(collaboration1.name, "Collaboration1")
        XCTAssertEqual(collaboration1.status, status1)
        XCTAssertEqual(collaboration1.geometry.first, geometry1)
        XCTAssertEqual(collaboration1.tags.first, tag)
        XCTAssertEqual(tag.collaborations.first, collaboration1)

        // 3. update collaboration1
        firestoreCollaboration1.name = "Collaboration1..."
        try realm.write {
            try firestoreCollaboration1.upsert(withId: "collaboration1", inRealm: realm)
        }
        XCTAssertEqual(geometry1.collaborations.count, 1)
        XCTAssertEqual(geometry2.collaborations.count, 0)
        XCTAssertEqual(collaboration1.name, "Collaboration1...")

        // 4. add another collaboration to feature1
        let firestoreCollaboration2 = FirestoreCollaboration(
            createdById: "user1",
            createdAt: Date(timeIntervalSince1970: 1), 
            descriptionString: "",
            geometryId: "geometry1",
            lastUpdatedAt: Date(),
            name: "Collaboration2",
            statusId: "status1",
            tagIds: []
        )
        try realm.write {
            try firestoreCollaboration2.upsert(withId: "collaboration2", inRealm: realm)
        }
        XCTAssertEqual(geometry1.collaborations.count, 2)
        XCTAssertEqual(geometry2.collaborations.count, 0)

        // 5. remove collaboration2
        try realm.write {
            let collaboration2 = try XCTUnwrap(
                realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration2"),
                "collaboration2 not found"
            )
            realm.delete(collaboration2)
        }
        XCTAssertEqual(geometry1.collaborations.count, 1)
        XCTAssertEqual(geometry2.collaborations.count, 0)
        XCTAssertEqual(geometry1.collaborations.first, collaboration1)
    }

    func testUpsert_statusIsOptional() throws {
        let geometry1 = Geometry(placeholderId: "geometry1")
        try realm.write {
            realm.add(geometry1)
        }
        let firestoreCollaboration = FirestoreCollaboration(
            createdById: "user1",
            createdAt: Date(timeIntervalSince1970: 1), 
            descriptionString: "",
            geometryId: "geometry1",
            lastUpdatedAt: Date(),
            name: "Collaboration1",
            statusId: nil,
            tagIds: []
        )
        try realm.write {
            try firestoreCollaboration.upsert(withId: "collaboration1", inRealm: realm)
        }

        let collaboration = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertNil(collaboration.status)
    }

    func testUpsert_updateTags() throws {
        let geometry1 = Geometry(placeholderId: "geometry1")
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        let tag3 = Tag(id: "tag3", name: "tag 3")
        try realm.write {
            realm.add([geometry1, tag1, tag2, tag3])
        }

        // given a collaboration with tag1 and tag2 and a duplicate of tag1
        var firestoreCollaboration = FirestoreCollaboration(
            createdById: "user1",
            createdAt: Date(), 
            descriptionString: "",
            geometryId: "geometry1",
            lastUpdatedAt: Date(),
            name: "Collaboration1",
            statusId: nil,
            tagIds: ["tag1", "tag2", "tag1"]
        )
        try realm.write {
            try firestoreCollaboration.upsert(withId: "collaboration1", inRealm: realm)
        }
        // tags have the collaboration attached
        let collaboration = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertEqual(collaboration.tags.map(\.id), ["tag1", "tag2"])
        XCTAssertEqual(tag1.collaborations.count, 1)
        XCTAssertEqual(tag2.collaborations.count, 1)
        XCTAssertEqual(tag3.collaborations.count, 0)

        // when switching collaboration tags
        firestoreCollaboration.tagIds = ["tag2", "tag3"]
        try realm.write {
            try firestoreCollaboration.upsert(withId: "collaboration1", inRealm: realm)
        }

        // then tag <-> collaboration links are updated
        XCTAssertEqual(collaboration.tags.map(\.id), ["tag2", "tag3"])
        XCTAssertEqual(tag1.collaborations.count, 0)
        XCTAssertEqual(tag2.collaborations.count, 1)
        XCTAssertEqual(tag3.collaborations.count, 1)
    }
}
