enum TriggerGroup: String, CaseIterable, Identifiable {
    case routine
    case environment
    case foodAndDrinks
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: L10n.text("Стан і режим")
        case .environment: L10n.text("Оточення")
        case .foodAndDrinks: L10n.text("Їжа та напої")
        case .custom: L10n.text("Власні тригери")
        }
    }
}

struct TriggerDefinition: Identifiable {
    let id: String
    let title: String
    let group: TriggerGroup
    let sortOrder: Int
    var customEmoji: String? = nil
}

enum TriggerCatalog {
    // Persist these IDs, never the display names. Keep IDs stable when renaming labels.
    static var all: [TriggerDefinition] { [
        .init(id: "stress", title: L10n.text("Стрес та емоційне напруження"), group: .routine, sortOrder: 0),
        .init(id: "sleep_disruption", title: L10n.text("Порушення сну (недосипання або надмірний сон)"), group: .routine, sortOrder: 1),
        .init(id: "skipped_meals", title: L10n.text("Пропуск прийомів їжі"), group: .routine, sortOrder: 2),
        .init(id: "dehydration", title: L10n.text("Зневоднення"), group: .routine, sortOrder: 3),
        .init(id: "physical_overexertion", title: L10n.text("Фізичне перевантаження"), group: .routine, sortOrder: 4),
        .init(id: "hormonal_changes", title: L10n.text("Гормональні коливання (менструація, овуляція)"), group: .routine, sortOrder: 5),
        .init(id: "weather_changes", title: L10n.text("Зміна погоди чи атмосферного тиску"), group: .environment, sortOrder: 6),
        .init(id: "bright_or_flickering_light", title: L10n.text("Яскраве або мерехтливе світло"), group: .environment, sortOrder: 7),
        .init(id: "loud_sounds", title: L10n.text("Гучні звуки"), group: .environment, sortOrder: 8),
        .init(id: "strong_smells", title: L10n.text("Різкі запахи"), group: .environment, sortOrder: 9),
        .init(id: "alcohol", title: L10n.text("Алкоголь (особливо червоне вино та пиво)"), group: .foodAndDrinks, sortOrder: 10),
        .init(id: "caffeine", title: L10n.text("Кофеїн (надлишок або синдром відміни)"), group: .foodAndDrinks, sortOrder: 11),
        .init(id: "aged_cheese", title: L10n.text("Витримані сири"), group: .foodAndDrinks, sortOrder: 12),
        .init(id: "processed_meat", title: L10n.text("Перероблене м’ясо (ковбаси, сосиски)"), group: .foodAndDrinks, sortOrder: 13),
        .init(id: "msg_and_sweeteners", title: L10n.text("Глутамат натрію та штучні підсолоджувачі"), group: .foodAndDrinks, sortOrder: 14),
        .init(id: "pickled_and_fermented_food", title: L10n.text("Мариновані та ферментовані продукти"), group: .foodAndDrinks, sortOrder: 15),
    ] }
}
