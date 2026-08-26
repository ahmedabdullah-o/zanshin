import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

/// Owns the NSStatusItem and the popover that hosts the timer UI.
///
/// Replaces `MenuBarExtra` because the original Onigiri opens its interface
/// automatically when a session finishes — which requires programmatic
/// open/close that MenuBarExtra does not offer.
@MainActor
final class StatusBarController: NSObject {

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let model: TimerModel
    private var cancellables: Set<AnyCancellable> = []
    private var globalMonitor: Any?
    private var floatingDisplay: FloatingDisplayController?

    // Global hotkey (⌥⌘T)
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let hotKeyBox = HotKeyBox()

    init(model: TimerModel) {
        self.model = model
        super.init()

        let hosting = PanelHostingView(
            rootView: TimerView(model: model),
            onClose: { [weak self] in self?.closeWindow() }
        )
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .applicationDefined // closed via our event monitors / Esc
        popover.animates = true

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleButtonClick)
            button.toolTip = "Zanshin — left-click to open, right-click for quick actions"
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        model.onFinish = { [weak self] in self?.openWindow() }

        model.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.renderMenuBar() }
            .store(in: &cancellables)

        model.$isFloatingDisplayOn
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncFloatingDisplay() }
            .store(in: &cancellables)

        installEventMonitors()
        installGlobalHotKey()
        syncFloatingDisplay()
        renderMenuBar()
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
        Unmanaged<HotKeyBox>.passUnretained(hotKeyBox).release()
    }

    // MARK: Window control

    func openWindow() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func closeWindow() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private func toggleWindow() {
        popover.isShown ? closeWindow() : openWindow()
    }

    // MARK: Status item button

    /// Left-click toggles the panel; right-click (or ⌘-click) opens a quick
    /// action menu so timers can be started without opening the panel.
    @objc private func handleButtonClick() {
        guard let event = NSApp.currentEvent else {
            toggleWindow()
            return
        }
        let wantsMenu = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if wantsMenu {
            let menu = buildQuickMenu()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggleWindow()
        }
    }

    private func buildQuickMenu() -> NSMenu {
        let menu = NSMenu()

        let toggleTitle: String
        switch model.state {
        case .running: toggleTitle = "Pause"
        case .paused: toggleTitle = "Resume"
        case .done where model.suggestedNext == .rest:
            toggleTitle = "Tea break · \(Int(model.breakMinutes))m"
        default: toggleTitle = "Begin practice"
        }
        menu.addItem(item(toggleTitle, #selector(quickToggle)))

        menu.addItem(item("Reset", #selector(quickReset)))
        menu.addItem(.separator())

        for value in model.presets {
            menu.addItem(item("\(value) minutes", #selector(quickPreset(_:)), represented: value))
        }
        menu.addItem(.separator())

        let teaItem = item("Tea break · \(Int(model.breakMinutes))m", #selector(quickBreak))
        menu.addItem(teaItem)

        let floatItem = item(
            model.isFloatingDisplayOn ? "Hide Floating Display" : "Show Floating Display",
            #selector(quickToggleFloating)
        )
        menu.addItem(floatItem)

        menu.addItem(.separator())
        menu.addItem(item("Quit Zanshin", #selector(quickQuit)))

        return menu
    }

    private func item(_ title: String, _ action: Selector, represented: Int? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.representedObject = represented.map(NSNumber.init(value:))
        return item
    }

    @objc private func quickToggle() { model.toggleStartPause() }
    @objc private func quickReset() { model.reset() }
    @objc private func quickBreak() { model.startBreak() }

    @objc private func quickPreset(_ sender: NSMenuItem) {
        guard let number = sender.representedObject as? NSNumber else { return }
        model.applyPreset(number.intValue)
    }

    @objc private func quickToggleFloating() {
        model.isFloatingDisplayOn.toggle()
    }

    @objc private func quickQuit() {
        NSApp.terminate(nil)
    }

    // MARK: Event monitors

    /// Outside-click dismissal is handled by the global monitor (clicks into
    /// other apps). Local clicks — the popover itself, its menus, the status
    /// item, the floating panel — must all pass through untouched so their
    /// controls keep working.
    private func installEventMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.closeWindow() }
        }
    }

    // MARK: Global hotkey (⌥⌘T)

    private func installGlobalHotKey() {
        hotKeyBox.controller = self

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: OSType(kEventHotKeyPressed)
        )
        let hotKeyID = EventHotKeyID(signature: OSType(0x4F_47_52_31) /* "OGR1" */, id: 1)
        let boxPointer = Unmanaged.passRetained(hotKeyBox).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var id = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                if id.id == 1 {
                    let box = Unmanaged<HotKeyBox>.fromOpaque(userData).takeUnretainedValue()
                    Task { @MainActor in
                        box.controller?.toggleWindow()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            boxPointer,
            &eventHandlerRef
        )

        RegisterEventHotKey(
            UInt32(kVK_ANSI_T),
            UInt32(optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    // MARK: Floating Display

    private func syncFloatingDisplay() {
        guard model.isFloatingDisplayOn else {
            floatingDisplay?.hide()
            return
        }
        if floatingDisplay == nil {
            floatingDisplay = FloatingDisplayController(model: model)
        }
        floatingDisplay?.show()
    }

    // MARK: Menu bar rendering

    private func renderMenuBar() {
        guard let button = statusItem.button else { return }

        let title: String
        switch model.state {
        case .running, .paused: title = model.formattedTime
        case .done: title = "Strike!"
        case .idle: title = ""
        }

        // Menu-bar marks: blank ensō when waiting, katana while practicing,
        // tea cup during breaks, hanko seal when practice completes.
        let glyph: NSImage
        switch model.state {
        case .done: glyph = ZanshinGlyph.seal()
        case .running, .paused: glyph = model.kind == .rest ? ZanshinGlyph.tea() : ZanshinGlyph.katana()
        case .idle: glyph = model.isHighContrastIcon ? ZanshinGlyph.seal() : ZanshinGlyph.enso()
        }
        button.image = glyph
        button.image?.size = NSSize(width: 16, height: 16)

        // Tea breaks read green in the menu bar, done reads crimson.
        if model.state == .done {
            button.contentTintColor = .systemRed
        } else if model.kind == .rest && model.state != .idle {
            button.contentTintColor = .systemGreen
        } else {
            button.contentTintColor = nil
        }

        let weight: NSFont.Weight = model.isHighContrastIcon ? .semibold : .regular
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: weight)
        ]
        button.attributedTitle = NSAttributedString(string: title, attributes: attributes)
    }
}

/// Objective-C-reachable holder for the hotkey target; C callbacks can't
/// capture Swift context, so the controller rides through a void pointer.
private final class HotKeyBox {
    weak var controller: StatusBarController?
}

/// Hosting controller that closes the popover when the user presses Esc.
private final class PanelHostingView<Content: View>: NSHostingController<Content> {
    private let onClose: () -> Void

    init(rootView: Content, onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onClose()
        } else {
            super.keyDown(with: event)
        }
    }
}
