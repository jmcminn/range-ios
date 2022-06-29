import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class FirebaseCollaborationRealmSyncTest: XCTestCase {
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(userId: "user1", projectId: UUID().uuidString, inMemory: true)
        realm = model.mainRealm
    }

    func testAddCollaborationToFeature_featureNotFound() throws {
        let firebaseCollaboration = FirebaseCollaboration(
            id: "collaboration1",
            featureId: "feature1",
            statusId: "status1",
            name: "Collaboration1",
            description: "",
            tagIds: []
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseCollaboration.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "feature not found: feature1")
            }
        }
    }

    func testAddCollaborationToFeature_statusNotFound() throws {
        let feature1 = Feature(id: "feature1", name: "Feature1")
        try realm.write {
            realm.add(feature1)
        }
        let firebaseCollaboration = FirebaseCollaboration(
            id: "collaboration1",
            featureId: "feature1",
            statusId: "status1",
            name: "Collaboration1",
            description: "",
            tagIds: []
        )
        try realm.write {
            XCTAssertThrowsError(
                try firebaseCollaboration.upsert(realm)
            ) { error in
                XCTAssertEqual(error.localizedDescription, "status not found: status1")
            }
        }
    }

    func testAddCollaborationToFeature_successful() throws {
        // 1. create 2 features and a status
        let status1 = Status(id: "status1", name: "Status", hexColor: "#000000", isInitial: true, isCompleted: false)
        let feature1 = Feature(id: "feature1", name: "Feature1")
        let feature2 = Feature(id: "feature2", name: "Feature2")
        let tag = Tag(id: "tag1", name: "tag 1", lastApplied: nil)
        try realm.write {
            realm.add([status1, feature1, feature2, tag])
        }
        XCTAssertEqual(feature1.collaborations.count, 0)
        XCTAssertEqual(feature2.collaborations.count, 0)

        // 2. add collaboration to feature1
        var firebaseCollaboration1 = FirebaseCollaboration(
            id: "collaboration1",
            featureId: "feature1",
            statusId: "status1",
            name: "Collaboration1",
            description: "",
            tagIds: ["tag1"]
        )
        try realm.write {
            try firebaseCollaboration1.upsert(realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        guard let collaboration1 = realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1") else {
            throw "collaboration1 not found"
        }
        XCTAssertEqual(collaboration1.name, "Collaboration1")
        XCTAssertEqual(collaboration1.status, status1)
        XCTAssertEqual(collaboration1.feature.first, feature1)
        XCTAssertEqual(collaboration1.tags.first, tag)
        XCTAssertEqual(tag.collaborations.first, collaboration1)

        // 3. update collaboration1
        firebaseCollaboration1.name = "Collaboration1..."
        try realm.write {
            try firebaseCollaboration1.upsert(realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        XCTAssertEqual(collaboration1.name, "Collaboration1...")

        // 4. add another collaboration to feature1
        let firebaseCollaboration2 = FirebaseCollaboration(
            id: "collaboration2",
            featureId: "feature1",
            statusId: "status1",
            name: "Collaboration2",
            description: "",
            tagIds: []
        )
        try realm.write {
            try firebaseCollaboration2.upsert(realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 2)
        XCTAssertEqual(feature2.collaborations.count, 0)

        // 5. remove collaboration2
        try realm.write {
            guard let collaboration2 = realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration2") else {
                throw "collaboration2 not found"
            }
            realm.delete(collaboration2)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        XCTAssertEqual(feature1.collaborations.first, collaboration1)
    }

    func testAddCollaborationToFeature_statusIsOptional() throws {
        let feature1 = Feature(id: "feature1", name: "Feature1")
        try realm.write {
            realm.add(feature1)
        }
        let firebaseCollaboration = FirebaseCollaboration(
            id: "collaboration1",
            featureId: "feature1",
            statusId: nil,
            name: "Collaboration1",
            description: "",
            tagIds: []
        )
        try realm.write {
            try firebaseCollaboration.upsert(realm)
        }

        let collaboration = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertNil(collaboration.status)
    }
}
