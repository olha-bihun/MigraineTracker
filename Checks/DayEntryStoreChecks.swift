// Compile with the files in MigraineTracker/Models using xcrun swiftc, then run.
import Foundation
import SwiftData

@main
struct DayEntryStoreChecks {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("checks.store"), cloudKitDatabase: .none)
        let zone = TimeZone(secondsFromGMT: 0)!
        let date = ISO8601DateFormatter().date(from: "2026-10-15T12:00:00Z")!
        let yesterday = date.addingTimeInterval(-86400)
        var calendar = MonthGrid.calendar(timeZone: zone)
        calendar.firstWeekday = 2
        let february = calendar.date(from: DateComponents(year: 2024, month: 2, day: 15))!
        let grid = MonthGrid.days(in: february, calendar: calendar)
        precondition(grid.compactMap { $0 }.count == 29)
        precondition(grid.prefix(3).allSatisfy { $0 == nil })
        let december = calendar.date(from: DateComponents(year: 2025, month: 12, day: 1))!
        let january = calendar.date(byAdding: .month, value: 1, to: december)!
        precondition(DayEntry.key(for: january, timeZone: zone) == "2026-01-01")
        precondition(MonthGrid.days(in: january, calendar: calendar).compactMap { $0 }.count == 31)
        do {
            let container = try ModelContainer(for: DayEntry.self, configurations: configuration)
            let store = DayEntryStore(container: container)
            let empty = try store.load(date: date, timeZone: zone)
            precondition(!empty.hasMigraine && empty.triggerIDs.isEmpty)
            try store.save(DaySnapshot(hasMigraine: true, triggerIDs: ["stress", "dehydration"]), date: date, timeZone: zone)
            try store.save(DaySnapshot(hasMigraine: true), date: yesterday, timeZone: zone)
            try store.save(DaySnapshot(hasMigraine: false, triggerIDs: ["stress", "dehydration"]), date: date, timeZone: zone)
        }
        // Open a fresh container to check the on-disk record, not an in-memory snapshot.
        let container = try ModelContainer(for: DayEntry.self, configurations: configuration)
        let store = DayEntryStore(container: container)
        var saved = try store.load(date: date, timeZone: zone)
        precondition(!saved.hasMigraine && saved.triggerIDs == ["stress", "dehydration"])
        saved.triggerIDs.remove("stress")
        try store.save(saved, date: date, timeZone: zone)
        let reduced = try store.load(date: date, timeZone: zone)
        precondition(reduced.triggerIDs == ["dehydration"])
        try store.save(DaySnapshot(), date: date, timeZone: zone)
        let context = ModelContext(container)
        let records = try context.fetch(FetchDescriptor<DayEntry>())
        precondition(records.count == 1 && records[0].dayKey == "2026-10-14" && records[0].hasMigraine)
        let markers = try store.loadAll()
        precondition(markers.count == 1 && markers["2026-10-14"]?.hasMigraine == true)
        enum TestFailure: Error { case diskUnavailable }
        let key = DayEntry.key(for: yesterday, timeZone: zone)
        var editor = DayEditorState()
        editor.load(key: key) { try store.loadAll() }
        let original = editor.snapshot
        let originalMarkers = editor.records
        var failingStore = store
        failingStore.commit = { _ in throw TestFailure.diskUnavailable }
        for proposed in [DaySnapshot(hasMigraine: false, triggerIDs: ["stress"]), DaySnapshot()] {
            editor.save(proposed, key: key) {
                try failingStore.save(proposed, date: yesterday, timeZone: zone)
            }
            precondition(editor.snapshot == original && editor.records == originalMarkers)
            precondition(editor.errorMessage != nil && editor.isLoaded)
            let persisted = try store.load(date: yesterday, timeZone: zone)
            precondition(persisted == original)
        }
        do {
            try failingStore.save(DaySnapshot(hasMigraine: true), date: date, timeZone: zone)
            preconditionFailure("Injected commit must fail")
        } catch TestFailure.diskUnavailable {}
        let afterFailedInsert = try store.loadAll()
        precondition(afterFailedInsert == originalMarkers)
        editor.load(key: key) { throw TestFailure.diskUnavailable }
        precondition(!editor.isLoaded && editor.records.isEmpty && editor.errorMessage != nil)
        var attemptedWrite = false
        editor.save(DaySnapshot(hasMigraine: true), key: key) { attemptedWrite = true }
        precondition(!attemptedWrite)
        editor.load(key: key) { try store.loadAll() }
        precondition(editor.isLoaded && editor.snapshot == original && editor.errorMessage == nil)
        print("PASS: failed update/delete/insert rollback; screen selection and markers unchanged; failed load blocks edits; retry recovers")
        let destination = yesterday.addingTimeInterval(-86400)
        let beforeMove = try store.loadAll()
        do {
            try failingStore.move(from: yesterday, to: destination, timeZone: zone)
            preconditionFailure("Move must fail")
        } catch TestFailure.diskUnavailable {}
        let afterFailedMove = try store.loadAll()
        precondition(beforeMove == afterFailedMove)
        try store.move(from: yesterday, to: destination, timeZone: zone)
        let moved = try store.load(date: destination, timeZone: zone)
        precondition(moved == original)
        let old = try store.load(date: yesterday, timeZone: zone)
        precondition(old == DaySnapshot())
        try store.save(DaySnapshot(triggerIDs: ["stress"]), date: yesterday, timeZone: zone)
        let beforeConflict = try store.loadAll()
        do {
            try store.move(from: destination, to: yesterday, timeZone: zone)
            preconditionFailure("Occupied destination must reject move")
        } catch DayEntryStore.MoveError.occupied {}
        let afterConflict = try store.loadAll()
        precondition(beforeConflict == afterConflict)
        try store.save(DaySnapshot(), date: destination, timeZone: zone)
        let deleted = try store.load(date: destination, timeZone: zone)
        precondition(deleted == DaySnapshot())
        try store.save(moved, date: destination, timeZone: zone)
        let restored = try store.load(date: destination, timeZone: zone)
        precondition(restored == original)
        print("PASS: atomic move, move rollback, occupied date preserved, delete and restore")
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        defer {
            if let savedLanguage { UserDefaults.standard.set(savedLanguage, forKey: "appLanguage") }
            else { UserDefaults.standard.removeObject(forKey: "appLanguage") }
        }
        for (language, expectedMonth) in [("uk", "жовтень"), ("en", "october"), ("ru", "октябрь")] {
            UserDefaults.standard.set(language, forKey: "appLanguage")
            let month = MonthGrid.label(date, template: "LLLL", timeZone: zone).lowercased()
            precondition(month == expectedMonth, month)
            precondition(TriggerCatalog.all.count == 16 && Set(TriggerCatalog.all.map(\.id)).count == 16)
        }
        let customURL = directory.appendingPathComponent("custom.store")
        let customConfig = ModelConfiguration(url: customURL, cloudKitDatabase: .none)
        var customID = ""
        do {
            let combined = try ModelContainer(for: DayEntry.self, CustomTrigger.self, configurations: customConfig)
            let context = ModelContext(combined)
            let custom = CustomTrigger(name: "Test custom", emoji: "✨")
            customID = custom.id
            context.insert(custom)
            context.insert(DayEntry(date: date, timeZone: zone, triggerIDs: [custom.id]))
            try context.save()
        }
        let reopened = try ModelContainer(for: DayEntry.self, CustomTrigger.self, configurations: customConfig)
        let customContext = ModelContext(reopened)
        let custom = try customContext.fetch(FetchDescriptor<CustomTrigger>())
        precondition(custom.count == 1 && custom[0].id == customID && custom[0].emoji == "✨")
        let linked = try DayEntryStore(container: reopened).load(date: date, timeZone: zone)
        precondition(linked.triggerIDs.contains(customID))
        print("PASS: three calendar languages, stable trigger IDs, custom emoji persistence and diary association")
        let auraStore = DayEntryStore(container: reopened)
        for kind in ["withAura", "withoutAura"] {
            let state = DaySnapshot(hasMigraine: true, triggerIDs: [customID], migraineKind: kind)
            try auraStore.save(state, date: date, timeZone: zone)
            let result = try auraStore.load(date: date, timeZone: zone)
            precondition(result == state)
            try auraStore.move(from: date, to: yesterday, timeZone: zone)
            let movedState = try auraStore.load(date: yesterday, timeZone: zone)
            precondition(movedState == state)
            try auraStore.move(from: yesterday, to: date, timeZone: zone)
        }
        try auraStore.save(DaySnapshot(hasMigraine: false, triggerIDs: [customID], migraineKind: "withAura"), date: date, timeZone: zone)
        let clearedKind = try auraStore.load(date: date, timeZone: zone)
        precondition(clearedKind.migraineKind == nil && clearedKind.triggerIDs.contains(customID))
        let catalog = TriggerCatalog.all + custom.map(\.definition)
        let reversedIDs = catalog.reversed().map(\.id)
        let preference = TriggerOrder.encode(reversedIDs)
        precondition(TriggerOrder.sorted(catalog, preference: preference).map(\.id) == reversedIDs)
        precondition(TriggerOrder.sorted(catalog, preference: "invalid").map(\.id) == catalog.map(\.id))
        let duplicateOrder = TriggerOrder.encode([customID, customID, "missing"])
        let deduplicated = TriggerOrder.sorted(catalog, preference: duplicateOrder)
        precondition(deduplicated.first?.id == customID && deduplicated.count == catalog.count)
        print("PASS: both aura types persist and move, clearing migraine clears type, trigger order roundtrip and fallback")
        var dual = DaySnapshot(triggerIDs: [customID])
        dual.setMigraine(withAura: true, withoutAura: true)
        precondition(dual.withAura && dual.withoutAura && dual.migraineKind == "both")
        try auraStore.save(dual, date: date, timeZone: zone)
        let dualRead = try auraStore.load(date: date, timeZone: zone)
        precondition(dualRead == dual)
        dual.setMigraine(withAura: false, withoutAura: dual.withoutAura)
        precondition(!dual.withAura && dual.withoutAura && dual.hasMigraine)
        dual.setMigraine(withAura: false, withoutAura: false)
        precondition(!dual.hasMigraine && dual.migraineKind == nil && dual.triggerIDs.contains(customID))
        let archived = TriggerOrder.hiddenIDs(TriggerOrder.encode([customID]))
        precondition(archived.contains(customID))
        let stillRecorded = try auraStore.load(date: date, timeZone: zone)
        precondition(stillRecorded.triggerIDs.contains(customID))
        print("PASS: independent migraine toggles, both types persist, clearing types preserves triggers, hiding leaves history intact")
        var exclusive = DaySnapshot(triggerIDs: [customID], comment: "Keep this comment")
        exclusive.toggleMigraine(aura: false, enabled: true)
        precondition(exclusive.withoutAura && !exclusive.withAura)
        exclusive.toggleMigraine(aura: true, enabled: true)
        precondition(exclusive.withAura && !exclusive.withoutAura)
        try auraStore.save(exclusive, date: date, timeZone: zone)
        let savedExclusive = try auraStore.load(date: date, timeZone: zone)
        precondition(savedExclusive == exclusive)
        var exclusiveEditor = DayEditorState()
        let exclusiveKey = DayEntry.key(for: date, timeZone: zone)
        exclusiveEditor.load(key: exclusiveKey) { try auraStore.loadAll() }
        var replacement = exclusive
        replacement.toggleMigraine(aura: false, enabled: true)
        var failingExclusiveStore = auraStore
        failingExclusiveStore.commit = { _ in throw TestFailure.diskUnavailable }
        exclusiveEditor.save(replacement, key: exclusiveKey) {
            try failingExclusiveStore.save(replacement, date: date, timeZone: zone)
        }
        precondition(exclusiveEditor.snapshot == exclusive)
        let afterFailedSwitch = try auraStore.load(date: date, timeZone: zone)
        precondition(afterFailedSwitch == exclusive)
        exclusive.toggleMigraine(aura: false, enabled: true)
        precondition(exclusive.withoutAura && !exclusive.withAura)
        exclusive.toggleMigraine(aura: false, enabled: false)
        precondition(!exclusive.hasMigraine && exclusive.migraineKind == nil)
        precondition(exclusive.comment == "Keep this comment" && exclusive.triggerIDs == [customID])
        print("PASS: exclusive migraine switches, persistence, failed switch preserves selection and record")
        for emoji in ["🤕", "😵‍💫", "👨‍👩‍👧‍👦", "🇺🇦", "👍🏽", "1️⃣", "❤️"] { precondition(EmojiChoice.isValid(emoji), emoji) }
        for invalid in ["", "A", "1", "🤕😴", "hello"] { precondition(!EmojiChoice.isValid(invalid), invalid) }
        precondition(DaySnapshot(hasMigraine: true, migraineKind: "withAura").migraineEmoji == "😵‍💫")
        precondition(DaySnapshot(hasMigraine: true, migraineKind: "withoutAura").migraineEmoji == "🤕")
        precondition(DaySnapshot(hasMigraine: true, migraineKind: "both").migraineEmoji == "🤕😵‍💫")
        precondition(DaySnapshot(hasMigraine: true).migraineEmoji == "❔")
        print("PASS: compound emoji validation and distinct migraine markers")
        let notesDate = yesterday.addingTimeInterval(-864000)
        let movedNotesDate = notesDate.addingTimeInterval(-86400)
        let longComment = String(repeating: "👨‍👩‍👧‍👦", count: 201)
        let note = DaySnapshot(comment: longComment)
        try auraStore.save(note, date: notesDate, timeZone: zone)
        let savedNote = try auraStore.load(date: notesDate, timeZone: zone)
        precondition(savedNote.comment.count == 200 && !savedNote.isEmpty)
        try auraStore.move(from: notesDate, to: movedNotesDate, timeZone: zone)
        let movedNote = try auraStore.load(date: movedNotesDate, timeZone: zone)
        precondition(movedNote.comment == savedNote.comment)
        var failedNotesStore = auraStore
        failedNotesStore.commit = { _ in throw TestFailure.diskUnavailable }
        var noteEditor = DayEditorState()
        let noteKey = DayEntry.key(for: movedNotesDate, timeZone: zone)
        noteEditor.load(key: noteKey) { try auraStore.loadAll() }
        noteEditor.save(DaySnapshot(comment: "changed"), key: noteKey) {
            try failedNotesStore.save(DaySnapshot(comment: "changed"), date: movedNotesDate, timeZone: zone)
        }
        precondition(noteEditor.snapshot.comment == savedNote.comment)
        try auraStore.save(DaySnapshot(), date: movedNotesDate, timeZone: zone)
        let afterNoteDelete = try auraStore.loadAll()
        precondition(afterNoteDelete[noteKey] == nil)
        print("PASS: comment-only entry, 200 grapheme limit, comment move, failed save rollback, empty comment deletion")
        print("PASS: leap February, weekday alignment, year boundary, calendar markers")
        precondition(TriggerCatalog.all.count == 16 && Set(TriggerCatalog.all.map(\.id)).count == 16)
        print("PASS: disk persistence, repeated update, trigger removal, independent days, empty-record deletion, unique catalog IDs")
    }
}
