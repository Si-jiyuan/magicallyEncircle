//
//  GestureRecognizer.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

/// 一个待匹配的手势候选（内置模板或用户自定义图案）。
struct GestureCandidate {
    let name: String
    let points: [CGPoint]
    let action: GestureAction?
    let customID: UUID?
}

/// $1 Unistroke Recognizer 的轻量实现（加入反向绘制 + 小幅旋转容错）。
/// 纯代码模板、无需图片；返回 0...1 的相似度分数，天然支持模糊匹配。
final class GestureRecognizer {
    static let shared = GestureRecognizer()

    private let sampleCount = 64
    private let squareSize: CGFloat = 250

    private init() {}

    /// 在候选集合里返回得分最高的一个。
    func recognize(_ points: [CGPoint], candidates: [GestureCandidate]) -> (candidate: GestureCandidate, score: Double)? {
        guard points.count >= 2, !candidates.isEmpty else { return nil }
        let candidate = GestureRecognizer.preprocess(points, sampleCount: sampleCount, squareSize: squareSize)

        var best: (GestureCandidate, Double)?
        for entry in candidates {
            let processed = GestureRecognizer.preprocess(entry.points, sampleCount: sampleCount, squareSize: squareSize)
            let score = GestureRecognizer.matchScore(candidate, processed, squareSize: squareSize)
            if best == nil || score > best!.1 {
                best = (entry, score)
            }
        }
        return best
    }

    // MARK: - 预处理

    static func preprocess(_ raw: [CGPoint], sampleCount: Int, squareSize: CGFloat) -> [CGPoint] {
        let resampled = resample(raw, count: sampleCount)
        let scaled = scaleToSquare(resampled, size: squareSize)
        return translateToOrigin(scaled)
    }

    /// 按等距重采样成固定数量点。
    static func resample(_ points: [CGPoint], count: Int) -> [CGPoint] {
        guard points.count > 1 else { return points }
        let interval = Geometry.pathLength(points) / CGFloat(count - 1)
        guard interval > 0 else { return points }

        var working = points
        var accumulated: CGFloat = 0
        var result: [CGPoint] = [points[0]]
        var index = 1

        while index < working.count {
            let d = Geometry.distance(working[index - 1], working[index])
            if d <= 0 {
                index += 1
                continue
            }
            if accumulated + d >= interval {
                let t = (interval - accumulated) / d
                let point = CGPoint(
                    x: working[index - 1].x + t * (working[index].x - working[index - 1].x),
                    y: working[index - 1].y + t * (working[index].y - working[index - 1].y)
                )
                result.append(point)
                working.insert(point, at: index)
                accumulated = 0
            } else {
                accumulated += d
            }
            index += 1
        }

        while result.count < count, let last = points.last {
            result.append(last)
        }
        if result.count > count {
            result = Array(result.prefix(count))
        }
        return result
    }

    /// 等比缩放到指定大小的正方形内。
    static func scaleToSquare(_ points: [CGPoint], size: CGFloat) -> [CGPoint] {
        let box = Geometry.boundingBox(points)
        let side = max(box.width, box.height)
        guard side > 0 else { return points }
        let scale = size / side
        return points.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
    }

    /// 平移到质心为原点。
    static func translateToOrigin(_ points: [CGPoint]) -> [CGPoint] {
        guard !points.isEmpty else { return points }
        var sumX: CGFloat = 0, sumY: CGFloat = 0
        for point in points {
            sumX += point.x; sumY += point.y
        }
        let centroid = CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
        return points.map { CGPoint(x: $0.x - centroid.x, y: $0.y - centroid.y) }
    }

    /// 平均点距离转成 0...1 的分数。
    static func score(_ a: [CGPoint], _ b: [CGPoint], squareSize: CGFloat) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var sum: CGFloat = 0
        for index in 0..<a.count {
            sum += Geometry.distance(a[index], b[index])
        }
        let average = sum / CGFloat(a.count)
        let halfDiagonal = 0.5 * hypot(squareSize, squareSize)
        return max(0, 1 - Double(average / halfDiagonal))
    }

    /// 反向重绘容错 + 小幅旋转容错，取最高分。
    static func matchScore(_ candidate: [CGPoint], _ template: [CGPoint], squareSize: CGFloat) -> Double {
        let variants: [[CGPoint]] = [candidate, Array(candidate.reversed())]
        var best: Double = 0
        for variant in variants {
            for angle in [-10.0, 0.0, 10.0] {
                let rotated = translateToOrigin(rotate(variant, degrees: angle))
                best = max(best, score(rotated, template, squareSize: squareSize))
            }
        }
        return best
    }

    static func rotate(_ points: [CGPoint], degrees: Double) -> [CGPoint] {
        let radians = degrees * Double.pi / 180
        let cosValue = CGFloat(cos(radians))
        let sinValue = CGFloat(sin(radians))
        return points.map { point in
            CGPoint(x: point.x * cosValue - point.y * sinValue,
                    y: point.x * sinValue + point.y * cosValue)
        }
    }
}
