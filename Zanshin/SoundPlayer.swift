import AppKit

/// Plays the completion alarm. Mirrors the original Onigiri's nine-beat chime,
/// can be cancelled early when the user interacts with the timer, and offers a
/// small set of system sounds to choose from.
enum SoundPlayer {

    static let availableAlarms = [
        "Glass", "Submarine", "Ping", "Purr", "Funk", "Blow", "Bottle", "Tink"
    ]

    private static let alarmKey = "alarmName"

    static var selectedAlarmName: String {
        get {
            let stored = UserDefaults.standard.string(forKey: alarmKey)
            guard let stored, availableAlarms.contains(stored) else { return "Glass" }
            return stored
        }
        set {
            UserDefaults.standard.set(newValue, forKey: alarmKey)
        }
    }

    private static var pendingBeeps: [DispatchWorkItem] = []

    static func playAlarm(muted: Bool) {
        stopAlarm()
        guard !muted else { return }
        let sound = NSSound(named: selectedAlarmName) ?? NSSound(named: "Glass")
        for i in 0..<9 {
            let work = DispatchWorkItem { sound?.play() }
            pendingBeeps.append(work)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.4, execute: work)
        }
    }

    static func stopAlarm() {
        pendingBeeps.forEach { $0.cancel() }
        pendingBeeps.removeAll()
    }
}
