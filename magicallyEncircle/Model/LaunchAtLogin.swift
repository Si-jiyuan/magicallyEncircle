//
//  LaunchAtLogin.swift
//  magicallyEncircle
//

import Foundation
import ServiceManagement

/// 开机自启动（登录项）。macOS 13+ 用 SMAppService。
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// 设置开机自启动，返回是否成功。
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("LaunchAtLogin \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }
}
