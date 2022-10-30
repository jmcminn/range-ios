import Foundation

extension Date {
    /// Returns a date with same day as this date but with time updated to 23:59:59 in given timezone
    func _endOfDay(in timeZone: TimeZone) -> Date? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        return calendar.date(bySettingHour: 23, minute: 59, second: 59, of: self)
    }
}
