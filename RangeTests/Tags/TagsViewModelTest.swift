@testable import Range
import RealmSwift
import XCTest

class TagsViewModelTest: XCTestCase {
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
            imageCaches: ImageCaches(),
            pendingUploadsModel: pendingUploadsModel,
            pendingActionsModel: pendingActionsModel,
            inMemory: true
        )
        realm = model.mainRealm
        // add some tags
        try realm.write {
            realm.add([
                Tag(id: "t1", name: "A"),
                Tag(id: "t2", name: "a"),
                Tag(id: "t3", name: "3"),
                Tag(id: "t4", name: "4"),
                Tag(id: "t5", name: "5"),
                Tag(id: "t6", name: "6"),
                Tag(id: "t7", name: "x"),
            ])
        }

        UserDefaults.addRecentTagIds(["t4", "t2", "t5"], forProjectId: model.projectId)
    }

    func testInit_sortsAllTags() {
        let viewModel = TagsViewModel(model: model)

        XCTAssertEqual(
            viewModel.allTags.map(\.name),
            ["3", "4", "5", "6", "a", "A", "x"]
        )
    }

    func testInit_recentTags() {
        let viewModel = TagsViewModel(model: model)

        XCTAssertEqual(
            viewModel.recentTags.map(\.id),
            ["t5", "t2", "t4"]
        )
    }

    func testInit_initialSelectedTags() throws {
        let viewModel = TagsViewModel(model: model, initialSelectedTags: [
            TagViewModel(id: "t1", name: "A", usageCount: 0), // existing tag
            TagViewModel(id: "t100", name: "Abc", usageCount: 0, newTag: true), // new tag
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
                Tag(id: "t11", name: "ąx"),
            ])
        }
        let viewModel = TagsViewModel(model: model)
        viewModel.filter(by: "ą")
        XCTAssertEqual(viewModel.filteredTags.map(\.name), ["a", "A", "ąx"])
    }

    func testFilter_multitermFilter() throws {
        try realm.write {
            realm.add([
                Tag(id: "t11", name: "another tag"),
                Tag(id: "t12", name: "tag other than a"),
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
        // should show as selected in allTags and filteredTags and recentTags
        XCTAssertTrue(try XCTUnwrap(viewModel.allTags.first { $0.id == "t2" }).selected)
        XCTAssertTrue(try XCTUnwrap(viewModel.recentTags.first { $0.id == "t2" }).selected)
        XCTAssertTrue(try XCTUnwrap(viewModel.filteredTags.first { $0.id == "t2" }).selected)
        XCTAssertEqual(viewModel.selectedTags.map(\.id), ["t2"])
    }

    func testMostUsedTags() throws {
        let upload1 = Upload(
            id: "upload1",
            timestamp: Date.now,
            name: "",
            description: "",
            correlationId: "upload1",
            fileType: .jpeg,
            imageHeightToWidth: 0.75,
            fileSize: 1024
        )
        let upload2 = Upload(
            id: "upload2",
            timestamp: Date.now,
            name: "",
            description: "",
            correlationId: "upload1",
            fileType: .jpeg,
            imageHeightToWidth: 1.0,
            fileSize: 1024
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
