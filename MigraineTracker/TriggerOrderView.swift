import SwiftUI
import SwiftData

struct TriggerOrderView: View {
    @AppStorage("hiddenTriggers") private var hiddenPreference = "[]"
    @AppStorage("triggerOrder") private var preference = "[]"
    @Query(sort: \CustomTrigger.createdAt) private var customTriggers: [CustomTrigger]
    private var allTriggers: [TriggerDefinition] {
        TriggerOrder.sorted(TriggerCatalog.all + customTriggers.map(\.definition), preference: preference)
    }
    private var triggers: [TriggerDefinition] {
        allTriggers.filter { !TriggerOrder.hiddenIDs(hiddenPreference).contains($0.id) }
    }
    private var deleted: [TriggerDefinition] {
        allTriggers.filter { TriggerOrder.hiddenIDs(hiddenPreference).contains($0.id) }
    }
    var body: some View {
        List {
            Section {
                ForEach(triggers) { trigger in
                    HStack { Text(trigger.emoji); Text(trigger.title).fixedSize(horizontal: false, vertical: true) }
                }
                .onDelete { indices in
                    var hidden = TriggerOrder.hiddenIDs(hiddenPreference)
                    for index in indices { hidden.insert(triggers[index].id) }
                    hiddenPreference = TriggerOrder.encode(hidden.sorted())
                }
                .onMove { source, destination in
                    var ordered = triggers
                    ordered.move(fromOffsets: source, toOffset: destination)
                    preference = TriggerOrder.encode(ordered.map(\.id))
                }
            } footer: { Text(L10n.text("Перетягни рядки, щоб змінити порядок іконок у щоденнику.")) }
            if !deleted.isEmpty {
                Section {
                    ForEach(deleted) { trigger in
                        Button {
                            var hidden = TriggerOrder.hiddenIDs(hiddenPreference)
                            hidden.remove(trigger.id)
                            hiddenPreference = TriggerOrder.encode(hidden.sorted())
                        } label: {
                            HStack {
                                Text(trigger.emoji)
                                Text(trigger.title)
                                Spacer()
                                Image(systemName: "arrow.uturn.backward")
                            }
                        }.accessibilityHint(L10n.text("Відновити тригер"))
                    }
                } header: { Text(L10n.text("Видалені тригери")) } footer: { Text(L10n.text("Видалені тригери залишаються у старих записах. Натисни, щоб відновити.")) }
            }
        }
        .environment(\.editMode, .constant(.active))
        .navigationTitle(L10n.text("Керування тригерами"))
    }
}
