//
//  SettingsWindowController.swift
//  magicallyEncircle
//

import AppKit
import SwiftUI

/// 菜单窗口（设置）。用 AppKit 管理窗口，内容用 SwiftUI。
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if window == nil {
            build()
        }
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func build() {
        let hosting = NSHostingView(rootView: SettingsView(controller: MagicController.shared))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "magicallyEncircle 设置"
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("magicallyEncircle.SettingsWindow")
        window.center()
        self.window = window
    }
}
