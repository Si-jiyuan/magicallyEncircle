//
//  ScreenCaptureService.swift
//  magicallyEncircle
//

import AppKit
import CoreGraphics

/// 屏幕区域截取（需「屏幕录制」权限）。覆盖层已设置 sharingType = .none，
/// 因此不会被截进画面。
enum ScreenCaptureService {
    static func capture(regionInAppKit: CGRect) -> CGImage? {
        let rect = toCGRect(regionInAppKit)
        guard rect.width > 1, rect.height > 1 else { return nil }
        return CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
    }

    /// AppKit 全局坐标（左下原点）→ CoreGraphics 全局坐标（左上原点）。
    static func toCGRect(_ rect: CGRect) -> CGRect {
        let height = primaryHeight()
        return CGRect(x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height)
    }

    static func toCGPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight() - point.y)
    }

    static func primaryHeight() -> CGFloat {
        let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? NSScreen.screens.first
        return primary?.frame.height ?? 0
    }
}
