//
//  MagicCanvasView.swift
//  magicallyEncircle
//

import AppKit

private struct Particle {
    var position: CGPoint
    var velocity: CGVector
    let born: TimeInterval
    let life: TimeInterval
    let size: CGFloat
    let color: NSColor
}

private final class Stroke {
    var points: [CGPoint]
    let startTime: TimeInterval
    var endTime: TimeInterval?
    let style: MagicStyle

    init(points: [CGPoint], startTime: TimeInterval, style: MagicStyle) {
        self.points = points
        self.startTime = startTime
        self.style = style
    }
}

/// 负责单块屏幕上的魔法线条绘制、粒子模拟与淡出动画。
final class MagicCanvasView: NSView {
    var style: MagicStyle = .whiteOrange

    private var strokes: [Stroke] = []
    private var particles: [Particle] = []
    private var current: Stroke?
    private var timer: Timer?

    private let fadeDuration: TimeInterval = 1.6
    private let frameInterval: TimeInterval = 1.0 / 60.0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        timer?.invalidate()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    // MARK: - 绘制输入

    func beginStroke(at point: CGPoint, time: TimeInterval) {
        let stroke = Stroke(points: [point], startTime: time, style: style)
        strokes.append(stroke)
        current = stroke
        spawnParticles(at: point, time: time)
        startTimerIfNeeded()
        needsDisplay = true
    }

    func extendStroke(to point: CGPoint, time: TimeInterval) {
        guard let stroke = current else { return }
        if let last = stroke.points.last, hypot(point.x - last.x, point.y - last.y) < 0.5 {
            return
        }
        stroke.points.append(point)
        spawnParticles(at: point, time: time)
        needsDisplay = true
    }

    func finishStroke(time: TimeInterval) {
        current?.endTime = time
        current = nil
    }

    // MARK: - 动画

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func stopTimerIfIdle() {
        guard strokes.isEmpty && particles.isEmpty else { return }
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime

        for index in particles.indices {
            particles[index].velocity.dx *= 0.96
            particles[index].velocity.dy *= 0.96
            particles[index].position.x += particles[index].velocity.dx * CGFloat(frameInterval)
            particles[index].position.y += particles[index].velocity.dy * CGFloat(frameInterval)
        }
        particles.removeAll { now - $0.born > $0.life }

        strokes.removeAll { stroke in
            guard let end = stroke.endTime else { return false }
            return now - end > fadeDuration
        }

        needsDisplay = true
        stopTimerIfIdle()
    }

    // MARK: - 粒子

    private func spawnParticles(at point: CGPoint, time: TimeInterval) {
        let count = Int.random(in: 1...3)
        for _ in 0..<count {
            let angle = Double.random(in: 0..<(2 * Double.pi))
            let speed = Double.random(in: 20...90)
            let velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
            let life = Double.random(in: 0.35...0.9)
            let size = CGFloat.random(in: 1.5...4.5)
            let color = style.particleColors.randomElement() ?? .white
            particles.append(Particle(position: point, velocity: velocity, born: time, life: life, size: size, color: color))
        }
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let now = ProcessInfo.processInfo.systemUptime

        drawParticles(in: ctx, now: now)
        drawStrokes(in: ctx, now: now)
    }

    private func drawParticles(in ctx: CGContext, now: TimeInterval) {
        for particle in particles {
            let remaining = max(0, 1 - (now - particle.born) / particle.life)
            let alpha = CGFloat(remaining)
            guard alpha > 0.01 else { continue }

            let radius = particle.size * (0.5 + 0.5 * CGFloat(remaining))
            let rect = CGRect(x: particle.position.x - radius, y: particle.position.y - radius,
                              width: radius * 2, height: radius * 2)

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 6, color: particle.color.withAlphaComponent(0.8 * alpha).cgColor)
            ctx.setFillColor(particle.color.withAlphaComponent(alpha).cgColor)
            ctx.fillEllipse(in: rect)
            ctx.restoreGState()
        }
    }

    private func drawStrokes(in ctx: CGContext, now: TimeInterval) {
        for stroke in strokes {
            let alpha = strokeAlpha(stroke, now: now)
            guard alpha > 0.01 else { continue }

            guard stroke.points.count > 1 else {
                drawDot(stroke, alpha: alpha, in: ctx)
                continue
            }

            let path = smoothedPath(stroke.points)

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 14, color: stroke.style.glowColor.withAlphaComponent(0.9 * alpha).cgColor)
            ctx.setStrokeColor(stroke.style.glowColor.withAlphaComponent(0.55 * alpha).cgColor)
            ctx.setLineWidth(7)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()

            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 3, color: stroke.style.coreColor.withAlphaComponent(0.9 * alpha).cgColor)
            ctx.setStrokeColor(stroke.style.coreColor.withAlphaComponent(alpha).cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.addPath(path)
            ctx.strokePath()
            ctx.restoreGState()
        }
    }

    private func drawDot(_ stroke: Stroke, alpha: CGFloat, in ctx: CGContext) {
        guard let point = stroke.points.first else { return }
        let radius: CGFloat = 3.5
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)

        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 12, color: stroke.style.glowColor.withAlphaComponent(0.9 * alpha).cgColor)
        ctx.setFillColor(stroke.style.glowColor.withAlphaComponent(0.7 * alpha).cgColor)
        ctx.fillEllipse(in: rect)
        ctx.setShadow(offset: .zero, blur: 3, color: stroke.style.coreColor.withAlphaComponent(0.9 * alpha).cgColor)
        ctx.setFillColor(stroke.style.coreColor.withAlphaComponent(alpha).cgColor)
        ctx.fillEllipse(in: rect.insetBy(dx: 1.5, dy: 1.5))
        ctx.restoreGState()
    }

    private func strokeAlpha(_ stroke: Stroke, now: TimeInterval) -> CGFloat {
        guard let end = stroke.endTime else { return 1 }
        return max(0, 1 - CGFloat((now - end) / fadeDuration))
    }

    /// 使用中点二次贝塞尔让折线变得平滑、柔和。
    private func smoothedPath(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 2 else {
            if let last = points.last { path.addLine(to: last) }
            return path
        }

        for index in 1..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let mid = CGPoint(x: (current.x + next.x) / 2, y: (current.y + next.y) / 2)
            path.addQuadCurve(to: mid, control: current)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        return path
    }
}
