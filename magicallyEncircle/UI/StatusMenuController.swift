//
//  StatusMenuController.swift
//  magicallyEncircle
//

import AppKit
import Combine

/// 原生菜单栏菜单：支持图案缩略图、重命名、快捷键绑定与动态「保存」按钮。
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let controller: MagicController
    private let statusItem: NSStatusItem
    private var cancellables = Set<AnyCancellable>()

    init(controller: MagicController) {
        self.controller = controller
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = makeMenu()
        menu.delegate = self
        statusItem.menu = menu

        controller.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = controller.isEnabled ? "sparkles" : "circle.slash"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "magicallyEncircle")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "magicallyEncircle"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        return menu
    }

    // MARK: - 菜单构建

    func menuNeedsUpdate(_ menu: NSMenu) {
        updateIcon()
        menu.removeAllItems()

        menu.addItem(actionItem(controller.isEnabled ? "停用魔法线条" : "启用魔法线条", #selector(toggleEnabled)))
        menu.addItem(.separator())
        menu.addItem(styleMenuItem())
        menu.addItem(actionItem(controller.showRecognitionHUD ? "隐藏识别反馈" : "显示识别反馈", #selector(toggleHUD)))
        menu.addItem(builtInGesturesMenuItem())
        menu.addItem(.separator())
        menu.addItem(recordMenuItem())
        if !controller.customGestures.isEmpty {
            menu.addItem(customGesturesMenuItem())
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("导出自定义图案…", #selector(exportGestures)))
        menu.addItem(actionItem("导入自定义图案…", #selector(importGestures)))
        menu.addItem(.separator())
        menu.addItem(actionItem("设置…", #selector(openSettings)))
        menu.addItem(actionItem("检查更新…", #selector(checkUpdates)))
        menu.addItem(.separator())
        let quit = actionItem("退出", #selector(quit), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func actionItem(_ title: String, _ selector: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func styleMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "视觉风格", action: nil, keyEquivalent: "")
        let submenu = makeMenu()
        for style in MagicStyle.allCases {
            let entry = actionItem(style.title, #selector(selectStyle))
            entry.representedObject = style.rawValue
            entry.state = controller.style == style ? .on : .off
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private func builtInGesturesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "内置图案", action: nil, keyEquivalent: "")
        let submenu = makeMenu()
        for builtIn in BuiltInGesture.all {
            submenu.addItem(builtInItem(builtIn))
        }
        submenu.addItem(.separator())

        let note = NSMenuItem(title: "○ 闭环快松=复制文本 / 按住1秒=截图（不可改）", action: nil, keyEquivalent: "")
        note.isEnabled = false
        submenu.addItem(note)

        submenu.addItem(actionItem("全部恢复默认图案", #selector(resetAllBuiltIns)))
        item.submenu = submenu
        return item
    }

    private func builtInItem(_ builtIn: BuiltInGesture) -> NSMenuItem {
        let item = NSMenuItem(title: "\(builtIn.title)（\(builtInDescription(builtIn))）", action: nil, keyEquivalent: "")
        let submenu = makeMenu()

        let record = actionItem("录制图案…", #selector(recordBuiltIn))
        record.representedObject = builtIn.id
        submenu.addItem(record)

        if builtIn.action.isShortcutRebindable {
            if controller.pendingBindingTarget == .builtIn(builtIn.id) {
                let display = controller.pendingKeyDisplay
                let status = NSMenuItem(
                    title: display.map { "已捕获 \($0)，点击保存" } ?? "等待按键…",
                    action: nil,
                    keyEquivalent: ""
                )
                status.isEnabled = false
                submenu.addItem(status)
                if display != nil {
                    submenu.addItem(actionItem("保存绑定", #selector(commitBinding)))
                }
                submenu.addItem(actionItem("取消绑定", #selector(cancelBinding)))
            } else {
                let bind = actionItem("设置快捷键…", #selector(beginBuiltInBinding))
                bind.representedObject = builtIn.id
                submenu.addItem(bind)
            }
        }

        let reset = actionItem("恢复默认", #selector(resetBuiltIn))
        reset.representedObject = builtIn.id
        reset.isEnabled = controller.overrideCount(builtIn.id) > 0 || controller.hasBuiltInShortcutOverride(builtIn.id)
        submenu.addItem(reset)

        item.submenu = submenu
        return item
    }

    private func builtInDescription(_ builtIn: BuiltInGesture) -> String {
        let count = controller.overrideCount(builtIn.id)
        let trigger: String
        if count > 0 {
            trigger = "自定义 \(count) 份"
        } else if let swipe = builtIn.defaultSwipe {
            trigger = swipeSymbol(swipe) + " 滑动"
        } else if !builtIn.defaultSamples.isEmpty {
            trigger = "默认图案"
        } else {
            trigger = "未设置"
        }
        let shortcut = controller.effectiveShortcutDisplay(forID: builtIn.id)
        if !shortcut.isEmpty {
            return "\(shortcut) · \(trigger)"
        }
        return trigger
    }

    private func swipeSymbol(_ direction: SwipeDirection) -> String {
        switch direction {
        case .left: return "←"
        case .right: return "→"
        case .up: return "↑"
        case .down: return "↓"
        }
    }

    private func recordMenuItem() -> NSMenuItem {
        if controller.isRecordingGesture || controller.recordingBuiltInID != nil {
            return actionItem("取消记录", #selector(cancelRecording))
        }
        return actionItem("记录新图案", #selector(startRecording))
    }

    private func customGesturesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "自定义图案", action: nil, keyEquivalent: "")
        let submenu = makeMenu()
        for gesture in controller.customGestures {
            submenu.addItem(customGestureItem(gesture))
        }
        item.submenu = submenu
        return item
    }

    private func customGestureItem(_ gesture: CustomGesture) -> NSMenuItem {
        let item = NSMenuItem(title: gesture.menuTitle, action: nil, keyEquivalent: "")
        item.image = controller.previewImage(for: gesture)

        let submenu = makeMenu()

        let rename = actionItem("重命名…", #selector(renameGesture))
        rename.representedObject = gesture.id
        submenu.addItem(rename)

        if controller.pendingBindingTarget == .custom(gesture.id) {
            let display = controller.pendingKeyDisplay
            let status = NSMenuItem(
                title: display.map { "已捕获 \($0)，点击保存" } ?? "等待按键…",
                action: nil,
                keyEquivalent: ""
            )
            status.isEnabled = false
            submenu.addItem(status)

            if display != nil {
                submenu.addItem(actionItem("保存绑定", #selector(commitBinding)))
            }
            submenu.addItem(actionItem("取消绑定", #selector(cancelBinding)))
        } else {
            let title = gesture.keyCode == nil ? "绑定快捷键…" : "重新绑定快捷键…"
            let bind = actionItem(title, #selector(beginBinding))
            bind.representedObject = gesture.id
            submenu.addItem(bind)
        }

        submenu.addItem(.separator())

        let delete = actionItem("删除", #selector(deleteGesture))
        delete.representedObject = gesture.id
        submenu.addItem(delete)

        item.submenu = submenu
        return item
    }

    // MARK: - 动作

    @objc private func toggleEnabled() { controller.toggleEnabled() }
    @objc private func toggleHUD() { controller.toggleHUD() }
    @objc private func startRecording() { controller.beginRecordingGesture() }
    @objc private func cancelRecording() {
        controller.cancelRecordingGesture()
        controller.cancelRecordingBuiltInOverride()
    }
    @objc private func exportGestures() { controller.exportGestures() }
    @objc private func importGestures() { controller.importGestures() }

    @objc private func recordBuiltIn(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controller.beginRecordingBuiltInOverride(id)
    }

    @objc private func resetBuiltIn(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controller.resetBuiltIn(id)
    }

    @objc private func beginBuiltInBinding(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        controller.beginBuiltInKeyBinding(id)
    }

    @objc private func resetAllBuiltIns() {
        controller.resetAllBuiltInOverrides()
    }
    @objc private func cancelBinding() { controller.cancelPendingBinding() }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func openSettings() { SettingsWindowController.shared.show() }
    @objc private func checkUpdates() { controller.checkForUpdates() }

    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = MagicStyle(rawValue: raw) else { return }
        controller.selectStyle(style)
    }

    @objc private func renameGesture(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.renameGesture(id)
    }

    @objc private func beginBinding(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.beginKeyBinding(for: id)
    }

    @objc private func commitBinding() { controller.commitPendingBinding() }

    @objc private func deleteGesture(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        controller.deleteGesture(id)
    }
}
