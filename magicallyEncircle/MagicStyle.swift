//
//  MagicStyle.swift
//  magicallyEncircle
//

import AppKit

/// 魔法线条的视觉风格。新增风格只需追加 case 并补全颜色即可，
/// 菜单栏与设置窗口的「视觉风格」会自动列出所有 case。
///
/// `.random` 是特殊模式：每一笔都会随机挑选一种颜色风格（见 `resolved()`）。
enum MagicStyle: String, CaseIterable, Identifiable {
    case whiteOrange
    case whiteBlue
    case whiteGreen
    case whitePurple
    case whitePink
    case random

    var id: String { rawValue }

    private static let key = "magicallyEncircle.visualStyle"

    /// 用户选择的风格（持久化）。
    static var current: MagicStyle {
        get { MagicStyle(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .whiteOrange }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    /// 除「随机」外的具体颜色风格。
    static var concreteStyles: [MagicStyle] {
        allCases.filter { $0 != .random }
    }

    var isRandom: Bool { self == .random }

    /// 把「随机」解析为一个具体风格（每笔调用一次即每笔随机）。
    func resolved() -> MagicStyle {
        guard self == .random else { return self }
        return MagicStyle.concreteStyles.randomElement() ?? .whiteOrange
    }

    var title: String {
        switch self {
        case .whiteOrange: return "白橙发光 · 星尘粒子"
        case .whiteBlue: return "白蓝发光 · 星尘粒子"
        case .whiteGreen: return "白绿发光 · 星尘粒子"
        case .whitePurple: return "白紫发光 · 星尘粒子"
        case .whitePink: return "白粉发光 · 星尘粒子"
        case .random: return "随机风格（每笔随机）"
        }
    }

    /// 线条中心的高亮颜色（统一近白）。
    var coreColor: NSColor {
        NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.92, alpha: 1)
    }

    /// 线条外发光的颜色。
    var glowColor: NSColor {
        switch self {
        case .whiteOrange, .random: return NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.12, alpha: 1)
        case .whiteBlue: return NSColor(calibratedRed: 0.20, green: 0.60, blue: 1.00, alpha: 1)
        case .whiteGreen: return NSColor(calibratedRed: 0.25, green: 0.90, blue: 0.45, alpha: 1)
        case .whitePurple: return NSColor(calibratedRed: 0.62, green: 0.38, blue: 1.00, alpha: 1)
        case .whitePink: return NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.72, alpha: 1)
        }
    }

    /// 粒子可选颜色（星尘）。
    var particleColors: [NSColor] {
        let white = NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1)
        switch self {
        case .whiteOrange, .random:
            return [white,
                    NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.30, alpha: 1),
                    NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.10, alpha: 1)]
        case .whiteBlue:
            return [white,
                    NSColor(calibratedRed: 0.55, green: 0.80, blue: 1.00, alpha: 1),
                    NSColor(calibratedRed: 0.20, green: 0.60, blue: 1.00, alpha: 1)]
        case .whiteGreen:
            return [white,
                    NSColor(calibratedRed: 0.60, green: 1.00, blue: 0.70, alpha: 1),
                    NSColor(calibratedRed: 0.25, green: 0.90, blue: 0.45, alpha: 1)]
        case .whitePurple:
            return [white,
                    NSColor(calibratedRed: 0.80, green: 0.65, blue: 1.00, alpha: 1),
                    NSColor(calibratedRed: 0.62, green: 0.38, blue: 1.00, alpha: 1)]
        case .whitePink:
            return [white,
                    NSColor(calibratedRed: 1.00, green: 0.70, blue: 0.85, alpha: 1),
                    NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.72, alpha: 1)]
        }
    }
}
