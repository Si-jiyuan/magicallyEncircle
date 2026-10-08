//
//  GestureRecognizer.swift
//  magicallyEncircle
//

import CoreGraphics
import Foundation

/// 一个待匹配的手势候选（内置模板或用户自定义图案）。
/// 用多笔画表示：单笔画就是只含一个元素的数组。
struct GestureCandidate {
    let name: String
    let strokes: [[CGPoint]]
    let action: GestureAction?
    let customID: UUID?
}

/// $1 Unistroke Recognizer 的轻量实现（加入反向绘制 + 小幅旋转容错），
/// 并支持多笔画：每笔独立重采样后做顺序无关的贪心配对，
/// 因此抬笔跳线不会影响结果，也不要求笔顺。
final class GestureRecognizer {
    static let shared = GestureRecognizer()

    private let sampleCount = 64
    private let squareSize: CGFloat = 250

    private init() {}

    /// 在候选集合里返回得分最高的一个。
    func recognize(_ strokes: [[CGPoint]], candidates: [GestureCandidate]) -> (candidate: GestureCandidate, score: Double)? {
        ranked(strokes, candidates: candidates).first
    }

    /// 返回所有候选的得分（从高到低），用于调试与更精细的判断。
    func ranked(_ strokes: [[CGPoint]], candidates: [GestureCandidate]) -> [(candidate: GestureCandidate, score: Double)] {
        guard !strokes.isEmpty, !candidates.isEmpty else { return [] }

        var ranked: [(GestureCandidate, Double)] = []
        ranked.reserveCapacity(candidates.count)
        for entry in candidates {
            let score = GestureRecognizer.matchStrokes(strokes, entry.strokes, sampleCount: sampleCount, squareSize: squareSize)
            ranked.append((entry, score))
        }
        return ranked.sorted { $0.1 > $1.1 }
    }

    // MARK: - 匹配

    /// 多笔画匹配：单笔对单笔走原 $1；
    /// 其余 = 逐笔形状匹配（顺序无关） + 整体点云匹配（考虑笔画间的相对位置/交叉关系）。
    static func matchStrokes(_ a: [[CGPoint]], _ b: [[CGPoint]], sampleCount: Int, squareSize: CGFloat) -> Double {
        let strokesA = a.filter { $0.count >= 2 && Geometry.pathLength($0) > 0 }
        let strokesB = b.filter { $0.count >= 2 && Geometry.pathLength($0) > 0 }
        guard !strokesA.isEmpty, !strokesB.isEmpty else { return 0 }

        if strokesA.count == 1, strokesB.count == 1 {
            return singleStrokeScore(strokesA[0], strokesB[0], sampleCount: sampleCount, squareSize: squareSize)
        }

        // 整体关系权重更高，避免「两笔斜线」与「交叉的叉号」这类误判。
        let shape = greedyStrokeScore(strokesA, strokesB, sampleCount: sampleCount, squareSize: squareSize)
        let arrangement = cloudScore(strokesA, strokesB, sampleCount: sampleCount, squareSize: squareSize)
        return shape * 0.35 + arrangement * 0.65
    }

    /// 顺序无关的逐笔贪心形状匹配。
    static func greedyStrokeScore(_ strokesA: [[CGPoint]], _ strokesB: [[CGPoint]], sampleCount: Int, squareSize: CGFloat) -> Double {
        var used = [Bool](repeating: false, count: strokesB.count)
        var total: Double = 0
        for stroke in strokesA {
            var best = 0.0
            var bestIndex = -1
            for index in strokesB.indices where !used[index] {
                let score = singleStrokeScore(stroke, strokesB[index], sampleCount: sampleCount, squareSize: squareSize)
                if score > best {
                    best = score
                    bestIndex = index
                }
            }
            if bestIndex >= 0 {
                used[bestIndex] = true
                total += best
            }
        }
        return total / Double(max(strokesA.count, strokesB.count))
    }

    /// 把所有笔画点合并成点云后整体匹配，能区分「交叉」与「分开」等相对关系。
    static func cloudScore(_ strokesA: [[CGPoint]], _ strokesB: [[CGPoint]], sampleCount: Int, squareSize: CGFloat) -> Double {
        let cloudA = cloudPoints(strokesA, perStroke: sampleCount / 2)
        let cloudB = cloudPoints(strokesB, perStroke: sampleCount / 2)
        guard !cloudA.isEmpty, !cloudB.isEmpty else { return 0 }

        let normalizedA = translateToOrigin(scaleToSquare(cloudA, size: squareSize))
        let normalizedB = translateToOrigin(scaleToSquare(cloudB, size: squareSize))

        let forward = greedyCloudDistance(normalizedA, normalizedB, squareSize: squareSize)
        let backward = greedyCloudDistance(normalizedB, normalizedA, squareSize: squareSize)
        return (forward + backward) / 2
    }

    /// 每笔各自重采样后合并（不插值抬笔跳线），保留笔画点分布。
    static func cloudPoints(_ strokes: [[CGPoint]], perStroke: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        for stroke in strokes where stroke.count >= 2 {
            points.append(contentsOf: resample(stroke, count: max(2, perStroke)))
        }
        return points
    }

    static func greedyCloudDistance(_ a: [CGPoint], _ b: [CGPoint], squareSize: CGFloat) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var used = [Bool](repeating: false, count: b.count)
        var sum: CGFloat = 0
        var matched = 0
        for point in a {
            var best = CGFloat.greatestFiniteMagnitude
            var bestIndex = -1
            for index in b.indices where !used[index] {
                let distance = Geometry.distance(point, b[index])
                if distance < best {
                    best = distance
                    bestIndex = index
                }
            }
            if bestIndex >= 0 {
                used[bestIndex] = true
                sum += best
                matched += 1
            }
        }
        guard matched > 0 else { return 0 }
        let average = sum / CGFloat(matched)
        let halfDiagonal = 0.5 * hypot(squareSize, squareSize)
        return max(0, 1 - Double(average / halfDiagonal))
    }

    /// 单笔试别：预处理 + 反向/旋转容错。
    static func singleStrokeScore(_ a: [CGPoint], _ b: [CGPoint], sampleCount: Int, squareSize: CGFloat) -> Double {
        guard a.count >= 2, b.count >= 2 else { return 0 }
        let processedA = preprocess(a, sampleCount: sampleCount, squareSize: squareSize)
        let processedB = preprocess(b, sampleCount: sampleCount, squareSize: squareSize)
        return bestRotatedScore(processedA, processedB, squareSize: squareSize)
    }

    /// 反向重绘容错 + 小幅旋转容错，取最高分。
    static func bestRotatedScore(_ candidate: [CGPoint], _ template: [CGPoint], squareSize: CGFloat) -> Double {
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
