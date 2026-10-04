//
//  RecognitionHUD.swift
//  magicallyEncircle
//

import AppKit
import SwiftUI

final class HUDState: ObservableObject {
    @Published var title = ""
    @Published var detail = ""
}

struct HUDView: View {
    @ObservedObject var state: HUDState

    var body: some View {
        VStack(spacing: 3) {
            Text(state.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            if !state.detail.isEmpty {
                Text(state.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15))
        )
        .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
        .fixedSize()
    }
}

/// 屏幕下方的识别反馈 HUD，可开关。
final class RecognitionHUD {
    static let shared = RecognitionHUD()

    private let state = HUDState()
    private var panel: NSPanel?
    private var hideWorkItem: DispatchWorkItem?

    private init() {
        buildPanel()
    }

    private func buildPanel() {
        let hosting = NSHostingView(rootView: HUDView(state: state))
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 64),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.contentView = hosting
        self.panel = panel
    }

    func show(title: String, detail: String = "", near point: CGPoint? = nil, duration: TimeInterval = 1.4) {
        state.title = title
        state.detail = detail
        guard let panel else { return }

        panel.contentView?.layoutSubtreeIfNeeded()
        let size = panel.contentView?.fittingSize ?? NSSize(width: 240, height: 64)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(point ?? .zero) }) ?? NSScreen.main
        let frame = screen?.frame ?? .zero
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.minY + 120)

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let panel = self.panel else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }
}
