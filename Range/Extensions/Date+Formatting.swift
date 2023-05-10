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
            return "Today @" + timeString() + " (" + calendar._hoursOrMinutesAgoString(from: date, to: now) + ")"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday @" + timeString() + " (" + calendar._hoursOrMinutesAgoString(from: date, to: now) + ")"
        } else if calendar._yearsAgo(from: date, to: now) == 0 {
            // this year
            let dateFormatter = DateFormatter()
            dateFormatter.locale = locale
            dateFormatter.setLocalizedDateFormatFromTemplate("MMM dd")
            return dateFormatter.string(from: date) + " @" + timeString() + " (" + calendar
                ._daysAgoString(from: date, to: now) + ")"
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = locale
            dateFormatter.setLocalizedDateFormatFromTemplate("MMM dd, yyyy")
            return dateFormatter.string(from: date) + " (" + calendar._yearsAgoString(from: date, to: now) + ")"
        }
    }

    /// Returns the formatted date as defined in Figma for primary timestamp type. But it only returns the "ago" part
    /// - Parameter date: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func format1Ago(_ date: Date, now: Date = Date.now, locale: Locale = Locale.current) -> String {
        var calendar = Calendar.current
        calendar.locale = locale

        if calendar.isDate(date, inSameDayAs: now) {
            return calendar._hoursOrMinutesAgoString(from: date, to: now)
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return calendar._hoursOrMinutesAgoString(from: date, to: now)
        } else if calendar._yearsAgo(from: date, to: now) == 0 {
            // this year
            return calendar._daysAgoString(from: date, to: now)
        } else {
            return calendar._yearsAgoString(from: date, to: now)
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
            dateFormatter.locale = locale
            dateFormatter.setLocalizedDateFormatFromTemplate(isThisYear ? "MMM dd" : "MMM dd, yyyy")
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
            dateFormatter.locale = locale
            dateFormatter.setLocalizedDateFormatFromTemplate(isThisYear ? "MMM dd" : "MMM dd, yyyy")
            return "on " + dateFormatter.string(from: date) + " @" + timeString
        }
    }

    /// Returns the formatted date as defined in Figma for media header in media grid view
    /// - Parameter timestamp: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func formatMediaHeader(_ date: Date, now: Date = Date.now,
                                  locale: Locale = Locale.current) -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.locale = locale
        dateFormatter.setLocalizedDateFormatFromTemplate("EE, MMM dd, yyyy")
        let dateString = dateFormatter.string(from: date)

        var calendar = Calendar.current
        calendar.locale = locale

        if calendar.isDate(date, inSameDayAs: now) {
            return "Today • " + dateString
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday)
        {
            return "Yesterday • " + dateString
        } else {
            return dateString
        }
    }

    /// Returns the formatted date as defined in Figma for media title in fullscreen media view
    /// - Parameter timestamp: the date to format
    /// - Parameter now: the current date can be customized - used in tests
    /// - Parameter locale: the locale to be used for formatting, customized in tests
    static func formatMediaTitle(_ date: Date, now _: Date = Date.now,
                                 locale: Locale = Locale.current) -> String
    {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .medium
        dateFormatter.dateStyle = .medium
        dateFormatter.locale = locale
        return dateFormatter.string(from: date)
    }

    /// Apr 6, 2022
    static func dueDateFormat(_ date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.dateStyle = .medium
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        return dateFormatter.string(from: date)
    }

    /// Apr 6
    static func dueDateFormat2(_ date: Date, timeZone: TimeZone?) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = .none
        dateFormatter.setLocalizedDateFormatFromTemplate("MMM dd")
        if let timeZone = timeZone {
            dateFormatter.timeZone = timeZone
        }
        return dateFormatter.string(from: date)
    }
}

extension Calendar {
    // if the difference between date and now is only minutes (<1 hour) returns .. minute(s) ago
    // otherwise  hour(s) ago
    func _hoursOrMinutesAgoString(from: Date, to: Date) -> String {
        if let hoursAgo = dateComponents([.hour], from: from, to: to).hour, hoursAgo > 0 {
            return "\(hoursAgo) \(hoursAgo == 1 ? "hour" : "hours") ago"
        } else if let minutesAgo = dateComponents([.minute], from: from, to: to).minute {
            return "\(minutesAgo) \(minutesAgo == 1 ? "minute" : "minutes") ago"
        } else {
            return ""
        }
    }

    // compute the distance in days in a way that time of a day doesn't matter
    // (e.g. if from is Monday and to is Wednesday on the same week it'll say 2, no matter what time of the day)
    func _daysAgoString(from: Date, to: Date) -> String {
        if let daysAgo = _daysAgo(from: from, to: to) {
            return "\(daysAgo) days ago"
        } else {
            return ""
        }
    }

    // compute the distance in days in a way that time of a day doesn't matter
    // (e.g. if from is Monday and to is Wednesday on the same week it'll say 2, no matter what time of the day)
    func _daysAgo(from: Date, to: Date) -> Int? {
        // reset time of a day
        if let fromNoTime = date(bySettingHour: 0, minute: 0, second: 0, of: from),
           let toNoTime = date(bySettingHour: 0, minute: 0, second: 0, of: to),
           let daysAgo = dateComponents([.day], from: fromNoTime, to: toNoTime).day
        {
            return daysAgo
        } else {
            return nil
        }
    }

    // compute the distance in years by checking how many full years ago it was
    func _yearsAgo(from: Date, to: Date) -> Int {
        if let yearFrom = dateComponents([.year], from: from).year,
           let yearTo = dateComponents([.year], from: to).year
        {
            let yearsAgo = yearTo - yearFrom
            if let sameYearFrom = date(byAdding: .year, value: yearsAgo, to: from), sameYearFrom <= to {
                return max(yearsAgo, 0)
            } else {
                // the difference in years is yearsAgo, but from is > than to if in the same year, so it's not full `yearsAgo`
                return max(yearsAgo - 1, 0)
            }
        } else {
            return 0
        }
    }

    // compute the distance in years by checking how many full years ago it was
    func _yearsAgoString(from: Date, to: Date) -> String {
        if let yearFrom = dateComponents([.year], from: from).year,
           let yearTo = dateComponents([.year], from: to).year
        {
            let yearsAgo = yearTo - yearFrom
            return "\(yearsAgo) \(yearsAgo == 1 ? "year" : "years") ago"
        } else {
            return ""
        }
    }
}
