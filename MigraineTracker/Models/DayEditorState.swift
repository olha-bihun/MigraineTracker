struct DayEditorState {
    private(set) var snapshot = DaySnapshot()
    private(set) var records: [String: DaySnapshot] = [:]
    private(set) var isLoaded = false
    private(set) var errorTitle = ""
    var errorMessage: String?

    mutating func load(key: String, read: () throws -> [String: DaySnapshot]) {
        isLoaded = false
        do {
            records = try read()
            snapshot = records[key] ?? DaySnapshot()
            isLoaded = true
            errorMessage = nil
        } catch {
            // Do not display another day's values or stale calendar markers as current data.
            snapshot = DaySnapshot()
            records = [:]
            errorTitle = L10n.text("Не вдалося завантажити запис")
            errorMessage = L10n.text("Дані недоступні. Натисни «Повторити завантаження». Редагування тимчасово вимкнено.")
        }
    }

    mutating func save(_ updated: DaySnapshot, key: String, persist: () throws -> Void) {
        guard isLoaded else { return }
        do {
            try persist()
            snapshot = updated.limited
            records[key] = updated.limited.isEmpty ? nil : updated.limited
            errorMessage = nil
        } catch {
            errorTitle = L10n.text("Не вдалося зберегти запис")
            errorMessage = L10n.text("Останню зміну не збережено. Попередній вибір залишився без змін. Спробуй ще раз.")
        }
    }
}
