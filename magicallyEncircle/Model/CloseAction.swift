//
//  CloseAction.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics
import Foundation

/// 「关闭」图案触发时执行的动作，可在通用设置里选择。
enum CloseAction: String, CaseIterable, Identifiable {
    case closeWindow
    case closeWindowSequence
    case closeAllWindows
    case quitApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .closeWindow: return "关闭当前展示窗口（⌘W）"
        case .closeWindowSequence: return "关闭当前窗口（⌥⌘W → ⌘W）"
        case .closeAllWindows: return "关闭其余窗口（⌥⌘W）"
        case .quitApp: return "关闭当前程序（⌘Q）"
        }
    }

    /// 用于展示的快捷键（顺序执行的动作显示完整序列）。
    var shortcut: KeyShortcut {
        switch self {
        case .closeWindow: return Self.commandW
        case .closeWindowSequence: return KeyShortcut(keyCode: 13, flags: [.maskCommand, .maskAlternate], display: "⌥⌘W → ⌘W")
        case .closeAllWindows: return Self.optionCommandW
        case .quitApp: return Self.commandQ
        }
    }

    func perform() {
        switch self {
        case .closeWindowSequence:
            performConditionalSequence()
        default:
            shortcut.send()
        }
    }

    /// 先发 ⌥⌘W，稍等片刻：若该 App 的窗口已全部关闭，就不再补发 ⌘W。
    private func performConditionalSequence() {
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        KeyShortcut.afterModifiersReleased {
            KeyShortcut.postImmediately(Self.optionCommandW)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if WindowCounter.onScreenWindowCount(ofPID: pid) > 0 {
                    KeyShortcut.postImmediately(Self.commandW)
                }
            }
        }
    }

    private static let commandW = KeyShortcut(keyCode: 13, flags: .maskCommand, display: "⌘W")
    private static let optionCommandW = KeyShortcut(keyCode: 13, flags: [.maskCommand, .maskAlternate], display: "⌥⌘W")
    private static let commandQ = KeyShortcut(keyCode: 12, flags: .maskCommand, display: "⌘Q")

    private static let key = "magicallyEncircle.closeAction"

    static var current: CloseAction {
        get { CloseAction(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .closeWindow }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}
