//
//  AppDelegate.swift
//  Campus
//
//  UIKit AppDelegate bridge for Firebase. Handles:
//   1. FirebaseApp.configure() at launch
//   2. APNs device-token registration (forwarded to FCM)
//   3. Remote push receipt routing
//
//  Guarded with canImport so the target still builds without the SDK.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {

    // MARK: - Lifecycle

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(FirebaseCore)
        // Guarded because FirebaseApp.configure() will trap if the
        // SDK is present but GoogleService-Info.plist isn't in the
        // bundle. Give a friendly console note instead of crashing.
        if Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
            #if canImport(FirebaseMessaging)
            Messaging.messaging().delegate = FCMDelegate.shared
            #endif
            UIApplication.shared.registerForRemoteNotifications()
        } else {
            NSLog("[Firebase] GoogleService-Info.plist not found. " +
                  "Sync + push disabled. See firebase-setup.md.")
        }
        #endif
        return true
    }

    // MARK: - APNs

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("[APNs] registration failed: \(error.localizedDescription)")
    }
}

// Declared unconditionally so callers can reference it even before the
// Firebase SDK is added — the notification simply never fires.
extension Notification.Name {
    static let fcmTokenUpdated = Notification.Name("FCMTokenUpdated")
}

// MARK: - FCM delegate

#if canImport(FirebaseMessaging)
final class FCMDelegate: NSObject, MessagingDelegate {
    static let shared = FCMDelegate()

    /// Called every time FCM issues a new registration token. The
    /// backend / Cloud Function targets a topic named `user_<userId>`
    /// so we subscribe as soon as we know who the current user is.
    func messaging(_ messaging: Messaging,
                   didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NSLog("[FCM] token = \(token)")
        NotificationCenter.default.post(name: .fcmTokenUpdated,
                                        object: token)
    }
}
#endif
