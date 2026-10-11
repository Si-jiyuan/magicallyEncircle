//
//  OverlayWindow.swift
//  magicallyEncircle
//

import AppKit

/// 覆盖在某一块屏幕上的透明、无边框、点击穿透窗口。
final class OverlayWindow: NSWindow {
    let targetScreen: NSScreen
    let canvasView: MagicCanvasView

    init(screen: NSScreen) {
        self.targetScreen = screen
        self.canvasView = MagicCanvasView(frame: NSRect(origin: .zero, size: screen.frame.size))
        // 避开顶部菜单栏（高度 = 整屏顶 - 可见区顶）。
        self.canvasView.topInset = max(0, screen.frame.maxY - screen.visibleFrame.maxY)

        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        sharingType = .none
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        animationBehavior = .none
        contentView = canvasView
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
