//
//  SettingsWindowController.swift
//  magicallyEncircle
//

import AppKit
import Combine
import SwiftUI

/// 菜单窗口（设置）。用 AppKit 管理窗口，内容用 SwiftUI。
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?
    private var cancellables = Set<AnyCancellable>()

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
        let state = SettingsState()
        let hosting = NSHostingView(rootView: SettingsView(controller: MagicController.shared, state: state))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "magicallyEncircle"
        window.titlebarSeparatorStyle = .none
        window.titlebarAppearsTransparent = true
        window.contentView = hosting
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("magicallyEncircle.SettingsWindow")
        window.center()
        self.window = window

        // 标题保持应用名，副标题随左侧栏目动态变化。
        state.$section
            .receive(on: RunLoop.main)
            .sink { [weak window] section in
                window?.subtitle = section.title
            }
            .store(in: &cancellables)
        window.subtitle = state.section.title
    }
}
