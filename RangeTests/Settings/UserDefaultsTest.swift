
@testable import Range
import XCTest

final class UserDefaultsTest: XCTestCase {
    private let projectId = "project1"

    override func setUp() {
        // reset the tags before running the tests
        UserDefaults.standard.removeObject(forKey: UserDefaults.recentTagsKey(forProjectId: projectId))
    }

    func testRecentTags() throws {
        let recentTags = {
            UserDefaults.recentTagIds(forProjectId: self.projectId)
        }

        // no tags added yet
        XCTAssertTrue(recentTags().isEmpty)

        // add some recent tags
        UserDefaults.addRecentTagIds(["3", "1", "2"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["3", "1", "2"])

        // re-add a tag
        UserDefaults.addRecentTagIds(["1"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["3", "2", "1"])

        // add tags over the limit of 10
        UserDefaults.addRecentTagIds(["a", "b", "c", "d", "e", "f", "g", "h"], forProjectId: projectId)
        XCTAssertEqual(recentTags(), ["2", "1", "a", "b", "c", "d", "e", "f", "g", "h"])
    }
}
