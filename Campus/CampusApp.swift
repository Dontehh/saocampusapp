//
//  CampusApp.swift
//  Campus
//
//  CampusPulse — SAO Event Analytics
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@main
struct CampusApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var clubsManager:  ClubsDataManager
    @StateObject private var dataStore:     DataStore
    @StateObject private var auth:          AuthService
    @StateObject private var settings:      AppSettings
    @StateObject private var pendingCheckIn = PendingCheckIn()

    init() {
        let manager = ClubsDataManager()
        let store   = DataStore(clubsManager: manager)
        _clubsManager = StateObject(wrappedValue: manager)
        _dataStore    = StateObject(wrappedValue: store)
        _auth         = StateObject(wrappedValue: AuthService())
        _settings     = StateObject(wrappedValue: AppSettings())

        Self.configureTabBarAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clubsManager)
                .environmentObject(dataStore)
                .environmentObject(auth)
                .environmentObject(settings)
                .environmentObject(pendingCheckIn)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.accent)
                .task {
                    await NotificationService.shared.requestAuthorizationIfNeeded()
                    // Firebase snapshot listeners start once, after
                    // AppDelegate has finished configuring the SDK.
                    FirebaseSync.shared.start(dataStore: dataStore)
                }
                // Cross-device: when a leader signs in, subscribe the
                // FCM topic named `user_<userId>` so the Cloud Function
                // can push assignments straight to their device.
                .onReceive(NotificationCenter.default.publisher(
                    for: .fcmTokenUpdated)) { _ in
                    resubscribeCurrentUser()
                }
                .onChange(of: auth.currentUser?.id) { _, _ in
                    resubscribeCurrentUser()
                }
                // Deep-link entry point:
                //   campuspulse://checkin?event=<eventId>
                .onOpenURL { url in
                    handleIncoming(url: url)
                }
                .sheet(isPresented: pendingCheckInBinding) {
                    if let id = pendingCheckIn.eventId {
                        CheckInPromptView(eventId: id)
                            .environmentObject(dataStore)
                            .environmentObject(auth)
                            .presentationDetents([.medium, .large])
                            .presentationDragIndicator(.visible)
                    }
                }
        }
    }

    // MARK: - Helpers

    private var pendingCheckInBinding: Binding<Bool> {
        Binding(
            get: { pendingCheckIn.eventId != nil },
            set: { if !$0 { pendingCheckIn.clear() } }
        )
    }

    private func handleIncoming(url: URL) {
        guard url.scheme?.lowercased() == "campuspulse" else { return }
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let host  = (url.host ?? comps?.host ?? "").lowercased()
        guard host == "checkin" else { return }
        guard let eventId = comps?
                .queryItems?
                .first(where: { $0.name == "event" })?
                .value,
              !eventId.isEmpty
        else { return }
        pendingCheckIn.begin(eventId: eventId)
    }

    /// (Re)subscribe the current signed-in user to their per-user FCM
    /// topic so the Cloud Function can target pushes at them.
    private func resubscribeCurrentUser() {
        #if canImport(FirebaseMessaging)
        guard let userId = auth.currentUser?.id else { return }
        Messaging.messaging().subscribe(toTopic: "user_\(userId)") { _ in }
        #endif
    }

    private static func configureTabBarAppearance() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor  = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor      = .clear
        UITabBar.appearance().standardAppearance   = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        #endif
    }
}

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif
