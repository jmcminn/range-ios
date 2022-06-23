import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseTagNameRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    // Tests how upserting/removing the FirebaseTagName is reflected in the Realm db
    func testTagSync() throws {
        // 1. initial status
        var firebaseTagName = FirebaseTagName(
            id: "tag1",
            name: "kitchen"
        )

        // when creating initial tag
        try realm.write {
            try firebaseTagName.upsert(realm)
        }

        // it gets stored with all properties
        guard let tag = realm.object(ofType: Tag.self, forPrimaryKey: "tag1") else {
            throw "tag1 not found"
        }
        XCTAssertEqual(tag.name, "kitchen")

        // 2. change the tag
        firebaseTagName.name = "kitchen..."
        // update object
        try realm.write {
            try firebaseTagName.upsert(realm)
        }
        // check status after update
        XCTAssertEqual(tag.name, "kitchen...")
    }

    func testTagSync_dontOverwriteLastApplied() throws {
        // 1. initial tag
        var firebaseTagName = FirebaseTagName(
            id: "tag1",
            name: "kitchen"
        )

        // when creating initial tag
        try realm.write {
            try firebaseTagName.upsert(realm)
        }

        // it gets stored with all properties
        guard let tag = realm.object(ofType: Tag.self, forPrimaryKey: "tag1") else {
            throw "tag1 not found"
        }
        XCTAssertEqual(tag.name, "kitchen")

        // 2. set lastApplied
        try realm.write {
            tag.lastApplied = 1000
        }

        // 3. update the firebase tag
        firebaseTagName.name = "kitchen..."
        // update object
        try realm.write {
            try firebaseTagName.upsert(realm)
        }
        // check status after update
        XCTAssertEqual(tag.name, "kitchen...")
        XCTAssertEqual(tag.lastApplied, 1000)
    }
}
