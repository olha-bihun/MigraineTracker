import Foundation

enum EmojiChoice {
    static func isValid(_ value: String) -> Bool {
        guard value.count == 1 else { return false }
        let scalars = value.unicodeScalars
        return scalars.contains { $0.properties.isEmojiPresentation }
            || (scalars.contains { $0.properties.isEmoji } && scalars.contains { $0.value == 0xFE0F || $0.value == 0x20E3 })
    }
}
