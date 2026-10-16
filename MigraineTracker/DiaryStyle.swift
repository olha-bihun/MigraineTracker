import SwiftUI

enum DiaryStyle {
    static let dustyLavender = Color(red: 0.64, green: 0.56, blue: 0.70)
    static let lavender = Color(red: 0.48, green: 0.36, blue: 0.65)
}

struct DiaryCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.padding(16)
            .background(scheme == .dark ? Color(white: 0.14) : Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct MigraineGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        if reduceTransparency {
            content.padding(16).background(.background, in: RoundedRectangle(cornerRadius: 20))
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.padding(16).glassEffect(.regular.tint(DiaryStyle.lavender.opacity(0.12)), in: RoundedRectangle(cornerRadius: 20))
        } else {
            content.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

extension TriggerDefinition {
    var emoji: String {
        if let customEmoji { return customEmoji }
        let icons = ["stress": "🤯", "sleep_disruption": "😴", "skipped_meals": "🍽️",
                     "dehydration": "💧", "physical_overexertion": "🏃", "hormonal_changes": "🌸",
                     "weather_changes": "🌦️", "bright_or_flickering_light": "☀️", "loud_sounds": "🔊",
                     "strong_smells": "🌺", "alcohol": "🍷", "caffeine": "☕️", "aged_cheese": "🧀",
                     "processed_meat": "🥓", "msg_and_sweeteners": "🧂", "pickled_and_fermented_food": "🥒"]
        return icons[id] ?? "✨"
    }
}

struct TriggerTile: View {
    let trigger: TriggerDefinition
    let selected: Bool
    let action: () -> Void
    @State private var showingDescription = false

    var body: some View {
        Button(action: action) {
            TriggerIllustration(trigger: trigger)
                .frame(width: 23, height: 23)
                .foregroundStyle(DiaryStyle.lavender)
                .frame(width: 52, height: 52)
                .background(DiaryStyle.lavender.opacity(selected ? 0.23 : 0.07), in: Circle())
                .overlay(Circle().stroke(DiaryStyle.lavender.opacity(selected ? 1 : 0.18), lineWidth: selected ? 2 : 1))
                .overlay(alignment: .bottomTrailing) {
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14)).foregroundStyle(DiaryStyle.lavender)
                            .background(.background, in: Circle())
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .highPriorityGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in showingDescription = true })
        .popover(isPresented: $showingDescription) {
            VStack(alignment: .leading, spacing: 10) {
                Text(trigger.title).font(.headline).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20).frame(idealWidth: 260)
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel(trigger.title)
        .accessibilityHint(L10n.text("Натисни, щоб змінити вибір. Утримуй, щоб показати опис."))
        .accessibilityValue(selected ? L10n.text("Обрано") : L10n.text("Не обрано"))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityAction(named: L10n.text("Показати опис")) { showingDescription = true }
    }
}

struct TriggerIllustration: View {
    let trigger: TriggerDefinition
    var body: some View {
        Text(trigger.emoji).font(.system(size: 25)).accessibilityHidden(true)
    }
}
