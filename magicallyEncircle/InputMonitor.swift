//
//  InputMonitor.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics

protocol InputMonitorDelegate: AnyObject {
    func inputMonitor(_ monitor: InputMonitor, didBeginAt point: CGPoint, at time: TimeInterval)
    func inputMonitor(_ monitor: InputMonitor, didMoveTo point: CGPoint, at time: TimeInterval)
    func inputMonitor(_ monitor: InputMonitor, didEndAt point: CGPoint, at time: TimeInterval)
}

/// 使用 CGEventTap 在系统层面监听并「拦截」Option + 鼠标左键事件，
/// 同时在需要绑定时捕获全局按键。
final class InputMonitor {
    weak var delegate: InputMonitorDelegate?
    var isEnabled = true
    var onKeyCaptured: ((UInt16, CGEventFlags) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDrawing = false
    private var isCapturingKeys = false

    @discardableResult
    func start() -> Bool {
        guard eventTap == nil else { return true }

        let mask = CGEventMask(1) << CGEventType.leftMouseDown.rawValue
            | CGEventMask(1) << CGEventType.leftMouseDragged.rawValue
            | CGEventMask(1) << CGEventType.leftMouseUp.rawValue
            | CGEventMask(1) << CGEventType.flagsChanged.rawValue
            | CGEventMask(1) << CGEventType.keyDown.rawValue
            | CGEventMask(1) << CGEventType.keyUp.rawValue

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<InputMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isDrawing = false
        isCapturingKeys = false
    }

    func startKeyCapture() { isCapturingKeys = true }
    func endKeyCapture() { isCapturingKeys = false }

    /// 返回 nil 表示吞掉该事件（不再派发给底层应用）。
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        if isCapturingKeys {
            if type == .keyDown {
                if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
                    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
                    onKeyCaptured?(keyCode, event.flags)
                }
                return nil
            }
            if type == .keyUp {
                return nil
            }
        }

        let modifierHeld = event.flags.contains(.maskAlternate)
        let now = ProcessInfo.processInfo.systemUptime

        switch type {
        case .leftMouseDown:
            if isEnabled && modifierHeld {
                isDrawing = true
                delegate?.inputMonitor(self, didBeginAt: appKitPoint(event.location), at: now)
                return nil
            }
        case .leftMouseDragged:
            if isDrawing {
                delegate?.inputMonitor(self, didMoveTo: appKitPoint(event.location), at: now)
                return nil
            }
        case .leftMouseUp:
            if isDrawing {
                isDrawing = false
                delegate?.inputMonitor(self, didEndAt: appKitPoint(event.location), at: now)
                return nil
            }
        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    /// 把 CoreGraphics 全局坐标（左上角原点）转换成 AppKit 全局坐标（左下角原点）。
    private func appKitPoint(_ cg: CGPoint) -> CGPoint {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        let height = primary?.frame.height ?? 0
        return CGPoint(x: cg.x, y: height - cg.y)
    }
}
