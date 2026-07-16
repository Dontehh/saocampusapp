//
//  NotificationService.swift
//  Campus
//
//  Wraps UserNotifications for the assignment flow. Local notifications
//  are used for the demo — swap the `notifyAssignment` body for an APNs
//  push (or a CloudKit subscription) once a backend is in place so the
//  notification reaches the leader's device rather than only the
//  admin's while both are on the same phone.
//

import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var didRequestAuthorization = false

    /// Prompts the user for notification permission on first launch.
    /// Safe to call repeatedly — the OS gate does the deduping too.
    func requestAuthorizationIfNeeded() async {
        #if canImport(UserNotifications)
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        #endif
    }

    /// Delivers a local notification announcing the assignment. In
    /// production this would be replaced with an APNs push targeted at
    /// the leader's device token.
    func notifyAssignment(leaderName: String,
                          eventTitle: String,
                          eventDate: Date) {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "New event assignment"
        content.body  = "\(leaderName), you've been assigned to \(eventTitle) on \(eventDate.formatted(date: .abbreviated, time: .shortened))."
        content.sound = .default
        content.threadIdentifier = "assignments"

        // 1 s trigger so the notification appears even when the app is
        // in the foreground and the system suppresses in-line banners.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content,
                                             trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        #endif
    }
}
