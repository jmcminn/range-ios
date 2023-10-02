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

    private func formatMediaHeader(_ timestamp: String, now: String) -> String {
        Date.formatMediaHeader(_t(timestamp), now: _t(now), locale: locale)
    }

    private func formatMediaTitle(_ timestamp: String, now: String) -> String {
        Date.formatMediaTitle(_t(timestamp), now: _t(now), locale: locale)
    }

    func testFormat1() throws {
        // today
        XCTAssertEqual(format1("2021-06-02 15:26", now: "2021-06-02 15:27"), "Today @3:26 PM (1 minute ago)")
        XCTAssertEqual(format1("2021-06-02 15:00", now: "2021-06-02 15:27"), "Today @3:00 PM (27 minutes ago)")
        XCTAssertEqual(format1("2021-06-02 14:00", now: "2021-06-02 15:27"), "Today @2:00 PM (1 hour ago)")
        XCTAssertEqual(format1("2021-06-02 13:20", now: "2021-06-02 15:27"), "Today @1:20 PM (2 hours ago)")
        // yesterday
        XCTAssertEqual(format1("2021-06-02 23:59", now: "2021-06-03 00:00"), "Yesterday @11:59 PM (1 minute ago)")
        XCTAssertEqual(format1("2021-06-02 23:45", now: "2021-06-03 00:15"), "Yesterday @11:45 PM (30 minutes ago)")
        XCTAssertEqual(format1("2021-06-02 23:10", now: "2021-06-03 00:15"), "Yesterday @11:10 PM (1 hour ago)")
        XCTAssertEqual(format1("2021-06-02 11:00", now: "2021-06-03 14:15"), "Yesterday @11:00 AM (27 hours ago)")
        // < 1 year ago
        XCTAssertEqual(format1("2021-05-31 15:40", now: "2021-06-02 15:27"), "May 31 @3:40 PM (2 days ago)")
        XCTAssertEqual(format1("2021-05-31 15:26", now: "2021-06-02 15:27"), "May 31 @3:26 PM (2 days ago)")
        XCTAssertEqual(format1("2023-07-24 22:31", now: "2023-08-01 13:57"), "Jul 24 @10:31 PM (8 days ago)")
        XCTAssertEqual(format1("2021-01-01 00:01", now: "2021-06-02 15:27"), "Jan 01 @12:01 AM (152 days ago)")
        XCTAssertEqual(format1("2021-01-02 00:01", now: "2022-01-01 15:27"), "Jan 02 @12:01 AM (364 days ago)")
        // older
        XCTAssertEqual(format1("2020-01-01 23:59", now: "2021-01-02 15:27"), "Jan 01, 2020 (1 year ago)")
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
        XCTAssertEqual(format3("2021-06-02 15:26", now: "2021-06-02 15:27"), "Today @3:26 PM")
        // yesterday
        XCTAssertEqual(format3("2021-06-02 23:59", now: "2021-06-03 00:00"), "Yesterday @11:59 PM")
        XCTAssertEqual(format3("2021-06-02 11:00", now: "2021-06-03 14:15"), "Yesterday @11:00 AM")
        // same year
        XCTAssertEqual(format3("2021-05-31 15:40", now: "2021-06-02 15:27"), "on May 31 @3:40 PM")
        XCTAssertEqual(format3("2021-01-01 00:01", now: "2021-06-02 15:27"), "on Jan 01 @12:01 AM")
        // older
        XCTAssertEqual(format3("2020-12-31 23:59", now: "2021-06-02 15:27"), "on Dec 31, 2020 @11:59 PM")
        XCTAssertEqual(format3("2000-01-01 00:59", now: "2021-06-02 15:27"), "on Jan 01, 2000 @12:59 AM")
    }

    func testFormatMediaHeader() throws {
        // today
        XCTAssertEqual(
            formatMediaHeader("2021-06-02 15:26", now: "2021-06-02 15:27"),
            "Today • Wed, Jun 02, 2021"
        )
        // yesterday
        XCTAssertEqual(
            formatMediaHeader("2021-06-02 23:59", now: "2021-06-03 00:00"),
            "Yesterday • Wed, Jun 02, 2021"
        )
        // other
        XCTAssertEqual(formatMediaHeader("2021-05-31 15:40", now: "2021-06-02 15:27"), "Mon, May 31, 2021")
        XCTAssertEqual(formatMediaHeader("2021-01-01 00:01", now: "2021-06-02 15:27"), "Fri, Jan 01, 2021")
        XCTAssertEqual(formatMediaHeader("2000-01-01 00:59", now: "2021-06-02 15:27"), "Sat, Jan 01, 2000")
    }

    func testFormatMediaTitle() throws {
        // today
        XCTAssertEqual(formatMediaTitle("2021-06-02 15:26", now: "2021-06-02 15:27"), "Jun 2, 2021 at 3:26:00 PM")
        // yesterday
        XCTAssertEqual(formatMediaTitle("2021-06-02 23:59", now: "2021-06-03 00:00"), "Jun 2, 2021 at 11:59:00 PM")
        // other
        XCTAssertEqual(formatMediaTitle("2021-05-31 15:40", now: "2021-06-02 15:27"), "May 31, 2021 at 3:40:00 PM")
        XCTAssertEqual(formatMediaTitle("2021-01-01 00:01", now: "2021-06-02 15:27"), "Jan 1, 2021 at 12:01:00 AM")
        XCTAssertEqual(formatMediaTitle("2000-01-01 00:59", now: "2021-06-02 15:27"), "Jan 1, 2000 at 12:59:00 AM")
    }
}
