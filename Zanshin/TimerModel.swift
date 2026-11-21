import Foundation
import Combine
import UserNotifications
import ServiceManagement

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case done
}

enum SessionKind: Equatable {
    case focus
    case rest
}

/// Wall-clock based countdown engine. Truth lives in `endDate`, so the timer
/// never drifts and survives system sleep mid-session.
@MainActor
final class TimerModel: ObservableObject {

    // MARK: Published state

    @Published private(set) var remainingSeconds: Int
    @Published private(set) var state: TimerState = .idle
    /// What is currently loaded/running (focus session or short break).
    @Published private(set) var kind: SessionKind = .focus
    /// What the app suggests after a completed session; drives the one-click
    /// follow-up (e.g. a break right after focus).
    @Published private(set) var suggestedNext: SessionKind?
    /// Exact elapsed fraction of the session, polled several times a second so
    /// the nori wrap animates smoothly instead of jumping once per second.
    @Published private(set) var progress: Double = 0
    @Published private(set) var sessionsToday: Int = 0

    @Published var minutes: Double {
        didSet {
            defaults.set(minutes, forKey: Self.minutesKey)
            guard state == .idle || state == .done else { return }
            if state == .done { state = .idle }
            durationSeconds = Int(minutes) * 60
            remainingSeconds = durationSeconds
            progress = 0
        }
    }
    @Published var breakMinutes: Double {
        didSet { defaults.set(breakMinutes, forKey: Self.breakKey) }
    }
    @Published var isMuted: Bool {
        didSet { defaults.set(isMuted, forKey: Self.mutedKey) }
    }
    @Published var isHighContrastIcon: Bool {
        didSet { defaults.set(isHighContrastIcon, forKey: Self.contrastKey) }
    }
    @Published var prefersDarkAppearance: Bool? {
        didSet { defaults.set(prefersDarkAppearance, forKey: Self.appearanceKey) }
    }
    @Published var isFloatingDisplayOn: Bool {
        didSet { defaults.set(isFloatingDisplayOn, forKey: Self.floatKey) }
    }
    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }
    @Published var inkTheme: BladeTheme {
        didSet { defaults.set(inkTheme.rawValue, forKey: Self.inkThemeKey) }
    }
    @Published var alarmName: String {
        didSet { SoundPlayer.selectedAlarmName = alarmName }
    }

    /// Fired when a session completes; the status-bar controller opens the panel.
    var onFinish: (() -> Void)?

    let presets: [Int] = [5, 15, 25, 45, 60, 90]
    let allowedRange: ClosedRange<Double> = 1...180
    let breakRange: ClosedRange<Double> = 1...30

    private var durationSeconds: Int
    private var endDate: Date?
    private var pausedRemaining: TimeInterval?
    private var ticker: AnyCancellable?
    private var permissionRequested = false

    private let defaults = UserDefaults.standard
    private static let minutesKey = "lastMinutes"
    private static let breakKey = "breakMinutes"
    private static let mutedKey = "isMuted"
    private static let contrastKey = "highContrastIcon"
    private static let appearanceKey = "prefersDarkAppearance"
    private static let floatKey = "floatingDisplayOn"
    private static let loginKey = "launchAtLogin"
    private static let inkThemeKey = "inkTheme"
    private static let savedStateKey = "savedState" // "running" | "paused"
    private static let savedEndDateKey = "savedEndDate"
    private static let savedPausedKey = "savedPausedRemaining"
    private static let savedKindKey = "savedKind"
    private static let savedDurationKey = "savedDuration"

    // MARK: Derived values

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        if m >= 60 {
            return String(format: "%d:%02d:%02d", m / 60, m % 60, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    var isActivePresetLocked: Bool {
        state == .running || state == .paused
    }

    init() {
        let stored = defaults.object(forKey: Self.minutesKey) as? Double
        let resolved = stored.map { min(180, max(1, $0)) } ?? 25
        let storedBreak = defaults.object(forKey: Self.breakKey) as? Double
        let resolvedBreak = storedBreak.map { min(30, max(1, $0)) } ?? 5

        minutes = resolved
        breakMinutes = resolvedBreak
        isMuted = defaults.bool(forKey: Self.mutedKey)
        isHighContrastIcon = defaults.bool(forKey: Self.contrastKey)
        prefersDarkAppearance = defaults.object(forKey: Self.appearanceKey) as? Bool
        isFloatingDisplayOn = defaults.bool(forKey: Self.floatKey)
        launchAtLogin = defaults.bool(forKey: Self.loginKey)
        inkTheme = BladeTheme(rawValue: defaults.string(forKey: Self.inkThemeKey) ?? "") ?? .sumi
        alarmName = SoundPlayer.selectedAlarmName

        durationSeconds = Int(resolved) * 60
        remainingSeconds = durationSeconds
        sessionsToday = defaults.integer(forKey: Self.sessionsKey(for: Date()))
        restoreSavedSession()
    }

    /// A running/paused session survives quitting the app: on relaunch the
    /// countdown picks up exactly where the wall clock says it should.
    private func restoreSavedSession() {
        guard let savedRaw = defaults.string(forKey: Self.savedStateKey) else { return }
        let savedKind: SessionKind = defaults.string(forKey: Self.savedKindKey) == "rest" ? .rest : .focus
        let savedDuration = defaults.integer(forKey: Self.savedDurationKey)

        kind = savedKind
        if savedDuration > 0 { durationSeconds = savedDuration }

        if savedRaw == "running" {
            let end = defaults.double(forKey: Self.savedEndDateKey)
            let remaining = end - Date().timeIntervalSince1970
            if remaining > 0 {
                endDate = Date(timeIntervalSince1970: end)
                remainingSeconds = Int(remaining.rounded(.up))
                state = .running
                startTicker()
                refreshFromClock()
            } else {
                // It completed while the app was closed; land in done, no alarm.
                remainingSeconds = 0
                progress = 1
                state = .done
                suggestedNext = savedKind == .focus ? .rest : .focus
                if savedKind == .focus { recordCompletedSession() }
                clearSavedSession()
            }
        } else if savedRaw == "paused" {
            let remaining = defaults.double(forKey: Self.savedPausedKey)
            if remaining > 0 {
                pausedRemaining = remaining
                remainingSeconds = Int(remaining.rounded(.up))
                progress = 1 - remaining / max(1, Double(durationSeconds))
                state = .paused
            }
        }
    }

    private func persistSession() {
        switch state {
        case .running:
            defaults.set("running", forKey: Self.savedStateKey)
            defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: Self.savedEndDateKey)
            defaults.set(kind == .rest ? "rest" : "focus", forKey: Self.savedKindKey)
            defaults.set(durationSeconds, forKey: Self.savedDurationKey)
        case .paused:
            defaults.set("paused", forKey: Self.savedStateKey)
            defaults.set(pausedRemaining ?? 0, forKey: Self.savedPausedKey)
            defaults.set(kind == .rest ? "rest" : "focus", forKey: Self.savedKindKey)
            defaults.set(durationSeconds, forKey: Self.savedDurationKey)
        default:
            clearSavedSession()
        }
    }

    private func clearSavedSession() {
        defaults.removeObject(forKey: Self.savedStateKey)
        defaults.removeObject(forKey: Self.savedEndDateKey)
        defaults.removeObject(forKey: Self.savedPausedKey)
    }

    // MARK: Controls

    func setMinutes(_ newValue: Double) {
        guard state == .idle || state == .done else { return }
        minutes = min(allowedRange.upperBound, max(allowedRange.lowerBound, newValue.rounded()))
    }

    func setBreakMinutes(_ newValue: Double) {
        breakMinutes = min(breakRange.upperBound, max(breakRange.lowerBound, newValue.rounded()))
    }

    /// Presets start practice right away, like the original Onigiri did.
    func applyPreset(_ value: Int) {
        setMinutes(Double(value))
        startFocus()
    }

    func toggleStartPause() {
        switch state {
        case .running:
            pause()
        case .paused:
            resume()
        case .idle:
            kind == .rest ? startBreak() : startFocus()
        case .done:
            suggestedNext == .rest ? startBreak() : startFocus()
        }
    }

    func startFocus() {
        SoundPlayer.stopAlarm()
        kind = .focus
        arm(duration: Int(minutes) * 60)
    }

    func startBreak() {
        SoundPlayer.stopAlarm()
        kind = .rest
        arm(duration: Int(breakMinutes) * 60)
    }

    /// Re-runs a short five-minute focus session, e.g. from the snooze action.
    func snoozeFiveMinutes() {
        SoundPlayer.stopAlarm()
        kind = .focus
        arm(duration: 5 * 60)
    }

    func reset() {
        ticker?.cancel()
        endDate = nil
        pausedRemaining = nil
        state = .idle
        kind = .focus
        suggestedNext = nil
        durationSeconds = Int(minutes) * 60
        remainingSeconds = durationSeconds
        progress = 0
        SoundPlayer.stopAlarm()
        persistSession()
    }

    private func arm(duration: Int) {
        guard duration > 0 else { return }
        durationSeconds = duration
        remainingSeconds = duration
        progress = 0
        pausedRemaining = nil
        endDate = Date().addingTimeInterval(Double(duration))
        state = .running
        requestNotificationPermissionIfNeeded()
        startTicker()
        refreshFromClock()
        persistSession()
    }

    private func resume() {
        guard let remaining = pausedRemaining, remaining > 0 else {
            kind == .rest ? startBreak() : startFocus()
            return
        }
        endDate = Date().addingTimeInterval(remaining)
        pausedRemaining = nil
        state = .running
        requestNotificationPermissionIfNeeded()
        startTicker()
        refreshFromClock()
        persistSession()
    }

    func pause() {
        guard state == .running else { return }
        pausedRemaining = endDate.map { max(0, $0.timeIntervalSinceNow) }
        endDate = nil
        state = .paused
        ticker?.cancel()
        persistSession()
    }

    // MARK: Engine

    private func startTicker() {
        ticker?.cancel()
        ticker = Timer.publish(every: 0.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refreshFromClock() }
    }

    private func refreshFromClock() {
        guard state == .running, let endDate else { return }
        let remaining = endDate.timeIntervalSinceNow
        let total = max(1, Double(durationSeconds))
        progress = min(1, max(0, 1 - remaining / total))

        let display = Int(remaining.rounded(.up))
        if display != remainingSeconds {
            remainingSeconds = max(0, display)
        }
        if remaining <= 0 {
            finish()
        }
    }

    private func finish() {
        ticker?.cancel()
        endDate = nil
        pausedRemaining = nil
        remainingSeconds = 0
        progress = 1
        state = .done
        suggestedNext = kind == .focus ? .rest : .focus
        if kind == .focus { recordCompletedSession() }
        persistSession()
        SoundPlayer.playAlarm(muted: isMuted)
        notifyCompletion()
        onFinish?()
    }

    // MARK: Sessions

    private static func sessionsKey(for date: Date) -> String {
        let day = Calendar.current.startOfDay(for: date)
        return "sessions-\(Int(day.timeIntervalSince1970))"
    }

    private func recordCompletedSession() {
        let key = Self.sessionsKey(for: Date())
        let count = defaults.integer(forKey: key) + 1
        defaults.set(count, forKey: key)
        sessionsToday = count
    }

    /// Completed focus sessions N days ago (0 = today), for the sparkline.
    func sessionCount(daysAgo: Int) -> Int {
        let day = Calendar.current.startOfDay(
            for: Date().addingTimeInterval(Double(-daysAgo) * 86_400)
        )
        return defaults.integer(forKey: Self.sessionsKey(for: day))
    }

    // MARK: Launch at login

    private func applyLaunchAtLogin(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.loginKey)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Non-fatal: preference simply won't take effect.
        }
    }

    // MARK: Notifications

    private func requestNotificationPermissionIfNeeded() {
        guard !permissionRequested else { return }
        permissionRequested = true
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert]) { _, _ in }
    }

    private func notifyCompletion() {
        let content = UNMutableNotificationContent()
        content.title = "Zanshin"
        content.body = kind == .focus ? "Strike! Practice complete." : "Tea finished — back to the blade."
        content.sound = nil // SoundPlayer already handles the alarm
        content.categoryIdentifier = "SESSION_COMPLETE"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
