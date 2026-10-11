//
//  DrawTrigger.swift
//  magicallyEncircle
//

import Foundation

/// 绘制图案的触发方式（互斥）。
enum DrawTrigger: String, CaseIterable, Identifiable {
    case optionLeft
    case middleButton

    var id: String { rawValue }

    var title: String {
        switch self {
        case .optionLeft: return "Option + 鼠标左键"
        case .middleButton: return "鼠标中键"
        }
    }

    private static let key = "magicallyEncircle.drawTrigger"

    static var current: DrawTrigger {
        get { DrawTrigger(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .optionLeft }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

/// 鼠标中键模式下，多笔画「多久无操作后开始识别」。
enum MiddleRecognitionSpeed: String, CaseIterable, Identifiable {
    case fast
    case normal
    case slow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: return "快（0.2 秒）"
        case .normal: return "适中（0.5 秒）"
        case .slow: return "慢（0.75 秒）"
        }
    }

    var delay: TimeInterval {
        switch self {
        case .fast: return 0.2
        case .normal: return 0.5
        case .slow: return 0.75
        }
    }

    private static let key = "magicallyEncircle.middleRecognitionSpeed"

    static var current: MiddleRecognitionSpeed {
        get { MiddleRecognitionSpeed(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .normal }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
