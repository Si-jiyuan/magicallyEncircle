//
//  SettingsView.swift
//  magicallyEncircle
//

import AppKit
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case style
    case builtIn
    case custom
    case record

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "通用设置"
        case .style: return "视觉风格"
        case .builtIn: return "内置图案"
        case .custom: return "自定义图案"
        case .record: return "记录图案"
        }
    }

    var icon: String {
        switch self {
        case .style: return "paintpalette"
        case .builtIn: return "square.grid.2x2"
        case .custom: return "hand.draw"
        case .record: return "pencil.tip"
        case .general: return "gearshape"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var controller: MagicController
    @State private var section: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            List(selection: $section) {
                ForEach(SettingsSection.allCases) { item in
                    Label(item.title, systemImage: item.icon).tag(item)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 165)

            Divider()

            ScrollView {
                detail
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 380, minHeight: 320)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .style: StyleSection(controller: controller)
        case .builtIn: BuiltInSection(controller: controller)
        case .custom: CustomSection(controller: controller)
        case .record: RecordSection(controller: controller)
        case .general: GeneralSection(controller: controller)
        }
    }
}

// MARK: - 视觉风格

private struct StyleSection: View {
    @ObservedObject var controller: MagicController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("视觉风格").font(.title2).bold()
            Text("魔法线条的外观样式。").font(.caption).foregroundStyle(.secondary)
            ForEach(MagicStyle.allCases) { style in
                Button {
                    controller.selectStyle(style)
                } label: {
                    HStack {
                        Image(systemName: controller.style == style ? "largecircle.fill.circle" : "circle")
                        Text(style.title)
                        Spacer()
                    }
                    .padding(10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(controller.style == style ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2))
                )
            }
        }
    }
}

// MARK: - 内置图案

private struct BuiltInSection: View {
    @ObservedObject var controller: MagicController
    @State private var recording: BuiltInGesture?
    @State private var strokes: [[CGPoint]] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("内置图案").font(.title2).bold()
            Text("为每个动作录制自己的图案（在画布上画，可多笔画）。").font(.caption).foregroundStyle(.secondary)

            ForEach(BuiltInGesture.all) { builtIn in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(builtIn.title).font(.headline)
                        Text(description(builtIn)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("录制…") {
                        strokes = []
                        recording = builtIn
                    }
                    Button("恢复默认") {
                        controller.resetBuiltInOverride(builtIn.id)
                    }
                    .disabled(controller.overrideCount(builtIn.id) == 0)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
        .sheet(item: $recording) { builtIn in
            RecordSheet(title: builtIn.title, strokes: $strokes) {
                controller.setBuiltInOverride(builtIn.id, strokes: strokes)
                recording = nil
            } onCancel: {
                recording = nil
            }
        }
    }

    private func description(_ builtIn: BuiltInGesture) -> String {
        let count = controller.overrideCount(builtIn.id)
        let trigger: String
        if count > 0 {
            trigger = "自定义 \(count) 份"
        } else if let swipe = builtIn.defaultSwipe {
            trigger = swipeSymbol(swipe) + " 滑动"
        } else if !builtIn.defaultSamples.isEmpty {
            trigger = "默认图案"
        } else {
            trigger = "未设置"
        }
        if let shortcut = builtIn.action.shortcut?.display, !shortcut.isEmpty {
            return "\(shortcut) · \(trigger)"
        }
        return trigger
    }

    private func swipeSymbol(_ direction: SwipeDirection) -> String {
        switch direction {
        case .left: return "←"
        case .right: return "→"
        case .up: return "↑"
        case .down: return "↓"
        }
    }
}

// MARK: - 自定义图案

private struct CustomSection: View {
    @ObservedObject var controller: MagicController
    @State private var selected: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("自定义图案").font(.title2).bold()

            if controller.customGestures.isEmpty {
                Text("还没有自定义图案。到「记录图案」里画一个吧。")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 110, maximum: 200), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(controller.customGestures) { gesture in
                        CustomGestureCard(
                            gesture: gesture,
                            preview: controller.previewImage(for: gesture),
                            isSelected: selected == gesture.id
                        )
                        .onTapGesture { selected = gesture.id }
                    }
                }
                .padding(.vertical, 4)

                if let id = selected, let gesture = controller.customGestures.first(where: { $0.id == id }) {
                    HStack {
                        Button("重命名…") { controller.renameGesture(id) }
                        Button("设置快捷键") { controller.beginKeyBinding(for: id) }
                        Button("删除") {
                            controller.deleteGesture(id)
                            selected = nil
                        }
                    }

                    if controller.pendingBindingID == id {
                        HStack {
                            if let display = controller.pendingKeyDisplay {
                                Text("已捕获 \(display)")
                                Button("保存") { controller.commitPendingBinding() }
                            } else {
                                Text("请在键盘上按下快捷键…").foregroundStyle(.secondary)
                            }
                            Button("取消") { controller.cancelPendingBinding() }
                        }
                    } else if !gesture.keyDisplay.isEmpty {
                        Text("当前快捷键：\(gesture.keyDisplay)").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("选中上方一个图案以设置快捷键或重命名。").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - 记录图案

private struct RecordSection: View {
    @ObservedObject var controller: MagicController
    @State private var strokes: [[CGPoint]] = []
    @State private var name: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("记录图案").font(.title2).bold()
            Text("在下方画布上绘制（无需按 Option，可多笔画），然后保存为自定义图案。")
                .font(.caption)
                .foregroundStyle(.secondary)

            PatternCanvas(strokes: $strokes)
                .frame(minHeight: 220)

            HStack {
                TextField("名称（可选）", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                Button("清空") { strokes = [] }
                Spacer()
                Button("保存为自定义图案") {
                    controller.addCustomGesture(name: name, strokes: strokes)
                    strokes = []
                    name = ""
                }
                .keyboardShortcut(.defaultAction)
                .disabled(strokes.isEmpty)
            }
        }
    }
}

// MARK: - 通用设置

private struct GeneralSection: View {
    @ObservedObject var controller: MagicController

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("通用设置").font(.title2).bold()

            Toggle("启用魔法线条", isOn: $controller.isEnabled)
            Toggle("显示识别反馈", isOn: $controller.showRecognitionHUD)

            Divider()

            Text("「关闭」图案的动作").font(.headline)
            Picker("", selection: Binding(
                get: { controller.closeAction },
                set: { controller.setCloseAction($0) }
            )) {
                ForEach(CloseAction.allCases) { action in
                    Text(action.title).tag(action)
                }
            }
            .labelsHidden()
            Text("识别到「关闭」图案（叉号）时执行上面的动作。图案本身可在「内置图案」里修改。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Text("启用多笔画").font(.headline)
            Picker("", selection: Binding(
                get: { controller.multiStrokeMode },
                set: { controller.setMultiStrokeMode($0) }
            )) {
                ForEach(MultiStrokeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            Text("该选项会替换原本「单击 Option 单笔画」的逻辑；两种模式互不影响。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Button("导入图案…") { controller.importGestures() }
                Button("导出图案…") { controller.exportGestures() }
            }
        }
    }
}

// MARK: - 录制弹窗

private struct RecordSheet: View {
    let title: String
    @Binding var strokes: [[CGPoint]]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("录制「\(title)」图案").font(.headline)
            Text("可多笔画绘制").font(.caption).foregroundStyle(.secondary)
            PatternCanvas(strokes: $strokes)
                .frame(width: 380, height: 240)
            HStack {
                Button("清空") { strokes = [] }
                Spacer()
                Button("取消") { onCancel() }
                Button("保存") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(strokes.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

// MARK: - 自定义图案卡片

private struct CustomGestureCard: View {
    let gesture: CustomGesture
    let preview: NSImage?
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .textBackgroundColor))
                if let preview {
                    Image(nsImage: preview)
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundStyle(.primary)
                }
            }
            .frame(height: 84)
            .frame(maxWidth: .infinity)

            Text(gesture.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(gesture.keyDisplay.isEmpty ? "未绑定" : gesture.keyDisplay)
                .font(.caption)
                .foregroundStyle(gesture.keyDisplay.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - 画布

struct PatternCanvas: View {
    @Binding var strokes: [[CGPoint]]
    @State private var current: [CGPoint] = []

    var body: some View {
        ZStack {
            Rectangle().fill(Color(nsColor: .textBackgroundColor))
            Canvas { context, _ in
                var path = Path()
                for stroke in strokes { append(stroke, to: &path) }
                if current.count >= 1 { append(current, to: &path) }
                context.stroke(
                    path,
                    with: .color(.primary),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .contentShape(Rectangle())
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if let last = current.last, hypot(last.x - value.location.x, last.y - value.location.y) < 1.5 {
                        return
                    }
                    current.append(value.location)
                }
                .onEnded { _ in
                    if current.count >= 2 { strokes.append(current) }
                    current = []
                }
        )
    }

    private func append(_ stroke: [CGPoint], to path: inout Path) {
        guard let first = stroke.first else { return }
        path.move(to: first)
        for point in stroke.dropFirst() {
            path.addLine(to: point)
        }
    }
}
