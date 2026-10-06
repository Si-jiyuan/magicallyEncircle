//
//  MultiStrokeMode.swift
//  magicallyEncircle
//

import Foundation

/// 多笔画的触发方式（互斥）。
enum MultiStrokeMode: String, CaseIterable, Identifiable {
    /// 单击 Option 不松开 → 多笔画（替换原本单笔画逻辑）。
    case singlePress
    /// 双击 Option 不松开 → 多笔画；单击仍是单笔画。
    case doublePress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .singlePress: return "单击 Option（不松开）"
        case .doublePress: return "双击 Option（不松开）"
        }
    }

    private static let key = "magicallyEncircle.multiStrokeMode"

    static var current: MultiStrokeMode {
        get { MultiStrokeMode(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .doublePress }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
