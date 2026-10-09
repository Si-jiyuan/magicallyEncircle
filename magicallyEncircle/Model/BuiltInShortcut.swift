//
//  BuiltInShortcut.swift
//  magicallyEncircle
//

import Foundation

/// 用户为内置图案换绑的快捷键。
struct BuiltInShortcut: Codable {
    var keyCode: UInt16
    var modifierFlags: UInt64
    var keyDisplay: String
}

/// 持久化内置图案的快捷键覆盖：内置 id → 自定义快捷键。
final class BuiltInShortcutStore {
    private let key = "magicallyEncircle.builtInShortcuts"

    func load() -> [String: BuiltInShortcut] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: BuiltInShortcut].self, from: data)) ?? [:]
    }

    func save(_ value: [String: BuiltInShortcut]) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
