//
//  MagicController.swift
//  magicallyEncircle
//

import AppKit
import ApplicationServices
import Combine
import UniformTypeIdentifiers

/// 正在等待绑定快捷键的目标（自定义图案或内置图案）。
enum BindingTarget: Equatable {
    case custom(UUID)
    case builtIn(String)
}

/// 全局协调器：覆盖层管理、输入监听、手势识别、动作执行、自定义手势与权限。
final class MagicController: NSObject, ObservableObject {
    static let shared = MagicController()

    @Published var isEnabled: Bool = true {
        didSet { monitor.isEnabled = isEnabled }
    }

    @Published var style: MagicStyle = MagicStyle.current {
        didSet {
            applyStyle()
            MagicStyle.current = style
        }
    }

    @Published var showRecognitionHUD: Bool = true
    @Published private(set) var isRecordingGesture = false
    @Published private(set) var customGestures: [CustomGesture] = []
    @Published private(set) var pendingBindingTarget: BindingTarget?
    @Published private(set) var pendingKeyDisplay: String?
    @Published private(set) var builtInShortcuts: [String: BuiltInShortcut] = [:]
    @Published private(set) var gestureOverrides: [String: [[[CodablePoint]]]] = [:]
    @Published private(set) var recordingBuiltInID: String?
    @Published private(set) var closeAction: CloseAction = CloseAction.current
    @Published private(set) var multiStrokeMode: MultiStrokeMode = MultiStrokeMode.current
    @Published private(set) var playbackSpeed: Double = PlaybackSpeed.current
    @Published private(set) var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    @Published private(set) var autoCheckUpdates: Bool = UpdateChecker.autoCheckEnabled

    private let monitor = InputMonitor()
    private let store = CustomGestureStore()
    private let overrideStore = GestureOverrideStore()
    private let builtInShortcutStore = BuiltInShortcutStore()
    private let patternPlayer = PatternPlayer()

    private var windows: [OverlayWindow] = []
    private var currentView: MagicCanvasView?
    private var currentWindow: OverlayWindow?

    private var currentPoints: [CGPoint] = []
    private var multiStrokePoints: [[CGPoint]] = []
    private var strokeClosed = false
    private var holdTimer: Timer?
    private var didCapture = false
    private var started = false

    private var pendingKeyCode: UInt16?
    private var pendingModifiers: CGEventFlags = []
    private var previewCache: [UUID: NSImage] = [:]

    private let holdDuration: TimeInterval = 1.0
    private let symbolThreshold: Double = 0.72
    private let customThreshold: Double = 0.75

    private override init() {
        super.init()
        customGestures = store.load()
        gestureOverrides = overrideStore.load()
        builtInShortcuts = builtInShortcutStore.load()
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

        if autoCheckUpdates {
            UpdateChecker.shared.check(manual: false)
        }
    }

    func stop() {
        monitor.stop()
        patternPlayer.cancel()
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
        recordingBuiltInID = nil
        isRecordingGesture = true
        showHUD(title: "记录图案中", detail: "用 Option+左键画一个图案，松手即保存")
    }

    func cancelRecordingGesture() {
        isRecordingGesture = false
        showHUD(title: "已取消记录", detail: "")
    }

    // MARK: - 内置手势图案覆盖

    func beginRecordingBuiltInOverride(_ id: String) {
        guard let builtIn = BuiltInGesture.find(id) else { return }
        cancelPendingBinding()
        isRecordingGesture = false
        recordingBuiltInID = id
        showHUD(title: "录制「\(builtIn.title)」的图案", detail: "用 Option+左键画一个图案，松手保存")
    }

    func cancelRecordingBuiltInOverride() {
        recordingBuiltInID = nil
    }

    private func saveBuiltInOverride(_ id: String, strokes: [[CGPoint]]) {
        recordingBuiltInID = nil
        let valid = strokes.filter { $0.count >= 2 }
        let totalLength = valid.reduce(CGFloat(0)) { $0 + Geometry.pathLength($1) }
        guard !valid.isEmpty, totalLength > 30 else {
            showHUD(title: "图案太短", detail: "请重新录制")
            return
        }
        var list = gestureOverrides[id] ?? []
        list.append(valid.map { $0.map(CodablePoint.init) })
        gestureOverrides[id] = list
        overrideStore.save(gestureOverrides)
        let title = BuiltInGesture.find(id)?.title ?? id
        showHUD(title: "已更新「\(title)」", detail: "现在有 \(list.count) 份自定义图案")
    }

    func resetBuiltInOverride(_ id: String) {
        guard gestureOverrides[id] != nil else { return }
        gestureOverrides[id] = nil
        overrideStore.save(gestureOverrides)
        let title = BuiltInGesture.find(id)?.title ?? id
        showHUD(title: "已恢复默认", detail: title)
    }

    func resetAllBuiltInOverrides() {
        guard !gestureOverrides.isEmpty else { return }
        gestureOverrides.removeAll()
        overrideStore.save(gestureOverrides)
        showHUD(title: "已全部恢复默认图案", detail: "")
    }

    func hasOverride(_ id: String) -> Bool {
        !(gestureOverrides[id]?.isEmpty ?? true)
    }

    func overrideCount(_ id: String) -> Int {
        gestureOverrides[id]?.count ?? 0
    }

    func hasBuiltInShortcutOverride(_ id: String) -> Bool {
        builtInShortcuts[id] != nil
    }

    func effectiveShortcutDisplay(forID id: String) -> String {
        if let override = builtInShortcuts[id] { return override.keyDisplay }
        return BuiltInGesture.find(id)?.action.shortcut?.display ?? ""
    }

    /// 恢复某个内置图案的默认（图案 + 快捷键）。
    func resetBuiltIn(_ id: String) {
        gestureOverrides[id] = nil
        builtInShortcuts[id] = nil
        overrideStore.save(gestureOverrides)
        builtInShortcutStore.save(builtInShortcuts)
        showHUD(title: "已恢复默认", detail: BuiltInGesture.find(id)?.title ?? id)
    }

    // MARK: - 设置窗口

    func setBuiltInOverride(_ id: String, strokes: [[CGPoint]]) {
        saveBuiltInOverride(id, strokes: strokes)
    }

    func addCustomGesture(name: String, strokes: [[CGPoint]]) {
        let valid = strokes.filter { $0.count >= 2 }
        guard !valid.isEmpty else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "图案\(customGestures.count + 1)" : uniqueName(trimmed)
        customGestures.append(CustomGesture(name: resolved, strokes: valid))
        persist()
    }

    func setCloseAction(_ action: CloseAction) {
        closeAction = action
        CloseAction.current = action
    }

    func setMultiStrokeMode(_ mode: MultiStrokeMode) {
        multiStrokeMode = mode
        MultiStrokeMode.current = mode
    }

    func setPlaybackSpeed(_ speed: Double) {
        playbackSpeed = speed
        PlaybackSpeed.current = speed
    }

    func setAutoCheckUpdates(_ enabled: Bool) {
        autoCheckUpdates = enabled
        UpdateChecker.autoCheckEnabled = enabled
    }

    func checkForUpdates() {
        UpdateChecker.shared.check(manual: true)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        if LaunchAtLogin.setEnabled(enabled) {
            launchAtLoginEnabled = enabled
        } else {
            launchAtLoginEnabled = LaunchAtLogin.isEnabled
            showHUD(title: "设置开机自启动失败", detail: "请把 App 放到「应用程序」后再试")
        }
    }

    // MARK: - 绑定 App

    func beginAppBinding(_ id: UUID) {
        guard let gesture = customGestures.first(where: { $0.id == id }), !gesture.isShortcutBound else { return }

        let panel = NSOpenPanel()
        panel.title = "选择要打开的 App（可多选）"
        panel.prompt = "绑定"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK else { return }

        let bundleIDs = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        bindApps(bundleIDs, to: id)
    }

    func bindApps(_ bundleIDs: [String], to id: UUID) {
        guard let index = customGestures.firstIndex(where: { $0.id == id }) else { return }
        customGestures[index].appBundleIDs = bundleIDs.isEmpty ? nil : bundleIDs
        customGestures[index].keyCode = nil
        customGestures[index].modifierFlags = 0
        customGestures[index].keyDisplay = ""
        if pendingBindingTarget == .custom(id) { cancelPendingBinding() }
        persist()
        if !bundleIDs.isEmpty {
            showHUD(title: customGestures[index].name, detail: "已绑定 " + bundleIDs.map(appDisplayName).joined(separator: "、"))
        }
    }

    func clearBinding(_ id: UUID) {
        guard let index = customGestures.firstIndex(where: { $0.id == id }) else { return }
        customGestures[index].appBundleIDs = nil
        customGestures[index].keyCode = nil
        customGestures[index].modifierFlags = 0
        customGestures[index].keyDisplay = ""
        if pendingBindingTarget == .custom(id) { cancelPendingBinding() }
        persist()
        showHUD(title: customGestures[index].name, detail: "已清除绑定")
    }

    func bindingSummary(for gesture: CustomGesture) -> String {
        if gesture.isShortcutBound { return gesture.keyDisplay }
        if gesture.isAppBound {
            return "打开 " + (gesture.appBundleIDs ?? []).map(appDisplayName).joined(separator: "、")
        }
        return "未绑定"
    }

    /// App 的展示名；找不到（已卸载）时回退为 Bundle Identifier。
    func appDisplayName(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        let name = FileManager.default.displayName(atPath: url.path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// 打开 App。已运行则激活（无窗口时由系统 reopen 打开一个窗口）；
    /// 返回成功打开与「不存在」的 bundle id。
    private func openApps(_ bundleIDs: [String]) -> (opened: [String], missing: [String]) {
        var opened: [String] = []
        var missing: [String] = []

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false

        for bundleID in bundleIDs {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
                missing.append(bundleID)
                continue
            }
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            opened.append(bundleID)
        }
        return (opened, missing)
    }

    // MARK: - 图案播放

    func playBuiltIn(_ id: String) {
        guard let builtIn = BuiltInGesture.find(id) else { return }
        if let first = gestureOverrides[id]?.first {
            playPattern(first.map { $0.map { $0.cgPoint } })
        } else if let first = builtIn.defaultSamples.first {
            playPattern(first)
        }
    }

    func playCustomGesture(_ id: UUID) {
        guard let gesture = customGestures.first(where: { $0.id == id }) else { return }
        playPattern(gesture.strokesCG)
    }

    func playPattern(_ strokes: [[CGPoint]]) {
        let valid = strokes.filter { $0.count >= 2 }
        guard !valid.isEmpty else { return }

        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main,
              let window = windows.first(where: { $0.targetScreen === screen }) ?? windows.first else { return }

        let all = valid.flatMap { $0 }
        let box = Geometry.boundingBox(all)
        let maxDimension = max(box.width, box.height, 1)
        let targetSize = min(screen.frame.width, screen.frame.height) * 0.35
        let scale = targetSize / maxDimension
        let center = CGPoint(x: screen.frame.midX, y: screen.frame.midY)
        let patternCenter = CGPoint(x: box.midX, y: box.midY)

        let mapped = valid.map { stroke in
            stroke.map { point in
                window.convertPoint(fromScreen: CGPoint(
                    x: center.x + (point.x - patternCenter.x) * scale,
                    y: center.y + (point.y - patternCenter.y) * scale
                ))
            }
        }

        patternPlayer.play(strokes: mapped, on: window.canvasView, speed: playbackSpeed)
    }

    private func saveRecordedGesture(_ strokes: [[CGPoint]]) {
        isRecordingGesture = false
        let valid = strokes.filter { $0.count >= 2 }
        let totalLength = valid.reduce(CGFloat(0)) { $0 + Geometry.pathLength($1) }
        guard !valid.isEmpty, totalLength > 30 else {
            showHUD(title: "图案太短", detail: "请重新记录")
            return
        }
        let gesture = CustomGesture(name: "图案\(customGestures.count + 1)", strokes: valid)
        customGestures.append(gesture)
        persist()
        let kind = valid.count > 1 ? "（\(valid.count) 笔）" : ""
        showHUD(title: "已保存 \(gesture.name)\(kind)", detail: "到菜单「自定义图案」绑定快捷键")
    }

    // MARK: - 快捷键绑定

    func beginKeyBinding(for id: UUID) {
        guard let gesture = customGestures.first(where: { $0.id == id }), !gesture.isAppBound else { return }
        isRecordingGesture = false
        pendingBindingTarget = .custom(id)
        pendingKeyCode = nil
        pendingModifiers = []
        pendingKeyDisplay = nil
        monitor.startKeyCapture()
        showHUD(title: "请按下快捷键", detail: "需包含一个普通按键；按完回菜单点「保存绑定」")
    }

    func beginBuiltInKeyBinding(_ id: String) {
        guard let builtIn = BuiltInGesture.find(id), builtIn.action.isShortcutRebindable else { return }
        isRecordingGesture = false
        recordingBuiltInID = nil
        pendingBindingTarget = .builtIn(id)
        pendingKeyCode = nil
        pendingModifiers = []
        pendingKeyDisplay = nil
        monitor.startKeyCapture()
        showHUD(title: "为「\(builtIn.title)」设置快捷键", detail: "按完回菜单点「保存绑定」")
    }

    func commitPendingBinding() {
        guard let target = pendingBindingTarget, let keyCode = pendingKeyCode else { return }
        let modifiers = pendingModifiers
        let display = pendingKeyDisplay ?? ""

        switch target {
        case .custom(let id):
            guard let index = customGestures.firstIndex(where: { $0.id == id }) else {
                cancelPendingBinding()
                return
            }
            customGestures[index].keyCode = keyCode
            customGestures[index].modifierFlags = modifiers.rawValue
            customGestures[index].keyDisplay = display
            customGestures[index].appBundleIDs = nil
            persist()
            let name = customGestures[index].name
            cancelPendingBinding()
            showHUD(title: "已绑定", detail: "\(name) → \(display)")

        case .builtIn(let id):
            builtInShortcuts[id] = BuiltInShortcut(keyCode: keyCode, modifierFlags: modifiers.rawValue, keyDisplay: display)
            builtInShortcutStore.save(builtInShortcuts)
            let title = BuiltInGesture.find(id)?.title ?? id
            cancelPendingBinding()
            showHUD(title: "已绑定", detail: "\(title) → \(display)")
        }
    }

    func cancelPendingBinding() {
        pendingBindingTarget = nil
        pendingKeyCode = nil
        pendingModifiers = []
        pendingKeyDisplay = nil
        monitor.endKeyCapture()
    }

    private func handleCapturedKey(keyCode: UInt16, flags: CGEventFlags) {
        guard pendingBindingTarget != nil else { return }
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
        alert.informativeText = "为这个图案起个名字"
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
        if pendingBindingTarget == .custom(id) {
            cancelPendingBinding()
        }
        persist()
    }

    func previewImage(for gesture: CustomGesture) -> NSImage? {
        if let cached = previewCache[gesture.id] { return cached }
        guard let image = Self.makePreview(strokes: gesture.strokesCG) else { return nil }
        previewCache[gesture.id] = image
        return image
    }

    private func persist() {
        store.save(customGestures)
    }

    // MARK: - 导入 / 导出

    func exportGestures() {
        guard !customGestures.isEmpty || !gestureOverrides.isEmpty else {
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
            let package = GesturePackage(
                version: 1,
                gestures: customGestures,
                builtInOverrides: gestureOverrides.isEmpty ? nil : gestureOverrides
            )
            let data = try encoder.encode(package)
            try data.write(to: url)
            let overrideCount = gestureOverrides.values.reduce(0) { $0 + $1.count }
            showHUD(title: "已导出图案", detail: "\(customGestures.count) 个自定义 + \(overrideCount) 份内置覆盖")
        } catch {
            showHUD(title: "导出失败", detail: error.localizedDescription)
        }
    }

    func importGestures() {
        let panel = NSOpenPanel()
        panel.title = "导入图案"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let package = try JSONDecoder().decode(GesturePackage.self, from: data)

            var count = 0
            for imported in package.gestures {
                var gesture = CustomGesture(name: uniqueName(imported.name), strokes: imported.strokesCG)
                gesture.keyCode = imported.keyCode
                gesture.modifierFlags = imported.modifierFlags
                gesture.keyDisplay = imported.keyDisplay
                customGestures.append(gesture)
                count += 1
            }
            persist()

            if let overrides = package.builtInOverrides {
                for (id, samples) in overrides {
                    var list = gestureOverrides[id] ?? []
                    list.append(contentsOf: samples)
                    gestureOverrides[id] = list
                    count += samples.count
                }
                overrideStore.save(gestureOverrides)
            }

            showHUD(title: "已导入图案", detail: "\(count) 个图案")
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

    private static func makePreview(strokes: [[CGPoint]], size: CGFloat = 18) -> NSImage? {
        let valid = strokes.filter { $0.count >= 2 }
        let allPoints = valid.flatMap { $0 }
        guard allPoints.count >= 2 else { return nil }

        let box = Geometry.boundingBox(allPoints)
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

        NSColor.black.setStroke()
        // 每一笔单独绘制，还原用户实际的画法（抬笔断开）。
        for stroke in valid {
            let path = NSBezierPath()
            for (index, point) in stroke.enumerated() {
                let mapped = NSPoint(x: offsetX + (point.x - box.minX) * scale,
                                     y: offsetY + (point.y - box.minY) * scale)
                if index == 0 {
                    path.move(to: mapped)
                } else {
                    path.line(to: mapped)
                }
            }
            path.lineWidth = 1.6
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }

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

    private func customCandidates() -> [GestureCandidate] {
        // 只有「已绑定」（快捷键或 App）的自定义图案才参与匹配；
        // 未绑定的（例如录制备用的样本）不参与，避免挡住内置动作。
        customGestures.filter { $0.isBound }.map {
            GestureCandidate(name: $0.name, strokes: $0.strokesCG, action: nil, customID: $0.id)
        }
    }

    private func builtInCandidates() -> [GestureCandidate] {
        var result: [GestureCandidate] = []
        for builtIn in BuiltInGesture.all {
            if let override = gestureOverrides[builtIn.id], !override.isEmpty {
                for sample in override {
                    result.append(GestureCandidate(name: builtIn.title, strokes: sample.map { $0.map { $0.cgPoint } }, action: builtIn.action, customID: nil))
                }
            } else {
                for sample in builtIn.defaultSamples {
                    result.append(GestureCandidate(name: builtIn.title, strokes: sample, action: builtIn.action, customID: nil))
                }
            }
        }
        return result
    }

    private func handleRecognizedStrokes(_ strokes: [[CGPoint]]) {
        let candidates = customCandidates() + builtInCandidates()
        let ranked = GestureRecognizer.shared.ranked(strokes, candidates: candidates)
        let ranking = Self.rankingText(ranked)

        // 1) 明确的直线滑动优先：直线就该走内置滑动，
        //    避免被"钩子"之类的自定义图案抢走。多笔画不参与滑动判断。
        if strokes.count == 1, let direction = Geometry.swipeDirection(strokes[0]),
           let builtIn = BuiltInGesture.all.first(where: { $0.defaultSwipe == direction && !hasOverride($0.id) }) {
            performBuiltIn(builtIn.action, extra: "滑动\n\(ranking)")
            return
        }

        // 2) 已绑定快捷键的自定义图案。
        if let custom = ranked.first(where: { $0.candidate.customID != nil }), custom.score >= customThreshold {
            performCustomGesture(custom.candidate.customID!, score: custom.score, ranking: ranking)
            return
        }

        // 3) 闭合圈 → 复制圈内文本。
        if strokeClosed {
            performLassoCopy()
            return
        }

        // 4) 内置图案。
        if let builtIn = ranked.first(where: { $0.candidate.action != nil }),
           builtIn.score >= symbolThreshold,
           let action = builtIn.candidate.action {
            performBuiltIn(action, extra: String(format: "%@ %.0f%%\n%@", builtIn.candidate.name, builtIn.score * 100, ranking))
            return
        }

        showHUD(title: "未识别图案", detail: ranking.isEmpty ? "无候选图案" : ranking)
    }

    /// 调试用：把候选按分数从高到低列出（同名只保留最高分）。
    private static func rankingText(_ ranked: [(candidate: GestureCandidate, score: Double)], limit: Int = 5) -> String {
        var seen = Set<String>()
        var lines: [String] = []
        for entry in ranked {
            let name = entry.candidate.name
            if seen.contains(name) { continue }
            seen.insert(name)
            lines.append(String(format: "%@  %.0f%%", name, entry.score * 100))
            if lines.count >= limit { break }
        }
        return lines.joined(separator: "\n")
    }

    private func performCustomGesture(_ id: UUID, score: Double, ranking: String = "") {
        guard let gesture = customGestures.first(where: { $0.id == id }) else { return }
        let percent = Int((score * 100).rounded())

        if gesture.isAppBound {
            let ids = gesture.appBundleIDs ?? []
            let (opened, missing) = openApps(ids)
            if showRecognitionHUD {
                var parts: [String] = []
                if !opened.isEmpty { parts.append("打开 " + opened.map(appDisplayName).joined(separator: "、")) }
                if !missing.isEmpty { parts.append(missing.map(appDisplayName).joined(separator: "、") + " 不存在") }
                parts.append("匹配 \(percent)%")
                showHUD(title: gesture.name, detail: parts.joined(separator: " · "))
            }
            return
        }

        guard let keyCode = gesture.keyCode else {
            showHUD(title: gesture.name, detail: "未绑定")
            return
        }
        let shortcut = KeyShortcut(
            keyCode: keyCode,
            flags: CGEventFlags(rawValue: gesture.modifierFlags),
            display: gesture.keyDisplay
        )
        shortcut.send()
        let head = "\(gesture.keyDisplay) · 匹配 \(percent)%"
        showHUD(title: gesture.name, detail: ranking.isEmpty ? head : "\(head)\n\(ranking)")
    }

    private func performBuiltIn(_ action: GestureAction, extra: String) {
        let builtIn = BuiltInGesture.all.first { $0.action == action }
        if let id = builtIn?.id, let override = builtInShortcuts[id] {
            // 用户换绑过的快捷键。
            KeyShortcut(keyCode: override.keyCode, flags: CGEventFlags(rawValue: override.modifierFlags), display: override.keyDisplay).send()
        } else {
            action.perform()
        }

        var detail = builtIn.map { effectiveShortcutDisplay(forID: $0.id) } ?? (action.shortcut?.display ?? "")
        if !extra.isEmpty {
            detail += detail.isEmpty ? extra : "   " + extra
        }
        showHUD(title: action.title, detail: detail)
    }

    // MARK: - 圈选动作

    private func performLassoCapture() {
        guard !didCapture, !isRecordingGesture, recordingBuiltInID == nil, !currentPoints.isEmpty else { return }
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
        patternPlayer.cancel()
        resetStrokeState()
        if monitor.isMultiStrokeSession {
            view.pinsStrokes = true
        } else {
            multiStrokePoints.removeAll()
            view.pinsStrokes = false
        }
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
        // 闭合圈检测在两种多笔模式下都生效（圈选复制/截图是独立手势）。
        if !isRecordingGesture, recordingBuiltInID == nil,
           !strokeClosed, Geometry.isClosedLoop(currentPoints) {
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

        if didCapture {
            // 已在按住期间完成截图。
        } else if monitor.isMultiStrokeSession {
            // 多笔模式：闭合圈仍按「圈选复制」处理；其余笔画先攒着，等松开 Option 再识别。
            if strokeClosed {
                performLassoCopy()
            } else if currentPoints.count >= 2 {
                multiStrokePoints.append(currentPoints)
            }
        } else if isRecordingGesture {
            saveRecordedGesture([currentPoints])
        } else if let builtInID = recordingBuiltInID {
            saveBuiltInOverride(builtInID, strokes: [currentPoints])
        } else {
            handleRecognizedStrokes([currentPoints])
        }

        currentView = nil
        currentWindow = nil
        resetStrokeState()
    }

    func inputMonitorDidReleaseModifier(_ monitor: InputMonitor) {
        let strokes = multiStrokePoints
        multiStrokePoints.removeAll()

        let now = ProcessInfo.processInfo.systemUptime
        windows.forEach {
            $0.canvasView.pinsStrokes = false
            $0.canvasView.releasePinnedStrokes(time: now)
        }

        guard !strokes.isEmpty else { return }

        if isRecordingGesture {
            saveRecordedGesture(strokes)
        } else if let builtInID = recordingBuiltInID {
            saveBuiltInOverride(builtInID, strokes: strokes)
        } else {
            handleRecognizedStrokes(strokes)
        }
    }
}
