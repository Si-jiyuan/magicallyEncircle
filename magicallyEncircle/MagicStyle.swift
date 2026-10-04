//
//  MagicStyle.swift
//  magicallyEncircle
//

import AppKit

/// 魔法线条的视觉风格。后续新增风格只需在此追加 case 并补全颜色即可，
/// 菜单栏的「视觉风格」子菜单会自动列出所有 case。
enum MagicStyle: String, CaseIterable, Identifiable {
    case whiteOrange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whiteOrange: return "白橙发光 · 星尘粒子"
        }
    }

    /// 线条中心的高亮颜色。
    var coreColor: NSColor {
        switch self {
        case .whiteOrange: return NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.92, alpha: 1)
        }
    }

    /// 线条外发光的颜色。
    var glowColor: NSColor {
        switch self {
        case .whiteOrange: return NSColor(calibratedRed: 1.00, green: 0.55, blue: 0.12, alpha: 1)
        }
    }

    /// 粒子可选颜色。
    var particleColors: [NSColor] {
        switch self {
        case .whiteOrange:
            return [
                NSColor(calibratedRed: 1.00, green: 1.00, blue: 1.00, alpha: 1),
                NSColor(calibratedRed: 1.00, green: 0.76, blue: 0.30, alpha: 1),
                NSColor(calibratedRed: 1.00, green: 0.50, blue: 0.10, alpha: 1)
            ]
        }
    }
}
