import SwiftUI
import AppKit

struct TimerView: View {
    @ObservedObject var model: TimerModel
    @FocusState private var minutesFieldFocused: Bool
    @State private var sealStamped = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            header

            VStack(spacing: 10) {
                dial
                    .frame(width: 166, height: 166)
                controlsRow
            }
            .paperCard(opacity: 0.91)

            VStack(alignment: .leading, spacing: 10) {
                Text("Practice duration")
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .accessibilityAddTraits(.isHeader)
                sliderRow
                presetsRow
                Divider().overlay(Theme.line)
                inkRow
            }
            .paperCard()

            footerRow
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Theme.paper.opacity(0.65), in: RoundedRectangle(cornerRadius: Theme.controlRadius))
        }
        .padding(16)
        .frame(width: 336)
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .background { ThemeArtwork() }
        .onAppear { sealStamped = model.state == .done }
        .onChange(of: model.state) { oldValue, newValue in
            guard newValue == .done, oldValue != .done else {
                if newValue != .done { sealStamped = false }
                return
            }
            guard !reduceMotion else {
                sealStamped = true
                return
            }
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) {
                sealStamped = false
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55).delay(0.15)) {
                sealStamped = true
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button {
                NSApplication.shared.orderFrontStandardAboutPanel(nil)
            } label: {
                HStack(spacing: 10) {
                    Image(nsImage: ZanshinGlyph.katana(size: 20))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Zanshin")
                            .font(.system(size: 23, weight: .medium, design: .serif))
                            .textCase(.lowercase)
                            .foregroundStyle(Theme.ink)
                        Text("残心")
                            .font(.system(size: 10))
                            .tracking(2)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
            }
            .buttonStyle(ZanshinButtonStyle())
            .accessibilityLabel("About Zanshin")
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(stanceColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(stance)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.paper.opacity(0.88), in: Capsule())
        }
    }

    private var stance: String {
        switch model.state {
        case .idle: return "Sheathed"
        case .running: return model.kind == .rest ? "Tea" : "Drawn"
        case .paused: return "Held"
        case .done: return "Strike!"
        }
    }

    private var stanceColor: Color {
        switch model.state {
        case .running: return model.kind == .rest ? Theme.matcha : Theme.accent
        case .done: return Theme.shu
        case .idle, .paused: return Theme.inkSoft
        }
    }

    // MARK: Ensō dial

    private var ringColor: Color {
        model.kind == .rest ? Theme.matcha : model.inkTheme.ringColor
    }

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(Theme.line, lineWidth: 6)

            Circle()
                .trim(from: 0, to: model.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .linear(duration: 0.25), value: model.progress)

            dialCenter
        }
        .padding(6)
    }

    private var dialCenter: some View {
        VStack(spacing: 4) {
            if model.state == .done {
                hankoSeal
                Text(model.suggestedNext == .rest ? "tea time?" : "practice complete")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.inkSoft)
            } else {
                Text(model.formattedTime)
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 12)
                    .foregroundColor(Theme.ink)
                    .monospacedDigit()
                Text(dialCaption)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(Theme.inkSoft)
            }
        }
    }

    /// The crimson hanko stamp that slams in when practice completes.
    private var hankoSeal: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(Theme.shu)
            .frame(width: 62, height: 62)
            .overlay(
                Text("残心")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Theme.onShu)
            )
            .rotationEffect(.degrees(-4))
            .shadow(color: Theme.shu.opacity(0.35), radius: 6, y: 2)
            .scaleEffect(sealStamped ? 1 : 1.6)
            .opacity(sealStamped ? 1 : 0)
    }

    private var dialCaption: String {
        switch model.state {
        case .running:
            return model.kind == .rest ? "tea steeping" : "zanshin"
        case .paused:
            return "held breath"
        default:
            return "set your practice"
        }
    }

    // MARK: Slider + number entry

    private var sliderRow: some View {
        HStack(spacing: 12) {
            Slider(value: Binding(
                get: { model.minutes },
                set: { model.setMinutes($0) }
            ), in: model.allowedRange, step: 1)
            .disabled(isDurationLocked)
            .opacity(isDurationLocked ? 0.45 : 1)
            .tint(Theme.accent)
            .accessibilityLabel("Practice duration")

            minutesField
        }
    }

    private var minutesField: some View {
        HStack(spacing: 4) {
            TextField("Practice duration", value: Binding(
                get: { model.minutes },
                set: { model.setMinutes($0) }
            ), format: .number.grouping(.never))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .labelsHidden()
            .focused($minutesFieldFocused)
            .onSubmit { minutesFieldFocused = false }

            Text("m")
                .foregroundColor(Theme.inkSoft)
        }
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .frame(width: 58)
        .padding(.vertical, 6)
        .background(Theme.washi, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.controlRadius)
                .strokeBorder(minutesFieldFocused ? Theme.accent : Theme.line)
                .allowsHitTesting(false)
        }
        .disabled(isDurationLocked)
    }

    private var isDurationLocked: Bool {
        model.isActivePresetLocked
    }

    // MARK: Presets

    private var presetsRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(model.presets.enumerated()), id: \.element) { index, value in
                Button {
                    model.applyPreset(value)
                } label: {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isActivePreset(value) ? Theme.accent.opacity(0.13) : Theme.paper)
                        .foregroundColor(isActivePreset(value) ? Theme.accent : Theme.ink)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(isActivePreset(value) ? Theme.accent.opacity(0.45) : Theme.line)
                                .allowsHitTesting(false)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(ZanshinButtonStyle())
                .disabled(model.isActivePresetLocked)
                .opacity(model.isActivePresetLocked ? 0.45 : 1)
                .keyboardShortcutIfEnabled(shortcutsEnabled ? KeyEquivalent(Character("\(index + 1)")) : nil)
                .accessibilityLabel("\(value) minute practice")
                .accessibilityAddTraits(isActivePreset(value) ? .isSelected : [])
            }
        }
    }

    private func isActivePreset(_ value: Int) -> Bool {
        Int(model.minutes) == value && !model.isActivePresetLocked && model.kind == .focus
    }

    // MARK: Ink picker

    private var inkRow: some View {
        HStack(spacing: 10) {
            Text("Ink")
                .font(.system(size: 10, weight: .bold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(Theme.inkSoft)

            ForEach(BladeTheme.allCases) { option in
                Button {
                    model.inkTheme = option
                } label: {
                    Circle()
                        .fill(option.swatch)
                        .frame(width: 13, height: 13)
                        .overlay(
                            Circle().stroke(
                                model.inkTheme == option ? Theme.ink : Theme.line,
                                lineWidth: model.inkTheme == option ? 1.5 : 1
                            )
                            .padding(-3)
                        )
                        .frame(width: 23, height: 23)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ZanshinButtonStyle())
                .disabled(model.isActivePresetLocked)
                .accessibilityLabel("\(option.name) ink")
                .accessibilityAddTraits(model.inkTheme == option ? .isSelected : [])
            }

            Spacer()

            Text(model.inkTheme.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.inkSoft)
        }
    }

    // MARK: Controls

    private var shortcutsEnabled: Bool {
        !minutesFieldFocused
    }

    private var controlsRow: some View {
        HStack(spacing: 14) {
            circleButton(
                systemName: "arrow.counterclockwise",
                label: "Reset practice"
            ) {
                model.reset()
            }
            .keyboardShortcutIfEnabled(shortcutsEnabled ? "r" : nil)

            Button {
                SoundPlayer.stopAlarm()
                model.toggleStartPause()
            } label: {
                Image(systemName: primarySymbol)
                    .font(.system(size: 20))
                    .foregroundColor(primaryForeground)
                    .frame(width: 62, height: 40)
                    .background(primaryBackground, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
            }
            .buttonStyle(ZanshinButtonStyle())
            .keyboardShortcutIfEnabled(shortcutsEnabled ? .space : nil)
            .accessibilityLabel(primaryAccessibilityLabel)

            circleButton(
                systemName: model.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                label: model.isMuted ? "Unmute drum" : "Mute drum"
            ) {
                model.isMuted.toggle()
            }
            .keyboardShortcutIfEnabled(shortcutsEnabled ? "m" : nil)
        }
    }

    private var primaryStartsTea: Bool {
        model.suggestedNext == .rest || model.kind == .rest
    }

    private var primarySymbol: String {
        switch model.state {
        case .running: return "pause.fill"
        case .paused: return "play.fill"
        case .done, .idle: return primaryStartsTea ? "cup.and.saucer.fill" : "play.fill"
        }
    }

    private var primaryBackground: Color {
        switch model.state {
        case .running: return model.kind == .rest ? Theme.matcha : Theme.accent
        case .paused: return model.kind == .rest ? Theme.matcha : Theme.accent
        case .done: return model.suggestedNext == .rest ? Theme.matcha : Theme.shu
        case .idle: return Theme.accent
        }
    }

    private var primaryForeground: Color {
        switch model.state {
        case .running, .paused: return model.kind == .rest ? Theme.onMatcha : Theme.onAccent
        case .done: return model.suggestedNext == .rest ? Theme.onMatcha : Theme.onShu
        case .idle: return Theme.onAccent
        }
    }

    private var primaryAccessibilityLabel: String {
        if model.state == .running { return "Pause" }
        if primaryStartsTea {
            return "Start \(Int(model.breakMinutes)) minute tea break"
        }
        return "Begin practice"
    }

    private func circleButton(
        systemName: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14))
                .foregroundColor(Theme.inkSoft)
                .frame(width: 38, height: 38)
                .background(Theme.paper, in: RoundedRectangle(cornerRadius: Theme.controlRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.controlRadius)
                        .strokeBorder(Theme.line)
                        .allowsHitTesting(false)
                }
        }
        .buttonStyle(ZanshinButtonStyle())
        .accessibilityLabel(label)
    }

    // MARK: Footer

    private var footerRow: some View {
        let isDark = model.prefersDarkAppearance ?? (colorScheme == .dark)
        return HStack(spacing: 10) {
            miniToggle(
                systemName: "pip",
                label: "Floating display",
                isActive: model.isFloatingDisplayOn
            ) {
                model.isFloatingDisplayOn.toggle()
            }

            miniToggle(
                systemName: "circle.lefthalf.filled",
                label: isDark ? "Switch to light appearance" : "Switch to dark appearance",
                isActive: isDark
            ) {
                model.prefersDarkAppearance = !isDark
            }

            miniToggle(
                systemName: "power",
                label: "Launch at login",
                isActive: model.launchAtLogin
            ) {
                model.launchAtLogin.toggle()
            }

            alarmMenu

            Spacer()

            if model.sessionsToday > 0 {
                HStack(spacing: 6) {
                    sparkline
                    Text("\(model.sessionsToday)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.inkSoft)
                }
                .accessibilityLabel("\(model.sessionsToday) sessions today")
            }
        }
    }

    private var alarmMenu: some View {
        Menu {
            Section("Drum") {
                ForEach(SoundPlayer.availableAlarms, id: \.self) { name in
                    Button {
                        model.alarmName = name
                    } label: {
                        if name == model.alarmName {
                            Label(name, systemImage: "checkmark")
                        } else {
                            Text(name)
                        }
                    }
                }
            }
            Section("Tea break length") {
                ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                    Button {
                        model.setBreakMinutes(Double(minutes))
                    } label: {
                        if Int(model.breakMinutes) == minutes {
                            Label("\(minutes) minutes", systemImage: "checkmark")
                        } else {
                            Text("\(minutes) minutes")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 11))
                .foregroundColor(Theme.inkSoft)
                .frame(width: 26, height: 26)
                .background(Theme.paper)
                .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                .clipShape(Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Drum sound: \(model.alarmName)")
    }

    /// Last seven days of completed practice.
    private var sparkline: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<7, id: \.self) { slot in
                let count = model.sessionCount(daysAgo: 6 - slot)
                Capsule()
                    .fill(count > 0 ? Theme.kin : Theme.line)
                    .frame(width: 5, height: CGFloat(4 + min(count, 5) * 3))
            }
        }
    }

    private func miniToggle(systemName: String, label: LocalizedStringKey, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(isActive ? Theme.accent : Theme.inkSoft)
                .frame(width: 26, height: 26)
                .background(isActive ? Theme.accent.opacity(0.13) : Theme.paper)
                .overlay(Circle().strokeBorder(isActive ? Theme.accent.opacity(0.45) : Theme.line))
                .clipShape(Circle())
        }
        .buttonStyle(ZanshinButtonStyle())
        .accessibilityLabel(label)
        .help(Text(label))
    }
}

/// Gentle press feedback shared by every custom button.
struct ZanshinButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

extension View {
    /// Applies a keyboard shortcut only when one is provided; used to suspend
    /// shortcuts while the number field has focus so typing stays clean.
    @ViewBuilder
    func keyboardShortcutIfEnabled(_ key: KeyEquivalent?) -> some View {
        if let key {
            self.keyboardShortcut(key, modifiers: [])
        } else {
            self
        }
    }
}
