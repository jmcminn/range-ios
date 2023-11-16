@testable import Range
import XCTest

final class DateOptionsTest: XCTestCase {
    let formatter = DateFormatter()
    let locale = Locale(identifier: "en-US")
    let timeZone = TimeZone(identifier: "Europe/Warsaw")!

    override func setUpWithError() throws {
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = locale
        formatter.timeZone = timeZone
    }

    // helper function to return Date for given time string formatted as
    // YYYY-MM-dd HH:mm
    private func _t(_ timeString: String) -> Date {
        formatter.date(from: timeString)!
    }

    private func isTimestampInLastNDays(_ days: Int, timestamp: String, now: String) -> Bool {
        DateOptions.isTimestampInLastNDays(days, timestamp: _t(timestamp), now: _t(now), timeZone: timeZone)
    }

    func testIsTimestampInLasNDays() throws {
        XCTAssertTrue(
            isTimestampInLastNDays(1, timestamp: "2023-11-16 15:12", now: "2023-11-16 15:11"),
            "It's in the future"
        )
        XCTAssertTrue(
            isTimestampInLastNDays(1, timestamp: "2023-11-16 15:10", now: "2023-11-16 15:11"),
            "It's 1 minute ago"
        )
        XCTAssertTrue(
            isTimestampInLastNDays(1, timestamp: "2023-11-15 15:12", now: "2023-11-16 15:11"),
            "It's yesterday"
        )
        XCTAssertTrue(
            isTimestampInLastNDays(1, timestamp: "2023-11-15 01:12", now: "2023-11-16 15:11"),
            "It's yesterday morning"
        )
        XCTAssertFalse(
            isTimestampInLastNDays(1, timestamp: "2023-11-14 22:12", now: "2023-11-16 15:11"),
            "The day before yesterday"
        )
        XCTAssertTrue(
            isTimestampInLastNDays(2, timestamp: "2023-11-14 22:12", now: "2023-11-16 15:11"),
            "The day before yesterday"
        )
        XCTAssertFalse(
            isTimestampInLastNDays(15, timestamp: "2023-10-31 22:12", now: "2023-11-16 15:11"),
            "It's 16 days ago"
        )
        XCTAssertTrue(
            isTimestampInLastNDays(16, timestamp: "2023-10-31 22:12", now: "2023-11-16 15:11"),
            "It's 16 days ago"
        )
    }
}
