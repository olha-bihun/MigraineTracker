import Foundation
import SwiftData

@Model
final class DayEntry {
    @Attribute(.unique) private(set) var dayKey: String
    var hasMigraine: Bool
    var migraineKind: String? = nil
    var comment: String = ""
    private(set) var triggerIDs: [String]

    /// Capture the selected date in its time zone once; never recompute stored keys.
    init(date: Date, timeZone: TimeZone = .current,
         hasMigraine: Bool = false, triggerIDs: [String] = [], migraineKind: String? = nil, comment: String = "") {
        self.comment = String(comment.prefix(200))
        self.dayKey = Self.key(for: date, timeZone: timeZone)
        self.hasMigraine = hasMigraine
        self.migraineKind = hasMigraine ? migraineKind : nil
        self.triggerIDs = Array(Set(triggerIDs)).sorted()
    }

    func setTriggerIDs(_ ids: [String]) {
        triggerIDs = Array(Set(ids)).sorted()
    }

    static func key(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"),
                      parts.year!, parts.month!, parts.day!)
    }
}
