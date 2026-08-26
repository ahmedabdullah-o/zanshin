import SwiftUI
import UserNotifications

@main
struct ZanshinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    static let completionCategory = "SESSION_COMPLETE"
    static let startBreakAction = "START_BREAK"
    static let snoozeAction = "SNOOZE_FIVE"

    let model = TimerModel()
    private var controller: StatusBarController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController(model: model)
        registerNotificationActions()
        UNUserNotificationCenter.current().delegate = self
    }

    private func registerNotificationActions() {
        let startBreak = UNNotificationAction(
            identifier: Self.startBreakAction,
            title: "Tea break",
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: Self.snoozeAction,
            title: "+5 minutes",
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.completionCategory,
            actions: [startBreak, snooze],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Self.startBreakAction:
            model.startBreak()
        case Self.snoozeAction:
            model.snoozeFiveMinutes()
        default:
            // Plain tap on the notification reveals the timer panel.
            controller.openWindow()
        }
        completionHandler()
    }
}
