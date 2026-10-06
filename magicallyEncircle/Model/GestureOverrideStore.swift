//
//  GestureOverrideStore.swift
//  magicallyEncircle
//

import Foundation

/// 用户为内置图案录制的自定义图案（覆盖默认触发）。
/// 结构：内置图案 id → 若干份样本，每份样本由若干笔画组成。
final class GestureOverrideStore {
    private let key = "magicallyEncircle.gestureOverrides"

    func load() -> [String: [[[CodablePoint]]]] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [:] }
        // 新格式：样本含多笔画。
        if let current = try? JSONDecoder().decode([String: [[[CodablePoint]]]].self, from: data) {
            return current
        }
        // 旧格式：样本是单笔画，迁移为多笔画。
        if let legacy = try? JSONDecoder().decode([String: [[CodablePoint]]].self, from: data) {
            return legacy.mapValues { samples in samples.map { [$0] } }
        }
        return [:]
    }

    func save(_ overrides: [String: [[[CodablePoint]]]]) {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
