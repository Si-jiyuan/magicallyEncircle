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
        menu.addItem(helpMenuItem())
        menu.addItem(.separator())
        menu.addItem(recordMenuItem())
        if !controller.customGestures.isEmpty {
            menu.addItem(customGesturesMenuItem())
        }
        menu.addItem(.separator())
        menu.addItem(actionItem("导出自定义图案…", #selector(exportGestures)))
        menu.addItem(actionItem("导入自定义图案…", #selector(importGestures)))
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

    private func helpMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "手势说明", action: nil, keyEquivalent: "")
        let submenu = makeMenu()
        let lines = [
            "← / →   后退 / 前进",
            "↑ / ↓   调度中心 / App 速览",
            "Z 撤销   C 复制   V 粘贴",
            "N 新建标签页   L 锁定屏幕",
            "○ 闭环快松 → 复制圈内文本",
            "○ 闭环按住 2 秒 → 截图圈选区域"
        ]
        for line in lines {
            let entry = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            entry.isEnabled = false
            submenu.addItem(entry)
        }
        item.submenu = submenu
        return item
    }

    private func recordMenuItem() -> NSMenuItem {
        if controller.isRecordingGesture {
            return actionItem("取消记录手势", #selector(cancelRecording))
        }
        return actionItem("记录新手势", #selector(startRecording))
    }

    private func customGesturesMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "自定义手势", action: nil, keyEquivalent: "")
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

        if controller.pendingBindingID == gesture.id {
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
    @objc private func cancelRecording() { controller.cancelRecordingGesture() }
    @objc private func exportGestures() { controller.exportGestures() }
    @objc private func importGestures() { controller.importGestures() }
    @objc private func cancelBinding() { controller.cancelPendingBinding() }
    @objc private func quit() { NSApp.terminate(nil) }

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
