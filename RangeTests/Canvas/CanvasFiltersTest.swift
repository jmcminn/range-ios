@testable import Range
import XCTest

final class CanvasFiltersTest: XCTestCase {
    func testAssigneeFiltersForPhotoPin() {
        let filters = CanvasFilters()
        filters.assigneeFilter = ["user1"]

        let photoPin = Collaboration(placeholderId: "collaboration1")

        XCTAssertTrue(filters.match(photoPin), "photo pin is not filtered by assignee")
    }

    func testAssigneeFiltersForTaskPin() {
        let filters = CanvasFilters()
        filters.assigneeFilter = ["user1", "user2"]

        let unassignedTaskPin = Collaboration(placeholderId: "collaboration1")
        unassignedTaskPin.status = Status(placeholderId: "status1")

        let assignedTaskPin = Collaboration(placeholderId: "collaboration2")
        assignedTaskPin.status = Status(placeholderId: "status1")
        assignedTaskPin.assignee = Participant(placeholderId: "user2")

        XCTAssertFalse(
            filters.match(unassignedTaskPin),
            "unassigned task doesn't match the assignee filter with user id"
        )
        XCTAssertTrue(filters.match(assignedTaskPin), "assigned task matches the assignee filter with user id")

        filters.assigneeFilter = [UserViewModel.unassignedUserId]
        XCTAssertTrue(
            filters.match(unassignedTaskPin),
            "unassigned task matches the assignee filter for unnassigned tasks"
        )
        XCTAssertFalse(
            filters.match(assignedTaskPin),
            "assigned task doesn't match the assignee filter for unassigned tasks"
        )
    }

    func testEmptyTagFilters() {
        let filters = CanvasFilters()
        filters.tagsFilter = []

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertTrue(filters.match(collaboration), "no tags in filter matches any collaboration")
    }

    func testTagFiltersMatchCollaboration() {
        let filters = CanvasFilters()
        filters.tagsFilter = ["tag1"]

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertFalse(filters.match(collaboration), "collaboration with no tags")

        collaboration.tags.append(Tag(placeholderId: "tag1"))
        XCTAssertTrue(filters.match(collaboration), "collaboration with a matching tag")
    }

    func testTagFiltersMatchUpload() {
        let filters = CanvasFilters()
        filters.tagsFilter = ["tag1"]

        let collaboration = Collaboration(placeholderId: "collaboration1")
        XCTAssertFalse(filters.match(collaboration), "collaboration with no tags")

        let upload1 = Upload(placeholderId: "upload1")
        upload1.tags.append(Tag(placeholderId: "tag 100"))
        collaboration.uploads.insert(upload1)
        XCTAssertFalse(filters.match(collaboration), "collaboration with upload with no matching tags")

        let upload2 = Upload(placeholderId: "upload2")
        upload2.tags.append(Tag(placeholderId: "tag1"))
        collaboration.uploads.insert(upload2)
        XCTAssertTrue(filters.match(collaboration), "collaboration with an upload with a matching tag")
    }

    func testTagFiltersAllTagsShouldMatch() {
        let filters = CanvasFilters()
        filters.tagsFilter = ["tag1", "tag2"]

        let collaboration = Collaboration(placeholderId: "collaboration1")
        collaboration.tags.append(Tag(placeholderId: "tag1"))
        XCTAssertFalse(filters.match(collaboration), "collaboration matches only 1 tag")

        let upload = Upload(placeholderId: "upload1")
        upload.tags.append(Tag(placeholderId: "tag2"))
        collaboration.uploads.insert(upload)
        XCTAssertTrue(filters.match(collaboration), "collaboration and upload match both tags")
    }
}
