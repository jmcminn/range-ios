@testable import Range
import XCTest

final class CanvasFiltersTest: XCTestCase {
    func testEmptyTagFilters() {
        let filters = CanvasFilters()
        filters.tagsFilter = []

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertTrue(filters.match(collaboration), "no tags in filter matches any collaboration")
    }

    func testTagFiltersMatchCollaboration() {
        let filters = CanvasFilters()
        filters.tagsFilter = ["tag1", "tag2"]

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertFalse(filters.match(collaboration), "collaboration with no tags")

        collaboration.tags.append(Tag(placeholderId: "tag1"))
        XCTAssertTrue(filters.match(collaboration), "collaboration with a matching tag")
    }

    func testTagFiltersMatchUpload() {
        let filters = CanvasFilters()
        filters.tagsFilter = ["tag1", "tag2"]

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertFalse(filters.match(collaboration), "collaboration with no tags")

        let upload1 = Upload(placeholderId: "upload1")
        upload1.tags.append(Tag(placeholderId: "tag 100"))
        collaboration.uploads.insert(upload1)
        XCTAssertFalse(filters.match(collaboration), "collaboration with upload with no matching tags")

        let upload2 = Upload(placeholderId: "upload2")
        upload2.tags.append(Tag(placeholderId: "tag2"))
        collaboration.uploads.insert(upload2)
        XCTAssertTrue(filters.match(collaboration), "collaboration with an upload with a matching tag")
    }
}
