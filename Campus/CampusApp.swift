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

    // ClubsDataManager owns the JSON-decoded source of truth.
    // DataStore consumes it to seed users/clubs/events/etc.
    @StateObject private var clubsManager: ClubsDataManager
    @StateObject private var dataStore:    DataStore
    @StateObject private var auth:         AuthService
    @StateObject private var settings:     AppSettings

    init() {
        let manager = ClubsDataManager()
        let store   = DataStore(clubsManager: manager)
        _clubsManager = StateObject(wrappedValue: manager)
        _dataStore    = StateObject(wrappedValue: store)
        _auth         = StateObject(wrappedValue: AuthService())
        _settings     = StateObject(wrappedValue: AppSettings())

        Self.configureTabBarAppearance()
    }

    /// The default UITabBar chrome renders a solid grey slab that
    /// occludes the SceneBackground on iOS. This wipes the resting AND
    /// scroll-edge appearances so the bar is fully transparent — the
    /// individual tab items keep their own Liquid Glass containers, and
    /// scrolling content + orange blobs refract cleanly under them.
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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clubsManager)
                .environmentObject(dataStore)
                .environmentObject(auth)
                .environmentObject(settings)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.accent)
        }
    }
}
