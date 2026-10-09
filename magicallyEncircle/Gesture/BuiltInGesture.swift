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
        BuiltInGesture(id: "delete", title: "删除", action: .delete, defaultSwipe: nil, defaultSamples: [deleteSample]),
        BuiltInGesture(id: "spaceLeft", title: "向左切换桌面", action: .switchSpaceLeft, defaultSwipe: nil, defaultSamples: [spaceLeftSample]),
        BuiltInGesture(id: "spaceRight", title: "向右切换桌面", action: .switchSpaceRight, defaultSwipe: nil, defaultSamples: [spaceRightSample]),
        BuiltInGesture(id: "share", title: "共享", action: .share, defaultSwipe: nil, defaultSamples: [shareUserDrawn]),
        BuiltInGesture(id: "close", title: "关闭", action: .close, defaultSwipe: nil, defaultSamples: [closeUserDrawn, closeSimple])
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

    /// 用户亲手绘制的「删除」图案（单笔，⌘⌫）。
    private static let deleteSample: [[CGPoint]] = [
        [CGPoint(x: 1203.5, y: 948.3), CGPoint(x: 1203.5, y: 918.0), CGPoint(x: 1203.5, y: 887.6), CGPoint(x: 1203.5, y: 857.2), CGPoint(x: 1203.5, y: 826.9), CGPoint(x: 1203.5, y: 796.5), CGPoint(x: 1203.5, y: 766.1), CGPoint(x: 1203.5, y: 735.8), CGPoint(x: 1207.7, y: 715.7), CGPoint(x: 1207.7, y: 746.1), CGPoint(x: 1207.7, y: 776.4), CGPoint(x: 1210.8, y: 806.6), CGPoint(x: 1214.8, y: 836.6), CGPoint(x: 1218.1, y: 866.8), CGPoint(x: 1219.7, y: 897.1), CGPoint(x: 1235.4, y: 912.7), CGPoint(x: 1264.4, y: 904.3), CGPoint(x: 1290.8, y: 889.5), CGPoint(x: 1313.2, y: 869.1), CGPoint(x: 1326.5, y: 842.2), CGPoint(x: 1332.6, y: 812.5), CGPoint(x: 1333.7, y: 782.2), CGPoint(x: 1323.7, y: 754.5), CGPoint(x: 1301.9, y: 733.6), CGPoint(x: 1278.8, y: 713.9), CGPoint(x: 1252.2, y: 699.6), CGPoint(x: 1222.3, y: 694.8), CGPoint(x: 1192.0, y: 694.8)]
    ]

    /// 用户亲手绘制的「共享」图案（单笔）。
    private static let shareUserDrawn: [[CGPoint]] = [
        [CGPoint(x: -581.7, y: 596.6), CGPoint(x: -599.1, y: 604.2), CGPoint(x: -617.2, y: 610.0), CGPoint(x: -635.8, y: 613.5), CGPoint(x: -654.3, y: 612.0), CGPoint(x: -671.8, y: 604.6), CGPoint(x: -688.8, y: 596.3), CGPoint(x: -702.3, y: 583.3), CGPoint(x: -705.1, y: 564.8), CGPoint(x: -699.3, y: 546.9), CGPoint(x: -687.6, y: 531.9), CGPoint(x: -674.0, y: 518.7), CGPoint(x: -660.2, y: 505.6), CGPoint(x: -647.1, y: 491.9), CGPoint(x: -634.8, y: 477.4), CGPoint(x: -623.2, y: 462.4), CGPoint(x: -613.1, y: 446.3), CGPoint(x: -610.6, y: 427.6), CGPoint(x: -618.4, y: 410.6), CGPoint(x: -632.2, y: 397.9), CGPoint(x: -648.6, y: 388.5), CGPoint(x: -666.7, y: 382.9), CGPoint(x: -685.4, y: 380.5), CGPoint(x: -704.4, y: 379.5), CGPoint(x: -723.4, y: 380.5), CGPoint(x: -741.5, y: 385.9), CGPoint(x: -759.4, y: 392.5), CGPoint(x: -776.2, y: 401.4)]
    ]

    /// 用户亲手绘制的「向左切换桌面」（横线 + 左箭头）。
    private static let spaceLeftSample: [[CGPoint]] = [
        [CGPoint(x: 194.1, y: -119.7), CGPoint(x: 187.9, y: -119.7), CGPoint(x: 182.0, y: -118.5), CGPoint(x: 175.9, y: -118.5), CGPoint(x: 169.9, y: -118.0), CGPoint(x: 163.9, y: -117.4), CGPoint(x: 157.8, y: -117.3), CGPoint(x: 151.7, y: -117.1), CGPoint(x: 145.6, y: -116.8), CGPoint(x: 139.5, y: -116.8), CGPoint(x: 133.4, y: -116.8), CGPoint(x: 127.2, y: -116.8), CGPoint(x: 121.1, y: -116.8), CGPoint(x: 115.0, y: -116.8), CGPoint(x: 108.9, y: -116.8), CGPoint(x: 102.8, y: -116.8), CGPoint(x: 96.6, y: -116.8), CGPoint(x: 90.5, y: -116.8), CGPoint(x: 84.4, y: -116.8), CGPoint(x: 78.3, y: -116.8), CGPoint(x: 72.2, y: -116.8), CGPoint(x: 66.0, y: -116.8), CGPoint(x: 59.9, y: -116.8), CGPoint(x: 53.8, y: -116.8), CGPoint(x: 47.7, y: -116.8), CGPoint(x: 41.6, y: -116.8), CGPoint(x: 35.4, y: -116.8), CGPoint(x: 29.3, y: -116.8)],
        [CGPoint(x: 82.4, y: -65.7), CGPoint(x: 77.3, y: -67.3), CGPoint(x: 73.1, y: -70.6), CGPoint(x: 69.2, y: -74.5), CGPoint(x: 65.1, y: -77.9), CGPoint(x: 60.8, y: -81.3), CGPoint(x: 56.7, y: -84.8), CGPoint(x: 52.6, y: -88.4), CGPoint(x: 48.8, y: -92.2), CGPoint(x: 45.0, y: -96.2), CGPoint(x: 41.3, y: -100.1), CGPoint(x: 37.7, y: -104.2), CGPoint(x: 34.1, y: -108.3), CGPoint(x: 30.1, y: -112.0), CGPoint(x: 28.3, y: -116.6), CGPoint(x: 32.1, y: -120.4), CGPoint(x: 36.5, y: -123.6), CGPoint(x: 40.8, y: -126.8), CGPoint(x: 45.3, y: -129.7), CGPoint(x: 49.8, y: -132.8), CGPoint(x: 54.2, y: -136.0), CGPoint(x: 58.6, y: -139.1), CGPoint(x: 63.1, y: -142.3), CGPoint(x: 67.5, y: -145.5), CGPoint(x: 71.8, y: -148.8), CGPoint(x: 76.0, y: -152.2), CGPoint(x: 80.4, y: -155.3), CGPoint(x: 84.5, y: -158.9)]
    ]

    /// 用户亲手绘制的「向右切换桌面」（横线 + 右箭头）。
    private static let spaceRightSample: [[CGPoint]] = [
        [CGPoint(x: 14.3, y: -113.8), CGPoint(x: 20.8, y: -112.5), CGPoint(x: 27.7, y: -112.5), CGPoint(x: 34.2, y: -111.1), CGPoint(x: 41.0, y: -111.1), CGPoint(x: 47.8, y: -111.1), CGPoint(x: 54.7, y: -111.1), CGPoint(x: 61.5, y: -111.1), CGPoint(x: 68.3, y: -111.1), CGPoint(x: 75.1, y: -111.1), CGPoint(x: 82.0, y: -111.1), CGPoint(x: 88.8, y: -111.1), CGPoint(x: 95.5, y: -112.0), CGPoint(x: 102.2, y: -112.7), CGPoint(x: 108.9, y: -113.8), CGPoint(x: 115.7, y: -113.8), CGPoint(x: 122.6, y: -113.8), CGPoint(x: 129.3, y: -114.6), CGPoint(x: 136.1, y: -114.8), CGPoint(x: 142.8, y: -115.2), CGPoint(x: 149.6, y: -115.3), CGPoint(x: 156.5, y: -115.3), CGPoint(x: 163.3, y: -115.3), CGPoint(x: 170.1, y: -115.3), CGPoint(x: 176.9, y: -115.3), CGPoint(x: 183.8, y: -115.3), CGPoint(x: 190.6, y: -115.3), CGPoint(x: 197.4, y: -115.3)],
        [CGPoint(x: 136.3, y: -65.8), CGPoint(x: 140.7, y: -69.8), CGPoint(x: 145.6, y: -73.0), CGPoint(x: 150.5, y: -76.2), CGPoint(x: 155.7, y: -79.0), CGPoint(x: 160.1, y: -83.0), CGPoint(x: 164.7, y: -86.8), CGPoint(x: 169.8, y: -89.8), CGPoint(x: 174.9, y: -92.9), CGPoint(x: 179.7, y: -96.3), CGPoint(x: 184.3, y: -100.1), CGPoint(x: 188.8, y: -103.8), CGPoint(x: 193.7, y: -107.2), CGPoint(x: 199.1, y: -109.7), CGPoint(x: 203.0, y: -114.1), CGPoint(x: 198.0, y: -116.4), CGPoint(x: 192.7, y: -119.2), CGPoint(x: 187.6, y: -122.1), CGPoint(x: 182.9, y: -125.7), CGPoint(x: 178.1, y: -129.2), CGPoint(x: 173.1, y: -132.3), CGPoint(x: 168.1, y: -135.5), CGPoint(x: 163.0, y: -138.6), CGPoint(x: 158.1, y: -141.9), CGPoint(x: 153.3, y: -145.3), CGPoint(x: 148.1, y: -148.2), CGPoint(x: 143.2, y: -151.5), CGPoint(x: 138.7, y: -155.4)]
    ]
}
