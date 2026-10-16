import SwiftUI
import SwiftData

@main struct MyApp: App {
    @AppStorage("appLanguage") private var language = L10n.defaultLanguage
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, Locale(identifier: language))
                .id(language)
        }
        .modelContainer(for: [DayEntry.self, CustomTrigger.self])
    }
}
