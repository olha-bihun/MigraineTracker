import SwiftUI
import SwiftData

struct SettingsView: View {
    @Binding var hiddenPreference: String
    @AppStorage("appLanguage") private var language = L10n.defaultLanguage
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CustomTrigger.createdAt) private var customTriggers: [CustomTrigger]
    @FocusState private var nameFocused: Bool
    @State private var name = ""
    @State private var emoji = "✨"
    @State private var showingEmoji = false
    @State private var failure = false
    private let emojis = ["✨", "🤯", "😴", "🍽️", "💧", "🏃", "🌸", "🌦️", "☀️", "🔊", "🌺", "🍷", "☕️", "🧀", "🥓", "🧂", "🥒", "💊", "✈️", "📱", "💻", "🚬", "🍫", "🧘", "🥶", "🥵", "🤧", "🩸", "🏔️", "🚌", "🧹", "🎧"]
    private var cleanName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool {
        (TriggerCatalog.all.map(\.title) + customTriggers.map(\.name)).contains {
            $0.compare(cleanName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Мова")) {
                    Picker(L10n.text("Мова застосунку"), selection: $language) {
                        Text("Українська").tag("uk")
                        Text("English").tag("en")
                        Text("Русский").tag("ru")
                    }
                }
                Section {
                    NavigationLink(L10n.text("Керування тригерами")) { TriggerOrderView(hiddenPreference: $hiddenPreference) }
                }
                Section(L10n.text("Власні тригери")) {
                    ForEach(customTriggers.filter { !TriggerOrder.hiddenIDs(hiddenPreference).contains($0.id) }) { trigger in
                        HStack { Text(trigger.emoji); Text(trigger.name) }
                    }
                    TextField(L10n.text("Назва тригера"), text: $name)
                        .focused($nameFocused)
                        .keyboardType(.default)
                        .submitLabel(.done)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                        .onTapGesture { nameFocused = true }
                        .onSubmit { nameFocused = false }
                        .onChange(of: name) { _, newValue in name = String(newValue.prefix(80)) }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))]) {
                        ForEach(emojis.contains(emoji) ? emojis : emojis + [emoji], id: \.self) { item in
                            Button { emoji = item } label: {
                                Text(item).font(.title2).frame(width: 44, height: 44)
                                    .background(emoji == item ? DiaryStyle.lavender.opacity(0.2) : .clear, in: Circle())
                                    .overlay(Circle().stroke(emoji == item ? DiaryStyle.lavender : .clear, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(emoji == item ? .isSelected : [])
                        }
                        Button {
                            nameFocused = false
                            showingEmoji = true
                        } label: {
                            Image(systemName: "plus").font(.title2)
                                .frame(width: 44, height: 44)
                                .background(DiaryStyle.lavender.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L10n.text("Власний емоджі"))
                        .background {
                            InlineEmojiKeyboard(isPresented: $showingEmoji, selection: $emoji)
                                .frame(width: 1, height: 1)
                        }
                    }
                    if isDuplicate && !cleanName.isEmpty { Text(L10n.text("Тригер із такою назвою вже існує")).foregroundStyle(.secondary) }
                    Button(L10n.text("Додати тригер")) { addTrigger() }
                        .disabled(cleanName.isEmpty || isDuplicate)
                }
            }
            .navigationTitle(L10n.text("Налаштування"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Готово")) { dismiss() } }
            }
            .alert(L10n.text("Не вдалося додати тригер"), isPresented: $failure) { Button(L10n.text("Зрозуміло"), role: .cancel) {} }
        }

        .tint(DiaryStyle.lavender)
    }

    private func addTrigger() {
        guard !cleanName.isEmpty && !isDuplicate else { return }
        let isolated = ModelContext(context.container)
        isolated.autosaveEnabled = false
        isolated.insert(CustomTrigger(name: cleanName, emoji: emoji))
        do { try isolated.save(); name = ""; nameFocused = false; showingEmoji = false }
        catch { isolated.rollback(); failure = true }
    }
}
