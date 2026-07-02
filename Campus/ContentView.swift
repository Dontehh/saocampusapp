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
                case .admin, .staff:
                    // Staff share the admin surface — same data, same
                    // read/write reach. The nav bar shows the current
                    // user's name, so it's clear which role is signed in.
                    AdminRootView()
                case .leader:
                    LeaderRootView()
                case .student:
                    StudentRootView()
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
