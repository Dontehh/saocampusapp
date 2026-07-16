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
                }
                // Deep-link entry point. QRs encode
                //   campuspulse://checkin?event=<eventId>
                // Any scanning device with the app installed will land
                // here and get the check-in prompt.
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

    private var pendingCheckInBinding: Binding<Bool> {
        Binding(
            get: { pendingCheckIn.eventId != nil },
            set: { if !$0 { pendingCheckIn.clear() } }
        )
    }

    private func handleIncoming(url: URL) {
        guard url.scheme?.lowercased() == "campuspulse" else { return }
        // "campuspulse://checkin?event=e-123" → host = "checkin",
        //   event = "e-123"
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
