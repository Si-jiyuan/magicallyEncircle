//
//  PatternPlayer.swift
//  magicallyEncircle
//

import AppKit

/// 把图案按「用户绘制」的方式在覆盖层上播放出来（复用魔法线条的绘制管线，
/// 因此风格、辉光、粒子、淡出都一致）。
final class PatternPlayer {
    private weak var canvas: MagicCanvasView?
    private var strokes: [[CGPoint]] = []
    private var timer: Timer?
    private var strokeIndex = 0
    private var pointIndex = 0
    private var accumulated: Double = 0
    private var lastTick: TimeInterval = 0
    private var pointsPerSecond: Double = 40

    private let basePointsPerSecond: Double = 55

    func play(strokes: [[CGPoint]], on canvas: MagicCanvasView, speed: Double) {
        cancel()
        let valid = strokes.filter { $0.count >= 2 }
        guard !valid.isEmpty else { return }

        self.canvas = canvas
        self.strokes = valid
        strokeIndex = 0
        pointIndex = 0
        accumulated = 0
        lastTick = ProcessInfo.processInfo.systemUptime
        pointsPerSecond = basePointsPerSecond * max(0.05, speed)
        // 播放期间固定笔画（先画完的不提前淡出），等全部播完再统一淡出。
        canvas.pinsStrokes = true

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        if let canvas {
            // 结束固定，让所有笔画一起开始淡出。
            canvas.pinsStrokes = false
            canvas.releasePinnedStrokes(time: ProcessInfo.processInfo.systemUptime)
        }
        canvas = nil
    }

    private func tick() {
        guard let canvas else { cancel(); return }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = now - lastTick
        lastTick = now
        accumulated += pointsPerSecond * dt

        let count = Int(accumulated)
        guard count > 0 else { return }
        accumulated -= Double(count)

        for _ in 0..<count {
            if !advance(canvas: canvas, now: now) {
                cancel()
                return
            }
        }
    }

    /// 前进一个点；返回 false 表示全部播放完。
    private func advance(canvas: MagicCanvasView, now: TimeInterval) -> Bool {
        guard strokeIndex < strokes.count else { return false }
        let stroke = strokes[strokeIndex]

        if pointIndex == 0 {
            canvas.beginStroke(at: stroke[0], time: now)
            pointIndex = 1
            return true
        }

        if pointIndex < stroke.count {
            canvas.extendStroke(to: stroke[pointIndex], time: now)
            pointIndex += 1
            if pointIndex >= stroke.count {
                canvas.finishStroke(time: now)
                strokeIndex += 1
                pointIndex = 0
            }
            return true
        }

        strokeIndex += 1
        pointIndex = 0
        return strokeIndex < strokes.count
    }
}
