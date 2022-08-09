import CoreLocation
@testable import Range
import RealmSwift
import Turf
import XCTest

class AddCollaborationCommandTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
    }

    // Adds a feature and status placeholders if not found
    func testApplyInRealm_createPlaceholders() throws {
        let cmd = AddCollaborationCommand(
            collaborationId: "collaboration1",
            featureId: "feature1",
            name: "",
            collaborationDescription: "",
            statusId: "status1",
            tagIds: []
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        let feature = try XCTUnwrap(
            realm.object(ofType: Feature.self, forPrimaryKey: "feature1"),
            "feature1 not found"
        )
        XCTAssertTrue(feature.placeholder)
        let status = try XCTUnwrap(
            realm.object(ofType: Status.self, forPrimaryKey: "status1"),
            "status1 not found"
        )
        XCTAssertTrue(status.placeholder)
    }

    func testApplyInRealm_successful() throws {
        // 1. create 2 features and a status
        let status1 = Status(id: "status1", name: "Status", hexColor: "#000000", isInitial: true, isCompleted: false)
        let feature1 = Feature(id: "feature1", name: "Feature1", description: "")
        let feature2 = Feature(id: "feature2", name: "Feature2", description: "")
        let tag = Tag(id: "tag1", name: "tag 1", lastApplied: nil)
        try realm.write {
            realm.add([status1, feature1, feature2, tag])
        }
        XCTAssertEqual(feature1.collaborations.count, 0)
        XCTAssertEqual(feature2.collaborations.count, 0)

        // 2. add collaboration to feature1
        var cmd1 = AddCollaborationCommand(
            collaborationId: "collaboration1",
            featureId: "feature1",
            name: "Collaboration1",
            collaborationDescription: "",
            statusId: "status1",
            tagIds: ["tag1"]
        )
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        let collaboration1 = try XCTUnwrap(
            realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"),
            "collaboration1 not found"
        )
        XCTAssertEqual(collaboration1.name, "Collaboration1")
        XCTAssertEqual(collaboration1.status, status1)
        XCTAssertEqual(collaboration1.feature.first, feature1)
        XCTAssertEqual(collaboration1.tags.first, tag)
        XCTAssertEqual(tag.collaborations.first, collaboration1)

        // 3. update collaboration1
        cmd1.name = "Collaboration1..."
        try realm.write {
            try cmd1.apply(inRealm: realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        XCTAssertEqual(collaboration1.name, "Collaboration1...")

        // 4. add another collaboration to feature1
        let cmd2 = AddCollaborationCommand(
            collaborationId: "collaboration2",
            featureId: "feature1",
            name: "Collaboration2",
            collaborationDescription: "",
            statusId: "status1",
            tagIds: []
        )
        try realm.write {
            try cmd2.apply(inRealm: realm)
        }
        XCTAssertEqual(feature1.collaborations.count, 2)
        XCTAssertEqual(feature2.collaborations.count, 0)

        // 5. remove collaboration2
        try realm.write {
            let collaboration2 = try XCTUnwrap(
                realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration2"),
                "collaboration2 not found"
            )
            realm.delete(collaboration2)
        }
        XCTAssertEqual(feature1.collaborations.count, 1)
        XCTAssertEqual(feature2.collaborations.count, 0)
        XCTAssertEqual(feature1.collaborations.first, collaboration1)
    }

    func testApplyInRealm_statusIsOptional() throws {
        let feature1 = Feature(id: "feature1", name: "Feature1", description: "")
        try realm.write {
            realm.add(feature1)
        }
        let cmd = AddCollaborationCommand(
            collaborationId: "collaboration1",
            featureId: "feature1",
            name: "",
            collaborationDescription: "",
            statusId: nil,
            tagIds: []
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }

        let collaboration = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertNil(collaboration.status)
    }

    func testApplyInRealm_updateTags() throws {
        let feature1 = Feature(id: "feature1", name: "Feature1", description: "")
        let tag1 = Tag(id: "tag1", name: "tag 1")
        let tag2 = Tag(id: "tag2", name: "tag 2")
        let tag3 = Tag(id: "tag3", name: "tag 3")
        try realm.write {
            realm.add([feature1, tag1, tag2, tag3])
        }

        // given a collaboration with tag1 and tag2
        var cmd = AddCollaborationCommand(
            collaborationId: "collaboration1",
            featureId: "feature1",
            name: "",
            collaborationDescription: "",
            statusId: nil,
            tagIds: ["tag1", "tag2"]
        )
        try realm.write {
            try cmd.apply(inRealm: realm)
        }
        // tags have the collaboration attached
        let collaboration = try XCTUnwrap(realm.object(ofType: Collaboration.self, forPrimaryKey: "collaboration1"))
        XCTAssertEqual(collaboration.tags.map(\.id), ["tag1", "tag2"])
        XCTAssertEqual(tag1.collaborations.count, 1)
        XCTAssertEqual(tag2.collaborations.count, 1)
        XCTAssertEqual(tag3.collaborations.count, 0)

        // when switching collaboration tags
        cmd.tagIds = ["tag2", "tag3"]
        try realm.write {
            try cmd.apply(inRealm: realm)
        }

        // then tag <-> collaboration links are updated
        XCTAssertEqual(collaboration.tags.map(\.id), ["tag2", "tag3"])
        XCTAssertEqual(tag1.collaborations.count, 0)
        XCTAssertEqual(tag2.collaborations.count, 1)
        XCTAssertEqual(tag3.collaborations.count, 1)
    }
}
