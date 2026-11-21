import AppKit
import SwiftUI

/// A small always-on-top panel showing the remaining time, draggable anywhere
/// and visible across Spaces and fullscreen apps.
@MainActor
final class FloatingDisplayController: NSObject, NSWindowDelegate {

    static let frameKey = "floatingDisplayFrame"

    private let model: TimerModel
    let panel: NSPanel

    init(model: TimerModel) {
        self.model = model

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 148, height: 78),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.appearance = Theme.appearance(prefersDark: model.prefersDarkAppearance)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let hostingView = DraggableHostingView(rootView: FloatingDisplayView(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 148, height: 78)
        panel.contentView = hostingView

        // Right-click hides the panel without opening the main window.
        let menu = NSMenu()
        let hide = NSMenuItem(title: "Hide Floating Display", action: #selector(hideFromMenu), keyEquivalent: "")
        hide.target = self
        menu.addItem(hide)
        hostingView.menu = menu

        restoreFrame()
    }

    @objc private func hideFromMenu() {
        model.isFloatingDisplayOn = false
    }

    func show() {
        restoreFrame()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func restoreFrame() {
        guard let raw = UserDefaults.standard.string(forKey: Self.frameKey),
              !raw.isEmpty else { return }
        panel.setFrameOrigin(NSPointFromString(raw))
    }

    // MARK: NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.frameKey)
    }
}

/// Hosting view whose background drags the borderless panel.
private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

struct FloatingDisplayView: View {
    @ObservedObject var model: TimerModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 5)

            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: model.progress)

            center
        }
        .padding(10)
        .frame(width: 78, height: 78)
        .background(
            Circle()
                .fill(Theme.paper.opacity(0.97))
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        )
        .padding(6) // room for the shadow inside the transparent panel
    }

    private var ringColor: Color {
        model.kind == .rest ? Theme.matcha : model.inkTheme.ringColor
    }

    private var center: some View {
        VStack(spacing: 1) {
            if model.state == .done {
                Text("残心")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(Theme.shu)
            } else {
                Text(model.formattedTime)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .foregroundColor(Theme.ink)
                    .monospacedDigit()
                Text(subtitle)
                    .font(.system(size: 6.5, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.inkSoft)
            }
        }
    }

    private var subtitle: String {
        switch model.state {
        case .idle: return "sheathed"
        case .running: return model.kind == .rest ? "tea" : "zanshin"
        case .paused: return "held"
        case .done: return "strike"
        }
    }
}
