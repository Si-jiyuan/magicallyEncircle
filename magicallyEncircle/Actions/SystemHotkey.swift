//
//  SystemHotkey.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics
import Darwin

/// 系统级符号快捷键（Mission Control、切换空间、锁定屏幕等）不会响应 App
/// 合成的普通 CGEvent，需要走专用触发通道。
///
/// - Mission Control / App 速览 / 显示桌面：`CoreDockSendNotification`
///   （macOS 14 由公开框架 HIServices 导出，旧系统在 CoreDock）
/// - 切换空间：合成 Dock 横滑手势事件（type 30 + companion type 29），
///   走 Dock 的手势管线，因此有动画、且窗口可见性由 Dock 正确维护。
///   （直接用 `SLSManagedDisplaySetCurrentSpace` 会没有动画、窗口叠加，故不用）
///
/// 全部动态查找/失败回退，尽量向前兼容。
enum SystemHotkey {
    case missionControl
    case appExpose
    case showDesktop
    case lockScreen
    case switchSpaceLeft
    case switchSpaceRight

    /// 判断某个按键组合是否对应已知的系统快捷键。
    static func match(keyCode: CGKeyCode, flags: CGEventFlags) -> SystemHotkey? {
        let modifiers = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        switch (keyCode, modifiers) {
        case (126, .maskControl): return .missionControl
        case (125, .maskControl): return .appExpose
        case (123, .maskControl): return .switchSpaceLeft
        case (124, .maskControl): return .switchSpaceRight
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
        case .switchSpaceLeft:
            handled = swipeSpace(toRight: false)
        case .switchSpaceRight:
            handled = swipeSpace(toRight: true)
        }
        if !handled {
            fallback()
        }
    }

    // MARK: - CoreDock 通知

    private typealias CoreDockFunction = @convention(c) (CFString, UnsafeMutableRawPointer?) -> Void

    @discardableResult
    private static func sendNotification(_ notification: String) -> Bool {
        guard let function = coreDockSendFunction else { return false }
        function(notification as CFString, nil)
        return true
    }

    private static let coreDockSendFunction: CoreDockFunction? = {
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

    // MARK: - 合成 Dock 滑动来切换空间
    // 事件字段参考开源实现 joshuarli/iss 与 ShiftPlus 的说明。

    private static let eventTypeField = CGEventField(rawValue: 55)!
    private static let gestureHIDTypeField = CGEventField(rawValue: 110)!
    private static let gestureScrollYField = CGEventField(rawValue: 119)!
    private static let gestureSwipeMotionField = CGEventField(rawValue: 123)!
    private static let gestureVelocityXField = CGEventField(rawValue: 129)!
    private static let gestureVelocityYField = CGEventField(rawValue: 130)!
    private static let gesturePhaseField = CGEventField(rawValue: 132)!
    private static let scrollGestureFlagBitsField = CGEventField(rawValue: 135)!
    private static let gestureZoomDeltaXField = CGEventField(rawValue: 139)!

    private static let dockControlEventType: Int64 = 30
    private static let gestureEventType: Int64 = 29
    private static let dockSwipeHIDType: Int64 = 23
    private static let horizontalMotion: Int64 = 1
    private static let phaseBegan: Int64 = 1
    private static let phaseChanged: Int64 = 2
    private static let phaseEnded: Int64 = 4

    @discardableResult
    private static func swipeSpace(toRight: Bool) -> Bool {
        let right = toRight
        guard let begin = makeDockSwipeEvent(phase: phaseBegan, right: right),
              let changed = makeDockSwipeEvent(phase: phaseChanged, right: right),
              let end = makeDockSwipeEvent(phase: phaseEnded, right: right) else {
            return false
        }
        end.setDoubleValueField(gestureVelocityXField, value: (right ? 1.0 : -1.0) * 400.0)
        end.setDoubleValueField(gestureVelocityYField, value: 0)

        postDockPair(begin)
        postDockPair(changed)
        postDockPair(end)
        return true
    }

    private static func makeDockSwipeEvent(phase: Int64, right: Bool) -> CGEvent? {
        guard let event = CGEvent(source: nil) else { return nil }
        event.setIntegerValueField(eventTypeField, value: dockControlEventType)
        event.setIntegerValueField(gestureHIDTypeField, value: dockSwipeHIDType)
        event.setIntegerValueField(gesturePhaseField, value: phase)

        // 方向标志：±FLT_TRUE_MIN（iss 探明必须非零，否则 Dock 静默丢弃）。
        let flagProgress: Float = right ? Float.leastNonzeroMagnitude : -Float.leastNonzeroMagnitude
        event.setIntegerValueField(scrollGestureFlagBitsField, value: Int64(Int32(bitPattern: flagProgress.bitPattern)))

        event.setIntegerValueField(gestureSwipeMotionField, value: horizontalMotion)
        event.setDoubleValueField(gestureScrollYField, value: 0)
        event.setDoubleValueField(gestureZoomDeltaXField, value: Double(Float.leastNonzeroMagnitude))
        return event
    }

    /// 每个 Dock 事件都要配一个 companion 手势事件（type 29）。
    private static func postDockPair(_ dock: CGEvent) {
        let companion = CGEvent(source: nil)
        companion?.setIntegerValueField(eventTypeField, value: gestureEventType)
        dock.post(tap: .cgSessionEventTap)
        companion?.post(tap: .cgSessionEventTap)
    }

    // MARK: - 锁定屏幕 / 打开 Mission Control

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
