import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseCommentRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    func testAddComment_wrongParentType() throws {
        let firebaseComment = FirebaseComment(
            id: "comment1",
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1"
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseComment.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "parentType not supported for comment: Feature")
            }
        }
    }

    func testAddCommentToCollaboration_parentNotFound() throws {
        let firebaseComment = FirebaseComment(
            id: "comment1",
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1"
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseComment.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "collaboration not found: collaboration1")
            }
        }
    }

    func testAddCommentToCollaboration_authorNotFound() throws {
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        try realm.write {
            realm.add(collaboration1)
        }

        let firebaseComment = FirebaseComment(
            id: "comment1",
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1"
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseComment.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "author not found: user1")
            }
        }
    }

    func testAddCommentToCollaboration_successful() throws {
        // 1. create 2 collaborations and a user
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        let collaboration2 = Collaboration(id: "collaboration2", name: "Collaboration2", description: "")
        try realm.write {
            realm.add([user1, collaboration1, collaboration2])
        }
        XCTAssertEqual(collaboration1.comments.count, 0)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 2. add comment to collaboration1
        var firebaseComment1 = FirebaseComment(
            id: "comment1",
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            text: "comment 1"
        )
        try realm.write {
            try firebaseComment1.upsert(realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        guard let comment1 = realm.object(ofType: Comment.self, forPrimaryKey: "comment1") else {
            throw "comment1 not found"
        }
        XCTAssertEqual(comment1.text, "comment 1")
        XCTAssertEqual(comment1.author, user1)
        XCTAssertEqual(comment1.timestamp, 1)

        // 3. update comment1
        firebaseComment1.text = "comment 1 ..."
        try realm.write {
            try firebaseComment1.upsert(realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(comment1.text, "comment 1 ...")

        // 4. add another comment to collaboration1
        let firebaseComment2 = FirebaseComment(
            id: "comment2",
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 2,
            text: "comment 2"
        )
        try realm.write {
            try firebaseComment2.upsert(realm)
        }
        XCTAssertEqual(collaboration1.comments.count, 2)
        XCTAssertEqual(collaboration2.comments.count, 0)

        // 5. remove comment2
        try realm.write {
            guard let comment2 = realm.object(ofType: Comment.self, forPrimaryKey: "comment2") else {
                throw "comment2 not found"
            }
            realm.delete(comment2)
        }
        XCTAssertEqual(collaboration1.comments.count, 1)
        XCTAssertEqual(collaboration2.comments.count, 0)
        XCTAssertEqual(collaboration1.comments.first, comment1)
    }
}
