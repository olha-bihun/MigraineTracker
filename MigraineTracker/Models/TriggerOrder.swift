import Foundation

enum TriggerOrder {
    static func hiddenIDs(_ preference: String) -> Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: Data(preference.utf8))) ?? [])
    }

    static func sorted(_ triggers: [TriggerDefinition], preference: String) -> [TriggerDefinition] {
        let ids = (try? JSONDecoder().decode([String].self, from: Data(preference.utf8))) ?? []
        var positions: [String: Int] = [:]
        for (index, id) in ids.enumerated() where positions[id] == nil { positions[id] = index }
        return triggers.enumerated().sorted { lhs, rhs in
            let left = positions[lhs.element.id] ?? Int.max
            let right = positions[rhs.element.id] ?? Int.max
            return left == right ? lhs.offset < rhs.offset : left < right
        }.map(\.element)
    }

    static func encode(_ ids: [String]) -> String {
        guard let data = try? JSONEncoder().encode(ids) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }
}
