//
//  ShareMenuPresenter.swift
//  magicallyEncircle
//

import AppKit

/// 「共享」图案：取出 Finder 中选中的文件，弹出系统共享服务菜单
/// （等同于右键 →「共享」，如隔空投送、信息、邮件等）。
///
/// 需要「自动化」权限（首次使用会提示允许控制 Finder）。
final class ShareMenuPresenter: NSObject {
    static let shared = ShareMenuPresenter()

    private struct Pending {
        let service: NSSharingService
        let urls: [URL]
    }

    func shareSelectedFiles() {
        let (urls, error) = Self.finderSelection()

        if let error {
            let code = (error["NSAppleScriptErrorNumber"] as? Int) ?? 0
            switch code {
            case -1743: // errAEEventNotPermitted
                Self.notify("需要「自动化」权限", "系统设置 → 隐私与安全性 → 自动化 → 勾选 Finder")
            case -600, -609: // Finder 未运行
                Self.notify("请先打开 Finder", nil)
            default:
                Self.notify("无法读取 Finder 选择", (error["NSAppleScriptErrorMessage"] as? String) ?? "错误码 \(code)")
            }
            return
        }

        guard !urls.isEmpty else {
            Self.notify("未找到选中的文件", "请先在 Finder 中选中要共享的文件")
            return
        }

        let services = NSSharingService.sharingServices(forItems: urls)
        guard !services.isEmpty else {
            Self.notify("没有可用的共享方式", nil)
            return
        }

        let menu = NSMenu()
        for service in services {
            let item = NSMenuItem(title: service.title, action: #selector(invoke(_:)), keyEquivalent: "")
            item.target = self
            item.image = service.image
            item.representedObject = Pending(service: service, urls: urls)
            menu.addItem(item)
        }

        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    @objc private func invoke(_ sender: NSMenuItem) {
        guard let pending = sender.representedObject as? Pending else { return }
        pending.service.perform(withItems: pending.urls)
    }

    // MARK: - 取 Finder 选中文件

    private static func finderSelection() -> ([URL], NSDictionary?) {
        let source = """
        tell application "Finder"
            set theSelection to selection
            set thePaths to {}
            repeat with anItem in theSelection
                set end of thePaths to POSIX path of (anItem as alias)
            end repeat
            return thePaths
        end tell
        """
        guard let script = NSAppleScript(source: source) else { return ([], nil) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error { return ([], error) }

        var urls: [URL] = []
        let count = result.numberOfItems
        if count > 0 {
            for index in 1...count {
                if let path = result.atIndex(index)?.stringValue, !path.isEmpty {
                    urls.append(URL(fileURLWithPath: path))
                }
            }
        }
        return (urls, nil)
    }

    private static func notify(_ title: String, _ detail: String?) {
        RecognitionHUD.shared.show(title: title, detail: detail ?? "")
    }
}
