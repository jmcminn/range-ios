@testable import Range
import XCTest

final class DateFormattingTest: XCTestCase {
    let formatter = DateFormatter()
    let locale = Locale(identifier: "en-US")

    override func setUpWithError() throws {
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = locale
    }

    // helper function to return Date for given time string formatted as
    // YYYY-MM-dd HH:mm
    private func _t(_ timeString: String) -> Date {
        formatter.date(from: timeString)!
    }

    // helper functions for shorter tests
    private func format1(_ timestamp: String, now: String) -> String {
        Date.format1(_t(timestamp), now: _t(now), locale: locale)
    }

    private func format2(_ timestamp: String, now: String) -> String {
        Date.format2(_t(timestamp), now: _t(now), locale: locale)
    }

    private func format3(_ timestamp: String, now: String) -> String {
        Date.format3(_t(timestamp), now: _t(now), locale: locale)
    }

    func testFormat1() throws {
        // today
        XCTAssertEqual(format1("2021-06-02 15:26", now: "2021-06-02 15:27"), "Today @3:26 PM (1 minute ago)")
        XCTAssertEqual(format1("2021-06-02 15:00", now: "2021-06-02 15:27"), "Today @3:00 PM (27 minutes ago)")
        XCTAssertEqual(format1("2021-06-02 14:00", now: "2021-06-02 15:27"), "Today @2:00 PM (1 hour ago)")
        XCTAssertEqual(format1("2021-06-02 13:20", now: "2021-06-02 15:27"), "Today @1:20 PM (2 hours ago)")
        // yesterday
        XCTAssertEqual(format1("2021-06-02 23:59", now: "2021-06-03 00:00"), "Yesterday @11:59 PM (1 minute ago)")
        XCTAssertEqual(format1("2021-06-02 23:45", now: "2021-06-03 00:15"), "Yesterday @11:45 PM (30 minutes ago)")
        XCTAssertEqual(format1("2021-06-02 23:10", now: "2021-06-03 00:15"), "Yesterday @11:10 PM (1 hour ago)")
        XCTAssertEqual(format1("2021-06-02 11:00", now: "2021-06-03 14:15"), "Yesterday @11:00 AM (27 hours ago)")
        // same year
        XCTAssertEqual(format1("2021-05-31 15:40", now: "2021-06-02 15:27"), "May 31 @3:40 PM (2 days ago)")
        XCTAssertEqual(format1("2021-05-31 15:26", now: "2021-06-02 15:27"), "May 31 @3:26 PM (2 days ago)")
        XCTAssertEqual(format1("2021-01-01 00:01", now: "2021-06-02 15:27"), "Jan 01 @12:01 AM (152 days ago)")
        // older
        XCTAssertEqual(format1("2020-12-31 23:59", now: "2021-06-02 15:27"), "Dec 31, 2020 (1 year ago)")
        XCTAssertEqual(format1("2020-01-01 00:59", now: "2021-06-02 15:27"), "Jan 01, 2020 (1 year ago)")
        XCTAssertEqual(format1("2000-01-01 00:59", now: "2021-06-02 15:27"), "Jan 01, 2000 (21 years ago)")
    }

    func testFormat2() throws {
        // today
        XCTAssertEqual(format2("2021-06-02 15:26", now: "2021-06-02 15:27"), "today")
        // yesterday
        XCTAssertEqual(format2("2021-06-02 23:59", now: "2021-06-03 00:00"), "yesterday")
        XCTAssertEqual(format2("2021-06-02 11:00", now: "2021-06-03 14:15"), "yesterday")
        // same year
        XCTAssertEqual(format2("2021-05-31 15:40", now: "2021-06-02 15:27"), "on May 31")
        XCTAssertEqual(format2("2021-01-01 00:01", now: "2021-06-02 15:27"), "on Jan 01")
        // older
        XCTAssertEqual(format2("2020-12-31 23:59", now: "2021-06-02 15:27"), "on Dec 31, 2020")
        XCTAssertEqual(format2("2000-01-01 00:59", now: "2021-06-02 15:27"), "on Jan 01, 2000")
    }

    func testFormat3() throws {
        // today
        XCTAssertEqual(format3("2021-06-02 15:26", now: "2021-06-02 15:27"), "Today @3:26 PM")
        // yesterday
        XCTAssertEqual(format3("2021-06-02 23:59", now: "2021-06-03 00:00"), "Yesterday @11:59 PM")
        XCTAssertEqual(format3("2021-06-02 11:00", now: "2021-06-03 14:15"), "Yesterday @11:00 AM")
        // same year
        XCTAssertEqual(format3("2021-05-31 15:40", now: "2021-06-02 15:27"), "on May 31 @3:40 PM")
        XCTAssertEqual(format3("2021-01-01 00:01", now: "2021-06-02 15:27"), "on Jan 01 @12:01 AM")
        // older
        XCTAssertEqual(format3("2020-12-31 23:59", now: "2021-06-02 15:27"), "on Dec 31, 2020 @11:59 PM")
        XCTAssertEqual(format3("2000-01-01 00:59", now: "2021-06-02 15:27"), "on Jan 01, 2000 @12:59 AM")
    }
}
