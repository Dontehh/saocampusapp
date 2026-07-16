//
//  NotificationService.swift
//  Campus
//
//  Wraps UserNotifications for the assignment flow. Local delivery only
//  at this stage — see the block comment at the bottom of this file for
//  what cross-device delivery would look like in production.
//

import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
final class NotificationService: NSObject {
    static let shared = NotificationService()

    private var didRequestAuthorization = false

    private override init() {
        super.init()
        #if canImport(UserNotifications)
        UNUserNotificationCenter.current().delegate = self
        #endif
    }

    /// Prompts for notification permission the first time. Repeated
    /// calls are cheap — the OS deduplicates the actual dialog anyway.
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

    /// Fires a local notification announcing the new assignment.
    /// This lands on the device that performed the assign, which is
    /// only useful for single-device demos. Real cross-device delivery
    /// needs an APNs push originated by a backend (see notes below).
    func notifyAssignment(leaderName: String,
                          eventTitle: String,
                          eventDate: Date) {
        #if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        content.title = "New event assignment"
        content.body  = "\(leaderName), you've been assigned to \(eventTitle) on \(eventDate.formatted(date: .abbreviated, time: .shortened))."
        content.sound = .default
        content.threadIdentifier = "assignments"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1,
                                                        repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                             content: content,
                                             trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        #endif
    }
}

// MARK: - Foreground presentation

#if canImport(UserNotifications)
extension NotificationService: UNUserNotificationCenterDelegate {
    /// Without this delegate, iOS silently suppresses local
    /// notifications while the app is in the foreground. Returning a
    /// non-empty `presentationOptions` set makes them appear as a
    /// banner + sound so single-device demos behave correctly.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
#endif

/*
 PRODUCTION PATH — cross-device notifications + attendance sync
 ---------------------------------------------------------------
 Local notifications land only on the device that fires them, and the
 DataStore is per-device in-memory. To make CampusPulse behave the way
 the product intends (leader on device A gets notified when admin on
 device B assigns them; live attendance flows from every student's
 device back into the leader's dashboard) we need one of:

   • CloudKit (Apple-native, no server)
       - Public database with `EventAssignment` and `Attendance`
         record types.
       - `CKQuerySubscription` + silent pushes update every device's
         DataStore in real time.
       - Uses the user's iCloud identity — matches the @aui.ma AppleID
         accounts university-managed devices already have.
       - Requires enabling the CloudKit capability in the target.

   • Firebase (Firestore + FCM)
       - Firestore stores assignments/attendance.
       - Snapshot listeners drive live UI updates.
       - FCM sends targeted push on assignment events.
       - Cross-platform if a web/Android client ever ships.

   • Custom backend (Supabase, Vercel, etc.)
       - REST or WebSocket, APNs push for notifications.

 Whichever you pick, the DataStore + NotificationService both expose
 the exact seams (a single write, a single notify call) where those
 backend hooks slot in — no view code needs to change.
 */
