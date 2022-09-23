@testable import Range
import XCTest

final class ArrayUtilsTest: XCTestCase {
    func testMergeSortedArrays() throws {
        XCTAssertEqual(_mergeSortedArrays(Int.self, [], [1, 2, 3]), [1, 2, 3], "first array empty")
        XCTAssertEqual(_mergeSortedArrays(Int.self, [1, 2, 3], []), [1, 2, 3], "second array empty")
        XCTAssertEqual(_mergeSortedArrays(Int.self, [1, 3, 5], [1, 2, 2, 3, 6]), [1, 1, 2, 2, 3, 3, 5, 6])
        XCTAssertEqual(_mergeSortedArrays(Int.self, [4, 2, 0], [3, 1], ascending: false), [4, 3, 2, 1, 0], "descending")
    }
}
