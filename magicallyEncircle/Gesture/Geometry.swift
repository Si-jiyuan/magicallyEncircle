//
//  Geometry.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

/// 轨迹的几何计算：长度、包围盒、面积、闭环判断、方向分类。
enum Geometry {
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func pathLength(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 1 else { return 0 }
        var total: CGFloat = 0
        for index in 1..<points.count {
            total += distance(points[index - 1], points[index])
        }
        return total
    }

    static func boundingBox(_ points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 鞋带公式计算多边形面积（绝对值）。
    static func polygonArea(_ points: [CGPoint]) -> CGFloat {
        guard points.count > 2 else { return 0 }
        var area: CGFloat = 0
        var j = points.count - 1
        for i in 0..<points.count {
            area += (points[j].x + points[i].x) * (points[j].y - points[i].y)
            j = i
        }
        return abs(area / 2)
    }

    /// 判断轨迹是否构成一个闭合的环（不要求规范）。
    static func isClosedLoop(_ points: [CGPoint]) -> Bool {
        guard points.count > 6 else { return false }
        let box = boundingBox(points)
        let diagonal = hypot(box.width, box.height)
        guard diagonal > 60 else { return false }
        guard let first = points.first, let last = points.last else { return false }
        guard distance(first, last) < 0.35 * diagonal else { return false }
        guard polygonArea(points) > 0.06 * diagonal * diagonal else { return false }
        guard pathLength(points) > 1.4 * diagonal else { return false }
        return true
    }

    /// 若轨迹近似一条直线，返回其方向对应的动作。AppKit 坐标 y 轴向上。
    static func swipeDirection(_ points: [CGPoint]) -> GestureAction? {
        let length = pathLength(points)
        guard length > 60, let first = points.first, let last = points.last else { return nil }
        let straight = distance(first, last)
        guard straight / length > 0.8 else { return nil }

        let dx = last.x - first.x
        let dy = last.y - first.y
        if abs(dx) >= abs(dy) {
            return dx >= 0 ? .forward : .back
        } else {
            return dy >= 0 ? .missionControl : .appExpose
        }
    }
}
