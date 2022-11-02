import Foundation

extension Date {
    /// Returns the formatted date as defined in Figma for primary timestamp type
    /// - Parameter date: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func format1(_ date: Date, now: Date = Date.now, locale: Locale = Locale.current) -> String {
        var calendar = Calendar.current
        calendar.locale = locale

        let timeString = {
            let timeFormatter = DateFormatter()
            timeFormatter.dateStyle = .none
            timeFormatter.timeStyle = .short
            timeFormatter.locale = locale
            return timeFormatter.string(from: date)
        }

        if calendar.isDate(date, inSameDayAs: now) {
            return "Today @" + timeString() + calendar._hoursOrMinutesAgo(from: date, to: now)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday @" + timeString() + calendar._hoursOrMinutesAgo(from: date, to: now)
        } else if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            // this year
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd"
            dateFormatter.locale = locale
            return dateFormatter.string(from: date) + " @" + timeString() + calendar._daysAgo(from: date, to: now)
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM dd, yyyy"
            dateFormatter.locale = locale
            return dateFormatter.string(from: date) + calendar._yearsAgo(from: date, to: now)
        }
    }

    /// Returns the formatted date as defined in Figma for secondary timestamp type
    /// - Parameter date: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func format2(_ date: Date, now: Date = Date.now, locale: Locale = Locale.current) -> String {
        var calendar = Calendar.current
        calendar.locale = locale

        if calendar.isDate(date, inSameDayAs: now) {
            return "today"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "yesterday"
        } else {
            let dateFormatter = DateFormatter()
            let isThisYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
            dateFormatter.dateFormat = isThisYear ? "MMM dd" : "MMM dd, yyyy"
            dateFormatter.locale = locale
            return "on " + dateFormatter.string(from: date)
        }
    }

    /// Returns the formatted date as defined in Figma for tertiary timestamp type
    /// - Parameter timestamp: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func format3(_ date: Date, now: Date = Date.now,
                        locale: Locale = Locale.current) -> String
    {
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        timeFormatter.locale = locale
        let timeString = timeFormatter.string(from: date)

        var calendar = Calendar.current
        calendar.locale = locale

        if calendar.isDate(date, inSameDayAs: now) {
            return "Today @" + timeString
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday @" + timeString
        } else {
            let dateFormatter = DateFormatter()
            let isThisYear = Calendar.current.isDate(date, equalTo: now, toGranularity: .year)
            dateFormatter.dateFormat = isThisYear ? "MMM dd" : "MMM dd, yyyy"
            dateFormatter.locale = locale
            return "on " + dateFormatter.string(from: date) + " @" + timeString
        }
    }

    static func dueDateFormat(_ date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .medium
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        return dateFormatter.string(from: date)
    }

    static func dueDateFormat2(_ date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .long
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        return dateFormatter.string(from: date)
    }
}

extension Calendar {
    // if the difference between date and now is only minutes (<1 hour) returns .. minute(s) ago
    // otherwise  hour(s) ago
    func _hoursOrMinutesAgo(from: Date, to: Date) -> String {
        if let hoursAgo = dateComponents([.hour], from: from, to: to).hour, hoursAgo > 0 {
            return " (\(hoursAgo) \(hoursAgo == 1 ? "hour" : "hours") ago)"
        } else if let minutesAgo = dateComponents([.minute], from: from, to: to).minute {
            return " (\(minutesAgo) \(minutesAgo == 1 ? "minute" : "minutes") ago)"
        } else {
            return ""
        }
    }

    // compute the distance in days in a way that time of a day doesn't matter
    // (e.g. if from is Monday and to is Wednesday on the same week it'll say 2, no matter what time of the day)
    func _daysAgo(from: Date, to: Date) -> String {
        // reset time of a day
        if let fromNoTime = date(bySettingHour: 0, minute: 0, second: 0, of: from),
           let toNoTime = date(bySettingHour: 0, minute: 0, second: 0, of: to),
           let daysAgo = dateComponents([.day], from: fromNoTime, to: toNoTime).day
        {
            return " (\(daysAgo) days ago)"
        } else {
            return ""
        }
    }

    // compute the distance in years by subtracting the to and from years
    // (e.g. if from is Dec 2021 and to Jan 2022 it'll say 1, even if 1 year hasn't passed yet)
    func _yearsAgo(from: Date, to: Date) -> String {
        if let yearFrom = dateComponents([.year], from: from).year,
           let yearTo = dateComponents([.year], from: to).year
        {
            let yearsAgo = yearTo - yearFrom
            return " (\(yearsAgo) \(yearsAgo == 1 ? "year" : "years") ago)"
        } else {
            return ""
        }
    }
}
