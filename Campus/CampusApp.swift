//
//  CampusApp.swift
//  Campus
//
//  CampusPulse — SAO Event Analytics
//

import SwiftUI

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
