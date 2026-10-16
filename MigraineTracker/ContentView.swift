import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CustomTrigger.createdAt) private var customTriggers: [CustomTrigger]
    @FocusState private var commentFocused: Bool
    @State private var commentFrame: CGRect = .zero
    @State private var showingSettings = false
    @AppStorage("hiddenTriggers") private var hiddenTriggers = "[]"
    @AppStorage("triggerOrder") private var triggerOrder = "[]"
    @State private var showYear = false
    @State private var date = Date()
    @State private var timeZone = TimeZone.current
    @State private var editor = DayEditorState()
    @State private var deletedSnapshot: DaySnapshot?
    @State private var showingMove = false
    @State private var destinationDate = Date()
    @State private var moveError: String?

    private var store: DayEntryStore { DayEntryStore(container: modelContext.container) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker(L10n.text("Перегляд календаря"), selection: $showYear) {
                        Text(L10n.text("Місяць")).tag(false)
                        Text(L10n.text("Рік")).tag(true)
                    }.pickerStyle(.segmented)
                    if showYear {
                        YearCalendarView(timeZone: timeZone, records: editor.records, selectedDate: date) { month in
                            date = month
                            showYear = false
                        }.modifier(DiaryCard())
                    } else {
                        MonthCalendarView(selectedDate: $date, timeZone: timeZone, records: editor.records)
                            .modifier(DiaryCard())
                        dayCard
                        if !editor.isLoaded {
                            Button(L10n.text("Повторити завантаження"), action: loadSelectedDay)
                                .buttonStyle(.bordered)
                        }
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.text("Можливі тригери")).font(.headline).accessibilityAddTraits(.isHeader)
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: textSize.isAccessibilitySize ? 3 : 4), spacing: 12) {
                                ForEach(TriggerOrder.sorted(TriggerCatalog.all + customTriggers.map(\.definition), preference: triggerOrder).filter { !TriggerOrder.hiddenIDs(hiddenTriggers).contains($0.id) }) { trigger in
                                    TriggerTile(trigger: trigger, selected: editor.snapshot.triggerIDs.contains(trigger.id)) {
                                        var updated = editor.snapshot
                                        if updated.triggerIDs.contains(trigger.id) { updated.triggerIDs.remove(trigger.id) }
                                        else { updated.triggerIDs.insert(trigger.id) }
                                        save(updated)
                                    }.disabled(!editor.isLoaded)
                                }
                            }
                            Text(L10n.text("Утримуй іконку, щоб побачити опис"))
                                .font(.caption).foregroundStyle(.secondary)
                        }.modifier(DiaryCard())
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("Коментар")).font(.headline)
                            TextField(L10n.text("Додай коментар до цього дня"), text: Binding(
                                get: { editor.snapshot.comment },
                                set: { value in
                                    var updated = editor.snapshot
                                    updated.comment = String(value.prefix(200))
                                    save(updated)
                                }
                            ), axis: .vertical)
                            .focused($commentFocused)
                            .background(GeometryReader { geometry in
                                Color.clear.preference(key: CommentFrameKey.self, value: geometry.frame(in: .global))
                            })
                            .lineLimit(3...6)
                            .disabled(!editor.isLoaded)
                            .accessibilityLabel(L10n.text("Коментар"))
                            Text("\(editor.snapshot.comment.count)/200")
                                .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }.modifier(DiaryCard())
                    }
                }.padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(colorScheme == .dark ? Color(red: 0.10, green: 0.08, blue: 0.14) : Color(red: 0.96, green: 0.94, blue: 0.98))
            .tint(DiaryStyle.lavender)
            .fontDesign(.rounded)
            .navigationTitle(L10n.text("Щоденник мігрені"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button { showingSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(L10n.text("Налаштування"))
            } }
        }
        .onPreferenceChange(CommentFrameKey.self) { commentFrame = $0 }
        .simultaneousGesture(SpatialTapGesture(coordinateSpace: .global).onEnded { tap in
            if commentFocused && !commentFrame.contains(tap.location) {
                commentFocused = false
            }
        })
        .sheet(isPresented: $showingSettings) { SettingsView(hiddenPreference: $hiddenTriggers) }
        .onAppear(perform: loadSelectedDay)
        .onChange(of: date) { _, _ in
            commentFocused = false
            deletedSnapshot = nil
            loadSelectedDay()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadSelectedDay() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            loadSelectedDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            loadSelectedDay()
        }
        .sheet(isPresented: $showingMove) {
            NavigationStack {
                Form {
                    DatePicker(L10n.text("Нова дата"), selection: $destinationDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    if let moveError { Text(moveError).foregroundStyle(.red) }
                    Button(L10n.text("Перенести запис")) { moveRecord() }
                        .disabled(DayEntry.key(for: destinationDate, timeZone: timeZone) == DayEntry.key(for: date, timeZone: timeZone))
                }
                .environment(\.timeZone, timeZone)
                .environment(\.calendar, MonthGrid.calendar(timeZone: timeZone))
                .navigationTitle(L10n.text("Змінити дату"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Скасувати")) { showingMove = false }
                } }
            }
        }
        .alert(editor.errorTitle, isPresented: Binding(
            get: { editor.errorMessage != nil },
            set: { if !$0 { editor.errorMessage = nil } }
        )) {
            Button(L10n.text("Зрозуміло"), role: .cancel) { editor.errorMessage = nil }
        } message: {
            Text(editor.errorMessage ?? "")
        }
    }

    private var dayCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(MonthGrid.label(date, template: "d MMMM yyyy", timeZone: timeZone))
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer()
                if editor.isLoaded && !editor.snapshot.isEmpty {
                    Menu {
                        Button(L10n.text("Змінити дату запису"), systemImage: "calendar") {
                            destinationDate = date
                            moveError = nil
                            showingMove = true
                        }
                        Button(L10n.text("Видалити запис"), systemImage: "trash", role: .destructive) {
                            let previous = editor.snapshot
                            save(DaySnapshot())
                            if editor.errorMessage == nil { deletedSnapshot = previous }
                        }
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }.accessibilityLabel(L10n.text("Дії із записом"))
                }
            }
            Toggle("🤕 " + L10n.text("Мігрень без аури"), isOn: Binding(
                get: { editor.snapshot.withoutAura },
                set: { value in
                    var updated = editor.snapshot
                    updated.toggleMigraine(aura: false, enabled: value)
                    save(updated)
                }
            ))
            .disabled(!editor.isLoaded)
            .modifier(MigraineGlass())
            Toggle("😵‍💫 " + L10n.text("Мігрень з аурою"), isOn: Binding(
                get: { editor.snapshot.withAura },
                set: { value in
                    var updated = editor.snapshot
                    updated.toggleMigraine(aura: true, enabled: value)
                    save(updated)
                }
            ))
            .disabled(!editor.isLoaded)
            .modifier(MigraineGlass())
            if editor.snapshot.hasMigraine && editor.snapshot.migraineKind == nil {
                Text(L10n.text("У цьому старому записі тип мігрені не вказано."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let previous = deletedSnapshot {
                Button(L10n.text("Запис видалено · Скасувати")) { save(previous) }
                    .frame(minHeight: 44)
            }
        }.modifier(DiaryCard())
    }

    private func moveRecord() {
        do {
            try store.move(from: date, to: destinationDate, timeZone: timeZone)
            deletedSnapshot = nil
            showingMove = false
            date = destinationDate
            loadSelectedDay()
        } catch {
            moveError = error.localizedDescription
        }
    }

    private func loadSelectedDay() {
        let store = store
        editor.load(key: DayEntry.key(for: date, timeZone: timeZone)) {
            try store.loadAll()
        }
    }

    private func save(_ updated: DaySnapshot) {
        // Past days are editable; future civil dates are not.
        guard editor.isLoaded, DayEntry.key(for: date, timeZone: timeZone) <= DayEntry.key(for: Date()) else {
            loadSelectedDay()
            return
        }
        let store = store
        editor.save(updated, key: DayEntry.key(for: date, timeZone: timeZone)) {
            try store.save(updated, date: date, timeZone: timeZone)
        }
        if editor.errorMessage == nil { deletedSnapshot = nil }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [DayEntry.self, CustomTrigger.self], inMemory: true)
}

private struct CommentFrameKey: PreferenceKey {
    static let defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}
