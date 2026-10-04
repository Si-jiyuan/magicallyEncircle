//
//  BuiltInGesture.swift
//  magicallyEncircle
//

import CoreGraphics

enum SwipeDirection {
    case left, right, up, down
}

/// 内置手势动作：把「默认触发方式（滑动或图案）」和「动作」绑定起来。
/// 用户可以在菜单里重新录制图案来覆盖默认触发；`defaultTemplates` 为空且
/// `defaultSwipe` 为 nil 的动作（如「显示桌面」）需要用户自行录制。
struct BuiltInGesture: Identifiable {
    let id: String
    let title: String
    let action: GestureAction
    let defaultSwipe: SwipeDirection?
    let defaultTemplates: [GestureTemplate]

    static let all: [BuiltInGesture] = [
        BuiltInGesture(id: "back", title: "后退", action: .back, defaultSwipe: .left, defaultTemplates: []),
        BuiltInGesture(id: "forward", title: "前进", action: .forward, defaultSwipe: .right, defaultTemplates: []),
        BuiltInGesture(id: "missionControl", title: "调度中心", action: .missionControl, defaultSwipe: .up, defaultTemplates: []),
        BuiltInGesture(id: "appExpose", title: "App 速览", action: .appExpose, defaultSwipe: .down, defaultTemplates: []),
        BuiltInGesture(id: "undo", title: "撤销", action: .undo, defaultSwipe: nil, defaultTemplates: GestureTemplate.templates(for: .undo)),
        BuiltInGesture(id: "copy", title: "复制", action: .copy, defaultSwipe: nil, defaultTemplates: GestureTemplate.templates(for: .copy)),
        BuiltInGesture(id: "paste", title: "粘贴", action: .paste, defaultSwipe: nil, defaultTemplates: GestureTemplate.templates(for: .paste)),
        BuiltInGesture(id: "newTab", title: "新建标签页", action: .newTab, defaultSwipe: nil, defaultTemplates: GestureTemplate.templates(for: .newTab)),
        BuiltInGesture(id: "lockScreen", title: "锁定屏幕", action: .lockScreen, defaultSwipe: nil, defaultTemplates: GestureTemplate.templates(for: .lockScreen)),
        BuiltInGesture(id: "showDesktop", title: "显示桌面", action: .showDesktop, defaultSwipe: nil, defaultTemplates: [])
    ]

    static func find(_ id: String) -> BuiltInGesture? {
        all.first { $0.id == id }
    }
}
