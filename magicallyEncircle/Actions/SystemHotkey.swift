//
//  SystemHotkey.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics
import Darwin

/// 系统级符号快捷键（Mission Control、App 速览、锁定屏幕等）不会响应 App
/// 合成的 CGEvent，需要走专用触发通道。
///
/// `CoreDockSendNotification` 在 macOS 14 由公开框架 HIServices 导出（旧系统
/// 在 CoreDock），因此这里动态查找、多重回退，尽量向前兼容。
enum SystemHotkey {
    case missionControl
    case appExpose
    case showDesktop
    case lockScreen

    /// 判断某个按键组合是否对应已知的系统快捷键。
    static func match(keyCode: CGKeyCode, flags: CGEventFlags) -> SystemHotkey? {
        let modifiers = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        switch (keyCode, modifiers) {
        case (126, .maskControl): return .missionControl
        case (125, .maskControl): return .appExpose
        case (103, []): return .showDesktop
        case (12, [.maskControl, .maskCommand]): return .lockScreen
        default: return nil
        }
    }

    /// 执行系统动作；所有通道都失败时调用 fallback（合成按键）。
    static func perform(_ hotkey: SystemHotkey, fallback: @escaping () -> Void) {
        let handled: Bool
        switch hotkey {
        case .missionControl:
            handled = sendNotification("com.apple.expose.awake") || openMissionControlApp()
        case .appExpose:
            handled = sendNotification("com.apple.expose.front.awake")
        case .showDesktop:
            handled = sendNotification("com.apple.showdesktop.awake")
        case .lockScreen:
            handled = lockScreen()
        }
        if !handled {
            fallback()
        }
    }

    // MARK: - 触发通道

    private typealias CoreDockFunction = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    @discardableResult
    private static func sendNotification(_ notification: String) -> Bool {
        guard let function = coreDockSendFunction else { return false }
        function(notification as CFString, nil)
        return true
    }

    private static let coreDockSendFunction: CoreDockFunction? = {
        // macOS 14+：HIServices；更早：CoreDock。再加一次全局查找作为兜底。
        let paths = [
            "/System/Library/Frameworks/ApplicationServices.framework/Versions/A/Frameworks/HIServices.framework/Versions/A/HIServices",
            "/System/Library/Frameworks/ApplicationServices.framework/Frameworks/HIServices.framework/HIServices",
            "/System/Library/PrivateFrameworks/CoreDock.framework/Versions/A/CoreDock",
            "/System/Library/PrivateFrameworks/CoreDock.framework/CoreDock"
        ]
        for path in paths {
            guard let handle = dlopen(path, RTLD_LAZY),
                  let symbol = dlsym(handle, "CoreDockSendNotification") else { continue }
            return unsafeBitCast(symbol, to: CoreDockFunction.self)
        }
        if let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CoreDockSendNotification") {
            return unsafeBitCast(symbol, to: CoreDockFunction.self)
        }
        return nil
    }()

    @discardableResult
    private static func openMissionControlApp() -> Bool {
        let paths = [
            "/System/Applications/Mission Control.app",
            "/System/Library/CoreServices/Mission Control.app"
        ]
        for path in paths where FileManager.default.fileExists(atPath: path) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
            return true
        }
        return false
    }

    @discardableResult
    private static func lockScreen() -> Bool {
        let paths = [
            "/System/Library/PrivateFrameworks/login.framework/Versions/A/login",
            "/System/Library/PrivateFrameworks/login.framework/login"
        ]
        for path in paths {
            guard let handle = dlopen(path, RTLD_LAZY),
                  let symbol = dlsym(handle, "SACLockScreenImmediate") else { continue }
            typealias Function = @convention(c) () -> Int32
            let function = unsafeBitCast(symbol, to: Function.self)
            _ = function()
            return true
        }
        return false
    }
}
