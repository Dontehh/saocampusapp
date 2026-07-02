//
//  ContentView.swift
//  Campus
//
//  Root router. Strictly gates entry into the Admin vs. Leader interface
//  based on the authenticated user's backend role.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    var body: some View {
        Group {
            if let user = auth.currentUser {
                switch user.role {
                case .admin:
                    AdminRootView()
                case .leader:
                    LeaderRootView()
                }
            } else {
                LoginView()
            }
        }
        .animation(AppMotion.smooth, value: auth.currentUser)
        .transition(.opacity)
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore(clubsManager: ClubsDataManager()))
        .environmentObject(AuthService())
        .environmentObject(AppSettings())
}
