import FirebaseFirestore
@testable import Range
import RealmSwift
import XCTest

class FirestoreCommentRealmSyncTest: ProjectModelTestCase {
    // MARK: - upsert tests

    // Tests if firebase object fills in the defaults for optionals
    func testUpsert_defaultValues() throws {
        let firestoreComment = FirestoreComment(
            createdById: "user1",
            createdAt: Date(), lastUpdatedAt: Date(),
            parentId: "collaboration1",
            parentType: "Collaboration",
            text: "comment 1"
        )
        try realm.write {
            try firestoreComment.upsert(withId: "comment1", inRealm: realm)
        }
        let comment = try XCTUnwrap(
            realm.object(ofType: Comment.self, forPrimaryKey: "comment1"),
            "comment1 not found"
        )
        XCTAssertEqual(comment.textIsEdited, false)
        XCTAssertEqual(comment.isNote, false)
        XCTAssertEqual(comment.completedBy, nil)
        XCTAssertEqual(comment.completedTimestamp, nil)
    }

    func testUpsert_wrongParentType() throws {
        let firestoreComment = FirestoreComment(
            createdById: "user1",
            createdAt: Date(), lastUpdatedAt: Date(),
            parentId: "feature1",
            parentType: "Feature",
            text: "comment 1"
        )
        XCTAssertThrowsError(
            try realm.write {
                try firestoreComment.upsert(withId: "comment1", inRealm: realm)
            }
        ) { error in
            XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
        }
    }

    // Adds a parent and author placeholders if not found
    func testUpsert_createPlaceholders() throws {
        let firestoreComment = FirestoreComment(
            createdById: "user2",
            createdAt: Date(), lastUpdatedAt: Date(),
            parentId: "collaboration1",
            parentType: "Collaboration",
            text: "comment 1"
        )
        try realm.write {
            try firestoreComment.upsert(withId: "comment1", inRealm: realm)
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
        let user1 = Participant(placeholderId: "user1")
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(), lastUpdatedAt: Date(),
            name: "Collaboration1",
            description: ""
        )
        let collaboration2 = Collaboration(
            id: "collaboration2",
            createdAt: Date(), lastUpdatedAt: Date(),
            name: "Collaboration2",
            description: ""
        )
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.comments.count, 0)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 2. add comment to collaboration1
        var firestoreComment1 = FirestoreComment(
            createdById: "user1",
            createdAt: Date(timeIntervalSince1970: 1), lastUpdatedAt: Date(),
            parentId: "collaboration1",
            parentType: "Collaboration",
            text: "comment 1"
        )
        try realm.write {
            try firestoreComment1.upsert(withId: "comment1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        let comment1 = try XCTUnwrap(
            realm.object(ofType: Comment.self, forPrimaryKey: "comment1"),
            "comment1 not found"
        )
        XCTAssertEqual(comment1.text, "comment 1")
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.createdAt.timeIntervalSince1970, 1)

        // 3. update comment1
        firestoreComment1.text = "comment 1 ..."
        try realm.write {
            try firestoreComment1.upsert(withId: "comment1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(comment1.text, "comment 1 ...")

        // 4. add another comment to collaboration1
        let firestoreComment2 = FirestoreComment(
            createdById: "user1",
            createdAt: Date(), lastUpdatedAt: Date(),
            parentId: "collaboration1",
            parentType: "Collaboration",
            text: "comment 2"
        )
        try realm.write {
            try firestoreComment2.upsert(withId: "comment2", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 2)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 5. remove comment2
        try realm.write {
            let comment2 = try XCTUnwrap(
                realm.object(ofType: Comment.self, forPrimaryKey: "comment2"),
                "comment2 not found"
            )
            realm.delete(comment2)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(collaboration1.comments.first, comment1)
    }

    func testUpsert_completedNote() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(placeholderId: "user1")
        let user2 = Participant(placeholderId: "user2")
        let collaboration1 = Collaboration(
            id: "collaboration1",
            createdAt: Date(), lastUpdatedAt: Date(),
            name: "Collaboration1",
            description: ""
        )
        try realm.write {
            realm.add([user1, user2, collaboration1])
        }
        XCTAssertEqual(collaboration1.comments.count, 0)

        // 2. add note to collaboration1
        let firestoreComment1 = FirestoreComment(
            completedById: "user2",
            completedTimestamp: Date(timeIntervalSince1970: 2),
            createdById: "user1",
            createdAt: Date(timeIntervalSince1970: 1), 
            isNote: true,
            lastUpdatedAt: Date(),
            parentId: "collaboration1",
            parentType: "Collaboration",
            text: "comment 1",
            textIsEdited: true
        )
        try realm.write {
            try firestoreComment1.upsert(withId: "comment1", inRealm: realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        let comment1 = try XCTUnwrap(
            realm.object(ofType: Comment.self, forPrimaryKey: "comment1"),
            "comment1 not found"
        )
        XCTAssertEqual(comment1.text, "comment 1")
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.createdAt.timeIntervalSince1970, 1)
        XCTAssertTrue(comment1.isNote)
        XCTAssertTrue(comment1.textIsEdited)
        XCTAssertEqual(comment1.completedBy, user2)
        XCTAssertEqual(comment1.completedTimestamp?.timeIntervalSince1970, 2)
    }
}
