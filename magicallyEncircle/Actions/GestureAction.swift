//
//  GestureAction.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

/// 一个可发送的系统快捷键。
struct KeyShortcut {
    let keyCode: CGKeyCode
    let flags: CGEventFlags
    let display: String

    /// 发送快捷键。除在按键事件上设置 flags 外，还显式补发修饰键的
    /// flagsChanged 事件——否则 Mission Control 之类的系统级快捷键
    /// 可能只识别到主键、丢掉修饰键。
    func send() {
        // 系统级符号快捷键（Mission Control 等）不响应合成事件，走专用通道。
        if let hotkey = SystemHotkey.match(keyCode: keyCode, flags: flags) {
            SystemHotkey.perform(hotkey) {
                KeyShortcut.postSynthetic(keyCode: keyCode, flags: flags)
            }
        } else {
            KeyShortcut.postSynthetic(keyCode: keyCode, flags: flags)
        }
    }

    static func postSynthetic(keyCode: CGKeyCode, flags: CGEventFlags) {
        DispatchQueue.main.async {
            // 用户是按住 Option 画图的，松手后 Option 可能仍被按住，
            // 会污染合成按键。等物理修饰键都松开再发送。
            whenModifiersReleased {
                post(keyCode: keyCode, flags: flags)
            }
        }
    }

    private static func post(keyCode: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let active = modifierOrder.filter { flags.contains($0.0) }

        var currentFlags: CGEventFlags = []
        for (flag, modifierKey) in active {
            currentFlags.insert(flag)
            postModifier(modifierKey, down: true, flags: currentFlags, source: source)
        }

        // 给系统一点时间真正进入修饰键按下态，再发主键。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
            down?.flags = flags
            up?.flags = flags
            down?.post(tap: .cghidEventTap)
            up?.post(tap: .cghidEventTap)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                var releaseFlags = flags
                for (flag, modifierKey) in active.reversed() {
                    releaseFlags.remove(flag)
                    postModifier(modifierKey, down: false, flags: releaseFlags, source: source)
                }
            }
        }
    }

    private static func whenModifiersReleased(_ action: @escaping () -> Void) {
        let tracked: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let deadline = Date().addingTimeInterval(0.6)

        func attempt() {
            let held = CGEventSource.flagsState(.combinedSessionState).intersection(tracked)
            if held.isEmpty || Date() >= deadline {
                action()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03, execute: attempt)
            }
        }
        attempt()
    }

    private static let modifierOrder: [(CGEventFlags, CGKeyCode)] = [
        (.maskControl, 0x3B),
        (.maskAlternate, 0x3A),
        (.maskShift, 0x38),
        (.maskCommand, 0x37)
    ]

    private static func postModifier(_ keyCode: CGKeyCode, down: Bool, flags: CGEventFlags, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: down) else { return }
        event.type = .flagsChanged
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

/// 内置的手势动作集合（先内置，不做配置界面）。
enum GestureAction: CaseIterable {
    case back
    case forward
    case missionControl
    case appExpose
    case undo
    case copy
    case paste
    case newTab
    case lockScreen
    case showDesktop

    var title: String {
        switch self {
        case .back: return "后退"
        case .forward: return "前进"
        case .missionControl: return "调度中心"
        case .appExpose: return "App 速览"
        case .undo: return "撤销"
        case .copy: return "复制"
        case .paste: return "粘贴"
        case .newTab: return "新建标签页"
        case .lockScreen: return "锁定屏幕"
        case .showDesktop: return "显示桌面"
        }
    }

    var shortcut: KeyShortcut? {
        switch self {
        case .back: return KeyShortcut(keyCode: 33, flags: .maskCommand, display: "⌘[")
        case .forward: return KeyShortcut(keyCode: 30, flags: .maskCommand, display: "⌘]")
        case .missionControl: return KeyShortcut(keyCode: 126, flags: .maskControl, display: "⌃↑")
        case .appExpose: return KeyShortcut(keyCode: 125, flags: .maskControl, display: "⌃↓")
        case .undo: return KeyShortcut(keyCode: 6, flags: .maskCommand, display: "⌘Z")
        case .copy: return KeyShortcut(keyCode: 8, flags: .maskCommand, display: "⌘C")
        case .paste: return KeyShortcut(keyCode: 9, flags: .maskCommand, display: "⌘V")
        case .newTab: return KeyShortcut(keyCode: 17, flags: .maskCommand, display: "⌘T")
        case .lockScreen: return KeyShortcut(keyCode: 12, flags: [.maskControl, .maskCommand], display: "⌃⌘Q")
        case .showDesktop: return KeyShortcut(keyCode: 103, flags: [], display: "F11")
        }
    }

    func perform() {
        shortcut?.send()
    }
}
