@testable import Range
import RealmSwift
import XCTest

class TagsViewModelTest: XCTestCase {
    var pendingUploadsModel: PendingUploadsModel!
    var model: ProjectModel!
    var realm: Realm!

    override func setUpWithError() throws {
        pendingUploadsModel = TestPendingUploadsModel()
        // create a different Realm in each test by using a new UUID
        model = try ProjectModel(
            userId: "user1",
            projectId: UUID().uuidString,
            imageCaches: ImageCaches(projectId: ""),
            pendingUploadsModel: pendingUploadsModel,
            inMemory: true
        )
        realm = model.mainRealm
        // add some tags
        try realm.write {
            realm.add([
                Tag(id: "t1", name: "A", lastApplied: nil),
                Tag(id: "t2", name: "a", lastApplied: 6),
                Tag(id: "t3", name: "3", lastApplied: nil),
                Tag(id: "t4", name: "4", lastApplied: 5),
                Tag(id: "t5", name: "5", lastApplied: 9),
                Tag(id: "t6", name: "6", lastApplied: nil),
                Tag(id: "t7", name: "x", lastApplied: nil),
            ])
        }
    }

    func testInit_sortsAllTags() {
        let viewModel = TagsViewModel(model: model)

        XCTAssertEqual(
            viewModel.allTags.map(\.name),
            ["3", "4", "5", "6", "a", "A", "x"]
        )
    }

    func testInit_lastAppliedTags() {
        let viewModel = TagsViewModel(model: model)

        XCTAssertEqual(
            viewModel.lastAppliedTags.map(\.id),
            ["t5", "t2", "t4"]
        )
    }

    // limit number of last applied tags to 10
    func testInit_lastAppliedTagsLimit() throws {
        try realm.write {
            realm.add([
                Tag(id: "t11", name: "11", lastApplied: 11),
                Tag(id: "t12", name: "12", lastApplied: 12),
                Tag(id: "t13", name: "13", lastApplied: 13),
                Tag(id: "t14", name: "14", lastApplied: 14),
                Tag(id: "t15", name: "15", lastApplied: 15),
                Tag(id: "t16", name: "16", lastApplied: 16),
                Tag(id: "t17", name: "17", lastApplied: 17),
                Tag(id: "t18", name: "18", lastApplied: 18),
                Tag(id: "t19", name: "19", lastApplied: 19),
            ])
        }
        let viewModel = TagsViewModel(model: model)

        XCTAssertEqual(
            viewModel.lastAppliedTags.map(\.id),
            ["t19", "t18", "t17", "t16", "t15", "t14", "t13", "t12", "t11", "t5"]
        )
    }

    func testInit_initialSelectedTags() throws {
        let viewModel = TagsViewModel(model: model, initialSelectedTags: [
            TagViewModel(id: "t1", name: "A", lastApplied: nil, usageCount: 0), // existing tag
            TagViewModel(id: "t100", name: "Abc", lastApplied: nil, usageCount: 0, newTag: true), // new tag
        ])
        XCTAssertEqual(viewModel.allTags.map(\.name),
                       ["3", "4", "5", "6", "a", "A", "Abc", "x"])
        XCTAssertEqual(viewModel.selectedTags.map(\.id), ["t1", "t100"])
    }

    func testFilter_caseInsensitive() {
        let viewModel = TagsViewModel(model: model)
        viewModel.filter(by: "a")
        XCTAssertEqual(viewModel.filteredTags.map(\.name), ["a", "A"])
    }

    func testFilter_diacriticInsensitive() throws {
        try realm.write {
            realm.add([
                Tag(id: "t11", name: "ąx", lastApplied: 11),
            ])
        }
        let viewModel = TagsViewModel(model: model)
        viewModel.filter(by: "ą")
        XCTAssertEqual(viewModel.filteredTags.map(\.name), ["a", "A", "ąx"])
    }

    func testFilter_multitermFilter() throws {
        try realm.write {
            realm.add([
                Tag(id: "t11", name: "another tag", lastApplied: 11),
                Tag(id: "t12", name: "tag other than a", lastApplied: 11),
            ])
        }
        let viewModel = TagsViewModel(model: model)
        viewModel.filter(by: "her tag")
        XCTAssertEqual(viewModel.filteredTags.map(\.name), ["another tag", "tag other than a"])
    }

    func testAddTag_keepsOrder() {
        let viewModel = TagsViewModel(model: model)
        viewModel.add(tag: TagViewModel(newTagWithName: "b"))
        XCTAssertEqual(viewModel.allTags.map(\.name), ["3", "4", "5", "6", "a", "A", "b", "x"])

        viewModel.add(tag: TagViewModel(newTagWithName: "1"))
        XCTAssertEqual(viewModel.allTags.map(\.name), ["1", "3", "4", "5", "6", "a", "A", "b", "x"])

        viewModel.add(tag: TagViewModel(newTagWithName: "Z"))
        XCTAssertEqual(viewModel.allTags.map(\.name), ["1", "3", "4", "5", "6", "a", "A", "b", "x", "Z"])
    }

    func testSetTagSelected() throws {
        let viewModel = TagsViewModel(model: model)

        viewModel.set(tagWithId: "t2", selected: true)

        viewModel.filter(by: "a")
        // should show as selected in allTags and filteredTags and lastAppliedTags
        XCTAssertTrue(try XCTUnwrap(viewModel.allTags.first { $0.id == "t2" }).selected)
        XCTAssertTrue(try XCTUnwrap(viewModel.lastAppliedTags.first { $0.id == "t2" }).selected)
        XCTAssertTrue(try XCTUnwrap(viewModel.filteredTags.first { $0.id == "t2" }).selected)
        XCTAssertEqual(viewModel.selectedTags.map(\.id), ["t2"])
    }

    func testMostUsedTags() throws {
        let upload1 = Upload(
            id: "upload1",
            timestamp: 0,
            url: URL(fileURLWithPath: "//test"),
            name: "",
            description: "",
            correlationId: "upload1",
            fileType: .image
        )
        let upload2 = Upload(
            id: "upload2",
            timestamp: 0,
            url: URL(fileURLWithPath: "//test"),
            name: "",
            description: "",
            correlationId: "upload1",
            fileType: .image
        )
        try realm.write {
            realm.add([upload1, upload2])
            realm.object(ofType: Tag.self, forPrimaryKey: "t1")!.uploads.insert(upload1)
            realm.object(ofType: Tag.self, forPrimaryKey: "t2")!.uploads.insert(upload1)
            realm.object(ofType: Tag.self, forPrimaryKey: "t3")!.uploads.insert(upload1)
            realm.object(ofType: Tag.self, forPrimaryKey: "t3")!.uploads.insert(upload2)
        }

        let viewModel = TagsViewModel(model: model)
        XCTAssertEqual(viewModel.mostUsedTags.map(\.id), ["t3", "t1", "t2"])
        XCTAssertEqual(viewModel.mostUsedTags.map(\.usageCount), [2, 1, 1])
    }
}
