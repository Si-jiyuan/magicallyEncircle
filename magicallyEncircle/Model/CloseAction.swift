//
//  CloseAction.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

/// 「关闭」图案触发时执行的动作，可在通用设置里选择。
enum CloseAction: String, CaseIterable, Identifiable {
    case closeWindow
    case closeAllWindows
    case quitApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .closeWindow: return "关闭当前窗口（⌘W）"
        case .closeAllWindows: return "关闭其余窗口（⌥⌘W）"
        case .quitApp: return "关闭当前程序（⌘Q）"
        }
    }

    var shortcut: KeyShortcut {
        switch self {
        case .closeWindow: return KeyShortcut(keyCode: 13, flags: .maskCommand, display: "⌘W")
        case .closeAllWindows: return KeyShortcut(keyCode: 13, flags: [.maskCommand, .maskAlternate], display: "⌥⌘W")
        case .quitApp: return KeyShortcut(keyCode: 12, flags: .maskCommand, display: "⌘Q")
        }
    }

    private static let key = "magicallyEncircle.closeAction"

    static var current: CloseAction {
        get { CloseAction(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .closeWindow }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
