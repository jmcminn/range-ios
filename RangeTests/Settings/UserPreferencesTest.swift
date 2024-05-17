
@testable import Range
import XCTest

final class UserPreferencesTest: XCTestCase {
    private let projectId = "project1"
    let userPreferences = UserPreferences(userId: "user1")

    override func setUp() {
        // reset the tags before running the tests
        userPreferences.defaults.removeObject(forKey: userPreferences.recentTagsKey(forProjectId: projectId))
    }

    func testRecentTags() throws {
        let recentTags = {
            self.userPreferences.recentTagIds(forProjectId: self.projectId)
        }

        // no tags added yet
        XCTAssertTrue(recentTags().isEmpty)

        // add some recent tags
        userPreferences.addRecentTagIds(["3", "1", "2"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["3", "1", "2"])

        // re-add a tag
        userPreferences.addRecentTagIds(["1"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["3", "2", "1"])

        // add tags over the limit of 10
        userPreferences.addRecentTagIds(["a", "b", "c", "d", "e", "f", "g", "h"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["2", "1", "a", "b", "c", "d", "e", "f", "g", "h"])
    }
}
