import Foundation
import SwiftData

@Model
final class CustomTrigger {
    @Attribute(.unique) var id: String
    var name: String
    var emoji: String
    var createdAt: Date

    init(name: String, emoji: String) {
        self.id = "custom_" + UUID().uuidString
        self.name = name
        self.emoji = emoji
        self.createdAt = Date()
    }

    var definition: TriggerDefinition {
        TriggerDefinition(id: id, title: name, group: .custom, sortOrder: 100, customEmoji: emoji)
    }
}
