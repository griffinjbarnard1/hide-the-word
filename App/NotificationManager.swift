import UserNotifications

enum NotificationManager {
    private static let dailyReminderID = "scripture_memory_daily_reminder"
    static let categoryStartSession = "START_SESSION"
    static let actionStartSession = "START_SESSION_ACTION"

    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    static func registerCategories() {
        let startAction = UNNotificationAction(
            identifier: actionStartSession,
            title: "Start reviewing",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryStartSession,
            actions: [startAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func scheduleDailyReminder(at hour: Int, minute: Int, dueCount: Int, planDayInfo: String? = nil) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            let granted = await requestPermission()
            guard granted else { return }
            return await scheduleDailyReminder(at: hour, minute: minute, dueCount: dueCount, planDayInfo: planDayInfo)
        }

        center.removePendingNotificationRequests(withIdentifiers: [dailyReminderID])

        let content = UNMutableNotificationContent()
        content.title = "Hide the Word"
        if let planInfo = planDayInfo {
            content.body = planInfo
        } else if dueCount > 0 {
            let label = dueCount == 1 ? "verse is" : "verses are"
            content.body = "\(dueCount) \(label) ready for review. A few quiet minutes is all it takes."
        } else {
            content.body = "No reviews due today, but a quick visit keeps the rhythm going."
        }
        content.sound = .default
        content.categoryIdentifier = categoryStartSession
        content.userInfo = ["route": "session/today"]

        if dueCount > 0 {
            content.badge = NSNumber(value: dueCount)
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(identifier: dailyReminderID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func clearBadge() async {
        try? await UNUserNotificationCenter.current().setBadgeCount(0)
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [dailyReminderID])
    }
}
