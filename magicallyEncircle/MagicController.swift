//
//  MagicController.swift
//  magicallyEncircle
//

import AppKit
import ApplicationServices
import Combine
import UniformTypeIdentifiers

/// 全局协调器：覆盖层管理、输入监听、手势识别、动作执行、自定义手势与权限。
final class MagicController: NSObject, ObservableObject {
    static let shared = MagicController()

    @Published var isEnabled: Bool = true {
        didSet { monitor.isEnabled = isEnabled }
    }

    @Published var style: MagicStyle = .whiteOrange {
        didSet { applyStyle() }
    }

    @Published var showRecognitionHUD: Bool = true
    @Published private(set) var isRecordingGesture = false
    @Published private(set) var customGestures: [CustomGesture] = []
    @Published private(set) var pendingBindingID: UUID?
    @Published private(set) var pendingKeyDisplay: String?

    private let monitor = InputMonitor()
    private let store = CustomGestureStore()

    private var windows: [OverlayWindow] = []
    private var currentView: MagicCanvasView?
    private var currentWindow: OverlayWindow?

    private var currentPoints: [CGPoint] = []
    private var strokeClosed = false
    private var holdTimer: Timer?
    private var didCapture = false
    private var started = false

    private var pendingKeyCode: UInt16?
    private var pendingModifiers: CGEventFlags = []
    private var previewCache: [UUID: NSImage] = [:]

    private let holdDuration: TimeInterval = 2.0
    private let symbolThreshold: Double = 0.72

    private override init() {
        super.init()
        customGestures = store.load()
        monitor.delegate = self
        monitor.isEnabled = isEnabled
        monitor.onKeyCaptured = { [weak self] keyCode, flags in
            self?.handleCapturedKey(keyCode: keyCode, flags: flags)
        }
    }

    func start() {
        guard !started else { return }
        started = true

        rebuildOverlays()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        requestAccessibilityIfNeeded()
        if !monitor.start() {
            DispatchQueue.main.async { [weak self] in
                self?.showAccessibilityAlert()
            }
        } else {
            showHUD(title: "magicallyEncircle 已启动", detail: "按住 Option 拖动开始绘制")
        }
    }

    func stop() {
        monitor.stop()
        holdTimer?.invalidate()
        holdTimer = nil
        NotificationCenter.default.removeObserver(self)
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }

    // MARK: - 菜单动作

    func toggleEnabled() { isEnabled.toggle() }

    func toggleHUD() { showRecognitionHUD.toggle() }

    func selectStyle(_ style: MagicStyle) { self.style = style }

    // MARK: - 覆盖层

    @objc private func screenParametersChanged() {
        rebuildOverlays()
    }

    private func rebuildOverlays() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            window.canvasView.style = style
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func applyStyle() {
        windows.forEach { $0.canvasView.style = style }
    }

    private func target(for screenPoint: CGPoint) -> (OverlayWindow, MagicCanvasView)? {
        for window in windows where window.targetScreen.frame.contains(screenPoint) {
            return (window, window.canvasView)
        }
        return nil
    }

    // MARK: - 自定义手势记录

    func beginRecordingGesture() {
        cancelPendingBinding()
        isRecordingGesture = true
        showHUD(title: "记录手势中", detail: "用 Option+左键画一个图案，松手即保存")
    }

    func cancelRecordingGesture() {
        isRecordingGesture = false
        showHUD(title: "已取消记录", detail: "")
    }

    private func saveRecordedGesture(_ points: [CGPoint]) {
        isRecordingGesture = false
        guard points.count >= 2, Geometry.pathLength(points) > 30 else {
            showHUD(title: "图案太短", detail: "请重新记录")
            return
        }
        let gesture = CustomGesture(name: "图案\(customGestures.count + 1)", points: points)
        customGestures.append(gesture)
        persist()
        showHUD(title: "已保存 \(gesture.name)", detail: "到菜单「自定义手势」绑定快捷键")
    }

    // MARK: - 快捷键绑定

    func beginKeyBinding(for id: UUID) {
        guard customGestures.contains(where: { $0.id == id }) else { return }
        isRecordingGesture = false
        pendingBindingID = id
        pendingKeyCode = nil
        pendingModifiers = []
        pendingKeyDisplay = nil
        monitor.startKeyCapture()
        showHUD(title: "请按下快捷键", detail: "需包含一个普通按键；按完回菜单点「保存绑定」")
    }

    func commitPendingBinding() {
        guard let id = pendingBindingID,
              let keyCode = pendingKeyCode,
              let index = customGestures.firstIndex(where: { $0.id == id }) else { return }

        customGestures[index].keyCode = keyCode
        customGestures[index].modifierFlags = pendingModifiers.rawValue
        customGestures[index].keyDisplay = pendingKeyDisplay ?? ""
        persist()

        let name = customGestures[index].name
        let display = pendingKeyDisplay ?? ""
        cancelPendingBinding()
        showHUD(title: "已绑定", detail: "\(name) → \(display)")
    }

    func cancelPendingBinding() {
        pendingBindingID = nil
        pendingKeyCode = nil
        pendingModifiers = []
        pendingKeyDisplay = nil
        monitor.endKeyCapture()
    }

    private func handleCapturedKey(keyCode: UInt16, flags: CGEventFlags) {
        guard pendingBindingID != nil else { return }
        let modifiers = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        pendingKeyCode = keyCode
        pendingModifiers = modifiers
        pendingKeyDisplay = KeyCodeNames.displayString(keyCode: keyCode, flags: modifiers)
        monitor.endKeyCapture()
        showHUD(title: "已捕获 \(pendingKeyDisplay ?? "")", detail: "回到菜单点击「保存绑定」")
    }

    // MARK: - 自定义手势管理

    func renameGesture(_ id: UUID) {
        guard let gesture = customGestures.first(where: { $0.id == id }) else { return }

        let alert = NSAlert()
        alert.messageText = "重命名图案"
        alert.informativeText = "为这个手势起个名字"
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = gesture.name
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty, let index = customGestures.firstIndex(where: { $0.id == id }) {
                customGestures[index].name = newName
                persist()
            }
        }
    }

    func deleteGesture(_ id: UUID) {
        customGestures.removeAll { $0.id == id }
        previewCache[id] = nil
        if pendingBindingID == id {
            cancelPendingBinding()
        }
        persist()
    }

    func previewImage(for gesture: CustomGesture) -> NSImage? {
        if let cached = previewCache[gesture.id] { return cached }
        guard let image = Self.makePreview(points: gesture.points.map { $0.cgPoint }) else { return nil }
        previewCache[gesture.id] = image
        return image
    }

    private func persist() {
        store.save(customGestures)
    }

    // MARK: - 导入 / 导出

    func exportGestures() {
        guard !customGestures.isEmpty else {
            showHUD(title: "没有可导出的图案", detail: "")
            return
        }
        let panel = NSSavePanel()
        panel.title = "导出自定义图案"
        panel.nameFieldStringValue = "magicallyEncircle-gestures.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(GesturePackage(version: 1, gestures: customGestures))
            try data.write(to: url)
            showHUD(title: "已导出手势", detail: "\(customGestures.count) 个图案")
        } catch {
            showHUD(title: "导出失败", detail: error.localizedDescription)
        }
    }

    func importGestures() {
        let panel = NSOpenPanel()
        panel.title = "导入手势"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(GesturePackage.self, from: data)
            var count = 0
            for imported in package.gestures {
                var gesture = CustomGesture(name: uniqueName(imported.name), points: imported.points.map { $0.cgPoint })
                gesture.keyCode = imported.keyCode
                gesture.modifierFlags = imported.modifierFlags
                gesture.keyDisplay = imported.keyDisplay
                customGestures.append(gesture)
                count += 1
            }
            persist()
            showHUD(title: "已导入手势", detail: "\(count) 个图案")
        } catch {
            showHUD(title: "导入失败", detail: "文件格式不正确")
        }
    }

    private func uniqueName(_ base: String) -> String {
        let existing = Set(customGestures.map { $0.name })
        guard existing.contains(base) else { return base }
        var index = 2
        while existing.contains("\(base) \(index)") { index += 1 }
        return "\(base) \(index)"
    }

    private static func makePreview(points: [CGPoint], size: CGFloat = 18) -> NSImage? {
        guard points.count >= 2 else { return nil }
        let box = Geometry.boundingBox(points)
        let content = size - 4
        let scale = content / max(box.width, box.height, 1)
        let offsetX = 2 + (content - box.width * scale) / 2
        let offsetY = 2 + (content - box.height * scale) / 2

        // 用位图后端生成，块式图像无法被 NSSecureCoding 编码（菜单经 XPC 传递会报错）。
        let scaleFactor = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size) * scaleFactor,
            pixelsHigh: Int(size) * scaleFactor,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: rep) else {
            return nil
        }
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context

        let path = NSBezierPath()
        var first = true
        for point in points {
            let mapped = NSPoint(x: offsetX + (point.x - box.minX) * scale,
                                 y: offsetY + (point.y - box.minY) * scale)
            if first {
                path.move(to: mapped); first = false
            } else {
                path.line(to: mapped)
            }
        }
        NSColor.black.setStroke()
        path.lineWidth = 1.6
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(rep)
        image.isTemplate = true
        return image
    }

    // MARK: - 手势执行

    private func resetStrokeState() {
        currentPoints.removeAll()
        strokeClosed = false
        holdTimer?.invalidate()
        holdTimer = nil
        didCapture = false
    }

    private func startHoldTimer() {
        holdTimer?.invalidate()
        let timer = Timer(timeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.performLassoCapture()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func customInputs() -> [CustomTemplateInput] {
        // 只有绑定了快捷键的自定义图案才参与匹配；
        // 未绑定的（例如录制备用的样本）不参与，避免挡住内置动作。
        customGestures.filter { $0.keyCode != nil }.map {
            CustomTemplateInput(id: $0.id, name: $0.name, points: $0.points.map { $0.cgPoint })
        }
    }

    private func performSymbolGesture(_ points: [CGPoint]) {
        if let action = Geometry.swipeDirection(points) {
            trigger(action, extra: action.shortcut?.display ?? "")
            return
        }

        let match = GestureRecognizer.shared.recognize(points, custom: customInputs())
        if let match, match.score >= symbolThreshold {
            if let customID = match.customID {
                performCustomGesture(customID, score: match.score)
            } else if let action = match.action {
                trigger(action, extra: String(format: "%@ · 匹配 %.0f%%", match.name, match.score * 100))
            }
            return
        }

        if let match {
            showHUD(title: "未识别图案", detail: String(format: "最接近 %@ · %.0f%%", match.name, match.score * 100))
        } else {
            showHUD(title: "未识别图案", detail: "试试滑动，或到菜单记录新手势")
        }
    }

    private func performCustomGesture(_ id: UUID, score: Double) {
        guard let gesture = customGestures.first(where: { $0.id == id }) else { return }
        guard let keyCode = gesture.keyCode else {
            showHUD(title: gesture.name, detail: "未绑定快捷键")
            return
        }
        let shortcut = KeyShortcut(
            keyCode: keyCode,
            flags: CGEventFlags(rawValue: gesture.modifierFlags),
            display: gesture.keyDisplay
        )
        shortcut.send()
        showHUD(title: gesture.name, detail: "\(gesture.keyDisplay) · 匹配 \(Int((score * 100).rounded()))%")
    }

    private func trigger(_ action: GestureAction, extra: String) {
        action.perform()
        var detail = action.shortcut?.display ?? ""
        if !extra.isEmpty {
            detail += detail.isEmpty ? extra : "   " + extra
        }
        showHUD(title: action.title, detail: detail)
    }

    // MARK: - 圈选动作

    private func performLassoCapture() {
        guard !didCapture, !isRecordingGesture, !currentPoints.isEmpty else { return }
        didCapture = true
        holdTimer?.invalidate()
        holdTimer = nil

        guard ensureScreenRecordingPermission(),
              let image = ScreenCaptureService.capture(regionInAppKit: paddedBoundingBox(currentPoints)) else {
            showHUD(title: "截图失败", detail: "请在系统设置授予「屏幕录制」权限")
            return
        }

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([nsImage])

        currentView?.finishStroke(time: ProcessInfo.processInfo.systemUptime)
        showHUD(title: "已截图圈选区域", detail: "图片已复制到剪贴板")
    }

    private func performLassoCopy() {
        guard !currentPoints.isEmpty else { return }
        let region = paddedBoundingBox(currentPoints)
        let samplePoints = sampleGridPoints(in: region)
        let regionInCG = ScreenCaptureService.toCGRect(region)

        var text: String?
        if ensureScreenRecordingPermission(),
           let image = ScreenCaptureService.capture(regionInAppKit: region) {
            text = TextExtractionService.extract(from: image, samplePointsInCG: samplePoints, regionInCG: regionInCG)
        } else {
            text = TextExtractionService.extractWithAccessibility(samplePointsInCG: samplePoints, regionInCG: regionInCG)
        }

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showHUD(title: "未找到可复制文本", detail: "试着圈住文字再松手")
            return
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showHUD(title: "已复制圈选文本", detail: "共 \(text.count) 个字符")
    }

    private func paddedBoundingBox(_ points: [CGPoint]) -> CGRect {
        Geometry.boundingBox(points).insetBy(dx: -6, dy: -6)
    }

    private func sampleGridPoints(in region: CGRect) -> [CGPoint] {
        var result: [CGPoint] = []
        let columns = 3, rows = 3
        for column in 0..<columns {
            for row in 0..<rows {
                let x = region.minX + region.width * (CGFloat(column) + 0.5) / CGFloat(columns)
                let y = region.minY + region.height * (CGFloat(row) + 0.5) / CGFloat(rows)
                result.append(ScreenCaptureService.toCGPoint(CGPoint(x: x, y: y)))
            }
        }
        return result
    }

    // MARK: - 提示与权限

    private func showHUD(title: String, detail: String) {
        guard showRecognitionHUD else { return }
        RecognitionHUD.shared.show(title: title, detail: detail, near: currentPoints.last)
    }

    private func ensureScreenRecordingPermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        return false
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "需要「辅助功能」权限"
        alert.informativeText = "magicallyEncircle 需要辅助功能权限来全局监听 Option + 鼠标左键。请在「系统设置 → 隐私与安全性 → 辅助功能」中勾选本应用，然后重新启动应用。"
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "稍后")

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

extension MagicController: InputMonitorDelegate {
    func inputMonitor(_ monitor: InputMonitor, didBeginAt point: CGPoint, at time: TimeInterval) {
        guard isEnabled, let (window, view) = target(for: point) else { return }
        resetStrokeState()
        currentWindow = window
        currentView = view
        currentPoints = [point]
        view.beginStroke(at: window.convertPoint(fromScreen: point), time: time)
    }

    func inputMonitor(_ monitor: InputMonitor, didMoveTo point: CGPoint, at time: TimeInterval) {
        guard isEnabled, let (window, view) = target(for: point) else { return }
        if didCapture { return }

        if window === currentWindow, let currentView {
            currentView.extendStroke(to: window.convertPoint(fromScreen: point), time: time)
        } else {
            currentView?.finishStroke(time: time)
            currentWindow = window
            currentView = view
            view.beginStroke(at: window.convertPoint(fromScreen: point), time: time)
        }

        currentPoints.append(point)
        if !isRecordingGesture, !strokeClosed, Geometry.isClosedLoop(currentPoints) {
            strokeClosed = true
            startHoldTimer()
        }
    }

    func inputMonitor(_ monitor: InputMonitor, didEndAt point: CGPoint, at time: TimeInterval) {
        guard let view = currentView, let window = currentWindow else {
            resetStrokeState()
            return
        }

        if window.targetScreen.frame.contains(point) {
            view.extendStroke(to: window.convertPoint(fromScreen: point), time: time)
            currentPoints.append(point)
        }

        holdTimer?.invalidate()
        holdTimer = nil
        view.finishStroke(time: time)

        if isRecordingGesture {
            saveRecordedGesture(currentPoints)
        } else if !didCapture {
            // 用户自己录制的图案优先级最高：匹配上就直接执行绑定快捷键，
            // 不再被「闭环=复制」或「滑动=内置动作」抢走。
            if let customMatch = GestureRecognizer.shared.matchCustom(currentPoints, custom: customInputs()),
               customMatch.score >= symbolThreshold {
                performCustomGesture(customMatch.id, score: customMatch.score)
            } else if strokeClosed {
                performLassoCopy()
            } else {
                performSymbolGesture(currentPoints)
            }
        }

        currentView = nil
        currentWindow = nil
        resetStrokeState()
    }
}
