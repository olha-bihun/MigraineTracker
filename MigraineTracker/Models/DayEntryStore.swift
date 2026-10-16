import Foundation
import SwiftData

struct DaySnapshot: Equatable {
    var hasMigraine = false
    var triggerIDs: Set<String> = []
    var migraineKind: String? = nil
    var comment = ""
    var isEmpty: Bool { !hasMigraine && triggerIDs.isEmpty && comment.isEmpty }
    var limited: DaySnapshot {
        var copy = self
        copy.comment = String(comment.prefix(200))
        return copy
    }

    var migraineEmoji: String {
        guard hasMigraine else { return "" }
        switch migraineKind {
        case "withoutAura": return "🤕"
        case "withAura": return "😵‍💫"
        case "both": return "🤕😵‍💫"
        default: return "❔"
        }
    }

    var withAura: Bool { hasMigraine && (migraineKind == "withAura" || migraineKind == "both") }
    var withoutAura: Bool { hasMigraine && (migraineKind == "withoutAura" || migraineKind == "both") }

    // Turning a type on replaces the other type; turning it off preserves the other.
    mutating func toggleMigraine(aura: Bool, enabled: Bool) {
        if aura {
            setMigraine(withAura: enabled, withoutAura: enabled ? false : withoutAura)
        } else {
            setMigraine(withAura: enabled ? false : withAura, withoutAura: enabled)
        }
    }

    mutating func setMigraine(withAura: Bool, withoutAura: Bool) {
        hasMigraine = withAura || withoutAura
        migraineKind = withAura && withoutAura ? "both" : (withAura ? "withAura" : (withoutAura ? "withoutAura" : nil))
    }
}

@MainActor
struct DayEntryStore {
    let container: ModelContainer
    var commit: (ModelContext) throws -> Void = { try $0.save() }

    enum MoveError: LocalizedError {
        case occupied, missing, future
        var errorDescription: String? {
            switch self {
            case .occupied: L10n.text("На цю дату вже є запис. Обери інший день.")
            case .missing: L10n.text("Початковий запис більше не існує.")
            case .future: L10n.text("Не можна перенести запис у майбутнє.")
            }
        }
    }

    func move(from source: Date, to destination: Date, timeZone: TimeZone) throws {
        let sourceKey = DayEntry.key(for: source, timeZone: timeZone)
        let destinationKey = DayEntry.key(for: destination, timeZone: timeZone)
        guard destinationKey <= DayEntry.key(for: Date()) else { throw MoveError.future }
        guard sourceKey != destinationKey else { return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            guard let original = try entry(date: source, timeZone: timeZone, context: context) else {
                throw MoveError.missing
            }
            guard try entry(date: destination, timeZone: timeZone, context: context) == nil else {
                throw MoveError.occupied
            }
            context.insert(DayEntry(date: destination, timeZone: timeZone,
                                    hasMigraine: original.hasMigraine, triggerIDs: original.triggerIDs, migraineKind: original.migraineKind, comment: original.comment))
            context.delete(original)
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadAll() throws -> [String: DaySnapshot] {
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<DayEntry>()).reduce(into: [:]) { result, entry in
            result[entry.dayKey] = DaySnapshot(hasMigraine: entry.hasMigraine, triggerIDs: Set(entry.triggerIDs), migraineKind: entry.migraineKind, comment: entry.comment)
        }
    }

    func load(date: Date, timeZone: TimeZone) throws -> DaySnapshot {
        let context = ModelContext(container)
        guard let entry = try entry(date: date, timeZone: timeZone, context: context) else {
            return DaySnapshot()
        }
        return DaySnapshot(hasMigraine: entry.hasMigraine, triggerIDs: Set(entry.triggerIDs), migraineKind: entry.migraineKind, comment: entry.comment)
    }

    func save(_ snapshot: DaySnapshot, date: Date, timeZone: TimeZone) throws {
        // A dedicated context prevents failed edits from leaking into the UI or autosave.
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let existing = try entry(date: date, timeZone: timeZone, context: context)
            if snapshot.isEmpty {
                if let existing { context.delete(existing) }
            } else {
                let record = existing ?? DayEntry(date: date, timeZone: timeZone)
                if existing == nil { context.insert(record) }
                record.comment = String(snapshot.comment.prefix(200))
                record.hasMigraine = snapshot.hasMigraine
                record.migraineKind = snapshot.hasMigraine ? snapshot.migraineKind : nil
                record.setTriggerIDs(Array(snapshot.triggerIDs))
            }
            try commit(context)
        } catch {
            context.rollback()
            throw error
        }
    }

    private func entry(date: Date, timeZone: TimeZone, context: ModelContext) throws -> DayEntry? {
        let key = DayEntry.key(for: date, timeZone: timeZone)
        var request = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.dayKey == key })
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
