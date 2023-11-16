import Foundation

enum DateOptions {
    /// By default we show the date options for given Last n days
    static let defaultDaysOptions: [Int] = [1, 5, 7, 14, 30]

    /// Given an array of days options to represent returns an array of ActionItem for each days value. The ActionItem is configured
    /// with a handler than runs given handler with the specific days value. Additionally the
    static func buildOptionItems(_ daysOptions: [Int], handler: @escaping (Int) -> Void) -> [ActionItem] {
        daysOptions.map { days in
            ActionItem(
                title: String(localized: days == 1 ? "Last day" : "Last \(days) days"),
                handler: { handler(days) }
            )
        }
    }

    /// Returns true when given timestamp is within the last <days> days. Meaning it is >=  <today - days>.
    /// The function uses the current timezone by default but this can be customised (for tests). For tests the value of `now` is also fixed
    static func isTimestampInLastNDays(
        _ days: Int,
        timestamp: Date,
        now: Date = Date.now,
        timeZone: TimeZone = TimeZone.current
    ) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timeZone

        let numberOfDaysComponents = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: timestamp),
            to: calendar.startOfDay(for: now)
        )
        if let numberOfDays = numberOfDaysComponents.day {
            return numberOfDays <= days
        }

        return false
    }
}
