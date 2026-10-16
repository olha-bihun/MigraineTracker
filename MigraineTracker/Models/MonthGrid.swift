import Foundation

enum MonthGrid {
    static func label(_ date: Date, template: String, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = L10n.locale
        formatter.calendar = calendar(timeZone: timeZone)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    static func calendar(timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = L10n.locale
        calendar.timeZone = timeZone
        var regional = Calendar(identifier: .gregorian)
        regional.locale = L10n.locale
        calendar.firstWeekday = regional.firstWeekday
        return calendar
    }

    static func days(in month: Date, calendar: Calendar) -> [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start,
              let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + range.map {
            calendar.date(byAdding: .day, value: $0 - 1, to: start)
        }
    }
}
