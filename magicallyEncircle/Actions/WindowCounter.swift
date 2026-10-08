//
//  WindowCounter.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics

/// 统计某个 App 当前屏幕上的普通窗口数量，用于判断窗口是否已被关闭。
enum WindowCounter {
    static func onScreenWindowCount(ofPID pid: pid_t? = nil) -> Int {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        let targetPID = pid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier

        var count = 0
        for window in list {
            // 只统计普通窗口（layer 0），排除菜单栏/覆盖层等。
            guard ((window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0) == 0 else { continue }
            guard let ownerPID = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value else { continue }
            if let targetPID, ownerPID != targetPID { continue }
            count += 1
        }
        return count
    }
}
