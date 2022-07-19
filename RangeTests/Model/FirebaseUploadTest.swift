import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseUploadRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    func testAddUpload_wrongParentType() throws {
        let firebaseUpload = FirebaseUpload(
            parentId: "feature1",
            parentType: "Feature",
            authorId: "user1",
            timestamp: 1,
            name: "",
            uploadDescription: "",
            urlString: "https://range.io/image",
            correlationId: ""
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseUpload.upsert(realm, id: "upload1")
            ) { error in
                XCTAssertEqual(error.localizedDescription, "parentType not supported: Feature")
            }
        }
    }

    func testAddUploadToCollaboration_parentNotFound() throws {
        let firebaseUpload = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            name: "",
            uploadDescription: "",
            urlString: "https://range.io/image",
            correlationId: ""
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseUpload.upsert(realm, id: "upload1")
            ) { error in
                XCTAssertEqual(error.localizedDescription, "collaboration not found: collaboration1")
            }
        }
    }

    func testAddUploadToCollaboration_authorNotFound() throws {
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        try realm.write {
            realm.add(collaboration1)
        }

        let firebaseUpload = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            name: "",
            uploadDescription: "",
            urlString: "https://range.io/image",
            correlationId: ""
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseUpload.upsert(realm, id: "upload1")
            ) { error in
                XCTAssertEqual(error.localizedDescription, "author not found: user1")
            }
        }
    }

    func testAddUploadToCollaboration_malformedUrl() throws {
        let user1 = Participant(
            id: "user1",
            firstName: "First",
            lastName: "Last",
            avatarUrl: nil,
            email: "first@last.com"
        )
        let collaboration1 = Collaboration(id: "collaboration1", name: "Collaboration1", description: "")
        try realm.write {
            realm.add([user1, collaboration1])
        }

        let firebaseUpload = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            name: "",
            uploadDescription: "",
            urlString: "https://range.io/image 2",
            correlationId: ""
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseUpload.upsert(realm, id: "upload1")
            ) { error in
                XCTAssertEqual(error.localizedDescription, "malformed url: https://range.io/image 2")
            }
        }
    }

    func testAddUploadToCollaboration_successful() throws {
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
        XCTAssertEqual(collaboration1.uploads.count, 0)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 2. add upload to collaboration1
        var firebaseUpload1 = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            name: "upload 1",
            uploadDescription: "upload 1 description",
            urlString: "https://range.io/image",
            correlationId: ""
        )
        try realm.write {
            try firebaseUpload1.upsert(realm, id: "upload1")
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        guard let upload1 = realm.object(ofType: Upload.self, forPrimaryKey: "upload1") else {
            throw "upload1 not found"
        }
        XCTAssertEqual(upload1.timestamp, 1)
        XCTAssertEqual(upload1.name, "upload 1")
        XCTAssertEqual(upload1.uploadDescription, "upload 1 description")
        XCTAssertEqual(upload1.author, user1)
        XCTAssertEqual(upload1.url.absoluteString, "https://range.io/image")

        // 3. update upload1
        firebaseUpload1.name = "upload 1 ..."
        try realm.write {
            try firebaseUpload1.upsert(realm, id: "upload1")
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        XCTAssertEqual(upload1.name, "upload 1 ...")

        // 4. add another upload to collaboration1
        let firebaseUpload2 = FirebaseUpload(
            parentId: "collaboration1",
            parentType: "Collaboration",
            authorId: "user1",
            timestamp: 1,
            name: "upload 2",
            uploadDescription: "upload 2 description",
            urlString: "https://range.io/image",
            correlationId: ""
        )
        try realm.write {
            try firebaseUpload2.upsert(realm, id: "upload2")
        }
        XCTAssertEqual(collaboration1.uploads.count, 2)
        XCTAssertEqual(collaboration2.uploads.count, 0)

        // 5. remove upload2
        try realm.write {
            guard let upload2 = realm.object(ofType: Upload.self, forPrimaryKey: "upload2") else {
                throw "upload2 not found"
            }
            realm.delete(upload2)
        }
        XCTAssertEqual(collaboration1.uploads.count, 1)
        XCTAssertEqual(collaboration2.uploads.count, 0)
        XCTAssertEqual(collaboration1.uploads.first, upload1)
    }
}
