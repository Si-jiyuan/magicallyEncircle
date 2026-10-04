//
//  GestureOverrideStore.swift
//  magicallyEncircle
//

import Foundation

/// 用户为内置手势录制的自定义图案（覆盖默认触发）。
/// 结构：内置手势 id → 若干份采样点。
final class GestureOverrideStore {
    private let key = "magicallyEncircle.gestureOverrides"

    func load() -> [String: [[CodablePoint]]] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        return (try? JSONDecoder().decode([String: [[CodablePoint]]].self, from: data)) ?? [:]
    }

    func save(_ overrides: [String: [[CodablePoint]]]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
