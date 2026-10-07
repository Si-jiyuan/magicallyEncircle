//
//  BuiltInGesture.swift
//  magicallyEncircle
//

import CoreGraphics

enum SwipeDirection {
    case left, right, up, down
}

/// 内置图案：把「默认触发方式（滑动或图案）」和「动作」绑定起来。
/// 图案用多笔画样本表示（单笔画就是只含一个元素的数组）。
/// 用户可以录制自定义图案来覆盖默认触发；`defaultSamples` 为空且
/// `defaultSwipe` 为 nil 的动作需要用户自行录制。
struct BuiltInGesture: Identifiable {
    let id: String
    let title: String
    let action: GestureAction
    let defaultSwipe: SwipeDirection?
    let defaultSamples: [[[CGPoint]]]

    static let all: [BuiltInGesture] = [
        BuiltInGesture(id: "back", title: "后退", action: .back, defaultSwipe: .left, defaultSamples: []),
        BuiltInGesture(id: "forward", title: "前进", action: .forward, defaultSwipe: .right, defaultSamples: []),
        BuiltInGesture(id: "missionControl", title: "调度中心", action: .missionControl, defaultSwipe: .up, defaultSamples: []),
        BuiltInGesture(id: "appExpose", title: "App 速览", action: .appExpose, defaultSwipe: .down, defaultSamples: []),
        BuiltInGesture(id: "undo", title: "撤销", action: .undo, defaultSwipe: nil, defaultSamples: samples(for: .undo)),
        BuiltInGesture(id: "copy", title: "复制", action: .copy, defaultSwipe: nil, defaultSamples: samples(for: .copy)),
        BuiltInGesture(id: "paste", title: "粘贴", action: .paste, defaultSwipe: nil, defaultSamples: samples(for: .paste)),
        BuiltInGesture(id: "newTab", title: "新建标签页", action: .newTab, defaultSwipe: nil, defaultSamples: samples(for: .newTab)),
        BuiltInGesture(id: "lockScreen", title: "锁定屏幕", action: .lockScreen, defaultSwipe: nil, defaultSamples: samples(for: .lockScreen)),
        BuiltInGesture(id: "close", title: "关闭", action: .close, defaultSwipe: nil, defaultSamples: [closeUserDrawn, closeSimple]),
        BuiltInGesture(id: "share", title: "共享", action: .share, defaultSwipe: nil, defaultSamples: [shareUserDrawn])
    ]

    static func find(_ id: String) -> BuiltInGesture? {
        all.first { $0.id == id }
    }

    private static func samples(for action: GestureAction) -> [[[CGPoint]]] {
        GestureTemplate.templates(for: action).map { [$0.points] }
    }

    /// 用户亲手绘制的「关闭」叉号（两笔）。
    private static let closeUserDrawn: [[CGPoint]] = [
        [CGPoint(x: -1082.5, y: 605.8), CGPoint(x: -1099.9, y: 590.7), CGPoint(x: -1116.4, y: 574.4), CGPoint(x: -1133.5, y: 558.8), CGPoint(x: -1151.0, y: 543.5), CGPoint(x: -1168.3, y: 528.1), CGPoint(x: -1186.2, y: 513.4), CGPoint(x: -1204.3, y: 498.9), CGPoint(x: -1222.3, y: 484.3), CGPoint(x: -1240.2, y: 469.6), CGPoint(x: -1259.2, y: 456.3), CGPoint(x: -1278.3, y: 443.0), CGPoint(x: -1297.0, y: 429.4), CGPoint(x: -1315.8, y: 415.8), CGPoint(x: -1334.0, y: 401.4), CGPoint(x: -1352.4, y: 387.3), CGPoint(x: -1370.9, y: 373.3), CGPoint(x: -1388.8, y: 358.6), CGPoint(x: -1407.5, y: 344.8), CGPoint(x: -1427.6, y: 334.0)],
        [CGPoint(x: -1296.7, y: 578.4), CGPoint(x: -1287.4, y: 562.7), CGPoint(x: -1277.2, y: 547.7), CGPoint(x: -1266.5, y: 532.9), CGPoint(x: -1255.2, y: 518.5), CGPoint(x: -1243.8, y: 504.2), CGPoint(x: -1232.3, y: 490.0), CGPoint(x: -1220.8, y: 475.9), CGPoint(x: -1209.0, y: 461.9), CGPoint(x: -1197.2, y: 448.0), CGPoint(x: -1184.7, y: 434.7), CGPoint(x: -1172.1, y: 421.4), CGPoint(x: -1159.3, y: 408.4), CGPoint(x: -1146.3, y: 395.5), CGPoint(x: -1132.8, y: 383.3), CGPoint(x: -1118.7, y: 371.6), CGPoint(x: -1104.6, y: 360.1), CGPoint(x: -1090.2, y: 348.8), CGPoint(x: -1074.7, y: 339.2), CGPoint(x: -1059.4, y: 333.5)]
    ]

    /// 备用的标准叉号（两笔）。
    private static let closeSimple: [[CGPoint]] = [
        [CGPoint(x: 20, y: 20), CGPoint(x: 80, y: 80)],
        [CGPoint(x: 80, y: 20), CGPoint(x: 20, y: 80)]
    ]

    /// 用户亲手绘制的「共享」图案（单笔）。
    private static let shareUserDrawn: [[CGPoint]] = [
        [CGPoint(x: -581.7, y: 596.6), CGPoint(x: -599.1, y: 604.2), CGPoint(x: -617.2, y: 610.0), CGPoint(x: -635.8, y: 613.5), CGPoint(x: -654.3, y: 612.0), CGPoint(x: -671.8, y: 604.6), CGPoint(x: -688.8, y: 596.3), CGPoint(x: -702.3, y: 583.3), CGPoint(x: -705.1, y: 564.8), CGPoint(x: -699.3, y: 546.9), CGPoint(x: -687.6, y: 531.9), CGPoint(x: -674.0, y: 518.7), CGPoint(x: -660.2, y: 505.6), CGPoint(x: -647.1, y: 491.9), CGPoint(x: -634.8, y: 477.4), CGPoint(x: -623.2, y: 462.4), CGPoint(x: -613.1, y: 446.3), CGPoint(x: -610.6, y: 427.6), CGPoint(x: -618.4, y: 410.6), CGPoint(x: -632.2, y: 397.9), CGPoint(x: -648.6, y: 388.5), CGPoint(x: -666.7, y: 382.9), CGPoint(x: -685.4, y: 380.5), CGPoint(x: -704.4, y: 379.5), CGPoint(x: -723.4, y: 380.5), CGPoint(x: -741.5, y: 385.9), CGPoint(x: -759.4, y: 392.5), CGPoint(x: -776.2, y: 401.4)]
    ]
}
