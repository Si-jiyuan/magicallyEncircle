//
//  UpdateChecker.swift
//  magicallyEncircle
//

import AppKit
import Foundation

/// 版本信息（来自仓库里的 version.json，走 raw.githubusercontent.com，不受 API 限流）。
struct AppVersionInfo: Decodable {
    let version: String
    let url: String
    let notes: String?
}

/// 检查更新：拉取静态 version.json，与当前版本比较；有新版本则提示前往下载。
final class UpdateChecker {
    static let shared = UpdateChecker()

    private let feedURL = URL(string: "https://raw.githubusercontent.com/Si-jiyuan/magicallyEncircle/main/version.json")!

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    func check(manual: Bool) {
        var request = URLRequest(url: feedURL)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("magicallyEncircle", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                guard let data, let info = try? JSONDecoder().decode(AppVersionInfo.self, from: data) else {
                    if manual { self.showInfo("检查更新失败", "无法获取版本信息，请稍后再试。") }
                    return
                }
                if info.version.compare(self.currentVersion, options: .numeric) == .orderedDescending {
                    self.promptUpdate(info)
                } else if manual {
                    self.showInfo("已是最新版本", "当前版本 \(self.currentVersion)。")
                }
            }
        }.resume()
    }

    private func promptUpdate(_ info: AppVersionInfo) {
        let alert = NSAlert()
        alert.messageText = "发现新版本 \(info.version)"
        alert.informativeText = (info.notes?.isEmpty == false)
            ? (info.notes ?? "")
            : "当前版本 \(currentVersion)，是否前往下载？"
        alert.addButton(withTitle: "前往下载")
        alert.addButton(withTitle: "稍后")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, let url = URL(string: info.url) {
            NSWorkspace.shared.open(url)
        }
    }

    private func showInfo(_ title: String, _ text: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - 启动时自动检查

    private static let autoKey = "magicallyEncircle.autoCheckUpdates"

    static var autoCheckEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: autoKey) as? Bool) ?? true }
        set { UserDefaults.standard.set(newValue, forKey: autoKey) }
    }
}
