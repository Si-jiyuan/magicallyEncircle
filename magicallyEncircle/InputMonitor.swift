//
//  InputMonitor.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics

enum EdgeDirection {
    case left
    case right
}

/// 鼠标拖拽进入的「屏幕边缘识别区间」。
struct EdgeZone {
    let direction: EdgeDirection
    let screen: NSScreen
    /// 识别边界线的全局 x（AppKit 坐标）——用于绘制引导线。
    let boundaryX: CGFloat
}

protocol InputMonitorDelegate: AnyObject {
    func inputMonitor(_ monitor: InputMonitor, didBeginAt point: CGPoint, at time: TimeInterval)
    func inputMonitor(_ monitor: InputMonitor, didMoveTo point: CGPoint, at time: TimeInterval)
    func inputMonitor(_ monitor: InputMonitor, didEndAt point: CGPoint, at time: TimeInterval)
    /// 多笔模式下松开 Option 键（此时才应识别合并后的图案）。
    func inputMonitorDidReleaseModifier(_ monitor: InputMonitor)
}

/// 使用 CGEventTap 在系统层面监听并「拦截」Option + 鼠标左键事件，
/// 同时检测 Option 双击（进入多笔模式）并在需要绑定时捕获全局按键。
final class InputMonitor {
    weak var delegate: InputMonitorDelegate?
    var isEnabled = true
    var onKeyCaptured: ((UInt16, CGEventFlags) -> Void)?
    /// 拖拽开始/跨到某块屏幕（用于显示边缘识别区间的魔法引导线）。
    var onDragScreenChanged: ((NSScreen?) -> Void)?
    /// 在识别区间停留足够久（用于切换该屏桌面）。
    var onEdgeSwitch: ((EdgeZone) -> Void)?
    var isEdgeSwitchEnabled = true

    /// 当前是否处于「双击 Option 触发的多笔模式」。
    private(set) var isMultiStrokeSession = false

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isDrawing = false
    private var isCapturingKeys = false

    private var optionDown = false
    private var optionDownTime: TimeInterval = 0
    private var lastOptionUpTime: TimeInterval = 0
    private var lastOptionWasTap = false

    private let doubleTapInterval: TimeInterval = 0.4
    private let tapMaxDuration: TimeInterval = 0.3

    private var plainDragActive = false
    private var dragDetermined = false
    private var dragIsFileDrag = false
    private var dragInitialChangeCount = -1
    private var lastPasteboardCheck: TimeInterval = 0
    private var currentDragScreen: NSScreen?
    private var currentZone: EdgeZone?
    private var edgeTimer: Timer?
    private var edgeFired = false
    private let edgeDwell: TimeInterval = 0.75
    private let edgeInset: CGFloat = 20

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
        isMultiStrokeSession = false
        plainDragActive = false
        dragDetermined = false
        dragIsFileDrag = false
        clearEdgeZone()
        endDragScreen()
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

        let now = ProcessInfo.processInfo.systemUptime

        if type == .flagsChanged {
            handleModifierChange(event, now: now)
            return Unmanaged.passUnretained(event)
        }

        let modifierHeld = event.flags.contains(.maskAlternate)

        switch type {
        case .leftMouseDown:
            if isEnabled && modifierHeld {
                isDrawing = true
                delegate?.inputMonitor(self, didBeginAt: appKitPoint(event.location), at: now)
                return nil
            }
            // 普通拖拽（未按 Option）：用于「拖到屏幕边缘区间切换桌面」。
            plainDragActive = true
            dragDetermined = false
            dragIsFileDrag = false
            dragInitialChangeCount = NSPasteboard(name: .drag).changeCount
            clearEdgeZone()

        case .leftMouseDragged:
            if isDrawing {
                delegate?.inputMonitor(self, didMoveTo: appKitPoint(event.location), at: now)
                return nil
            }
            if isEnabled, isEdgeSwitchEnabled, plainDragActive {
                let point = appKitPoint(event.location)
                determineDragKindIfNeeded(now: now)
                if dragDetermined, dragIsFileDrag {
                    updateDragScreen(point)
                    updateEdgeDwell(point)
                }
            }

        case .leftMouseUp:
            if isDrawing {
                isDrawing = false
                delegate?.inputMonitor(self, didEndAt: appKitPoint(event.location), at: now)
                return nil
            }
            plainDragActive = false
            dragDetermined = false
            dragIsFileDrag = false
            clearEdgeZone()
            endDragScreen()

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - 边缘识别区间 → 切换该屏桌面

    /// 判断本次拖拽是不是「拖文件」。
    /// 用拖拽板 changeCount 判断：拖窗口不会改变它，只有真正的内容拖拽（拖文件/文字等）才会。
    /// 且仅当拖拽板含文件 URL 时才算「拖文件」（拖文字/拖窗口都不算）。
    private func determineDragKindIfNeeded(now: TimeInterval) {
        guard !dragDetermined else { return }
        guard now - lastPasteboardCheck > 0.04 else { return }
        lastPasteboardCheck = now

        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != dragInitialChangeCount else { return }
        dragDetermined = true
        dragIsFileDrag = pasteboard.types?.contains(.fileURL) ?? false
    }

    private func updateDragScreen(_ point: CGPoint) {
        let screen = screenContaining(point)
        guard screen !== currentDragScreen else { return }
        currentDragScreen = screen
        onDragScreenChanged?(screen)
    }

    private func endDragScreen() {
        guard currentDragScreen != nil else { return }
        currentDragScreen = nil
        onDragScreenChanged?(nil)
    }

    private func updateEdgeDwell(_ point: CGPoint) {
        guard let screen = screenContaining(point), let zone = edgeZone(point, screen) else {
            clearEdgeZone()
            return
        }

        let changed = currentZone == nil
            || currentZone!.direction != zone.direction
            || currentZone!.screen !== zone.screen
        currentZone = zone

        guard changed else { return }
        edgeFired = false
        edgeTimer?.invalidate()

        let timer = Timer(timeInterval: edgeDwell, repeats: false) { [weak self] _ in
            self?.fireEdge()
        }
        RunLoop.main.add(timer, forMode: .common)
        edgeTimer = timer
    }

    private func fireEdge() {
        guard !edgeFired, let zone = currentZone else { return }
        edgeFired = true
        edgeTimer = nil
        onEdgeSwitch?(zone)
    }

    private func clearEdgeZone() {
        edgeTimer?.invalidate()
        edgeTimer = nil
        edgeFired = false
        currentZone = nil
    }

    private func screenContaining(_ point: CGPoint) -> NSScreen? {
        // 用「包含边界」判断，否则鼠标到屏幕最右侧（x == maxX）会找不到屏幕。
        NSScreen.screens.first { screen in
            let frame = screen.frame
            return point.x >= frame.minX && point.x <= frame.maxX
                && point.y >= frame.minY && point.y <= frame.maxY
        }
    }

    private func edgeZone(_ point: CGPoint, _ screen: NSScreen) -> EdgeZone? {
        let frame = screen.frame
        if point.x <= frame.minX + edgeInset {
            return EdgeZone(direction: .left, screen: screen, boundaryX: frame.minX + edgeInset)
        }
        if point.x >= frame.maxX - edgeInset {
            return EdgeZone(direction: .right, screen: screen, boundaryX: frame.maxX - edgeInset)
        }
        return nil
    }

    /// 检测 Option 的单击 / 双击，双击进入多笔模式。
    private func handleModifierChange(_ event: CGEvent, now: TimeInterval) {
        let optionNow = event.flags.contains(.maskAlternate)

        if optionNow, !optionDown {
            optionDown = true
            optionDownTime = now
            switch MultiStrokeMode.current {
            case .doublePress:
                let isDoubleTap = lastOptionWasTap && (now - lastOptionUpTime) < doubleTapInterval
                isMultiStrokeSession = isDoubleTap
            case .singlePress:
                isMultiStrokeSession = true
            }
        } else if !optionNow, optionDown {
            optionDown = false
            lastOptionWasTap = (now - optionDownTime) < tapMaxDuration
            lastOptionUpTime = now
            if isMultiStrokeSession {
                isMultiStrokeSession = false
                delegate?.inputMonitorDidReleaseModifier(self)
            }
        }
    }

    /// 把 CoreGraphics 全局坐标（左上角原点）转换成 AppKit 全局坐标（左下角原点）。
    private func appKitPoint(_ cg: CGPoint) -> CGPoint {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        let height = primary?.frame.height ?? 0
        return CGPoint(x: cg.x, y: height - cg.y)
    }
}
