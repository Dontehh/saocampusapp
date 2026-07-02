//
//  StudentRootView.swift
//  Campus
//
//  Read-only shell for general AUI students. Shows two tabs — the
//  campus-wide event schedule and the club directory. Shares the same
//  Liquid Glass canvas and AppMotion vocabulary as the leader/admin
//  surfaces so the experience feels part of the same product.
//

import SwiftUI

struct StudentRootView: View {

    enum Tab: Hashable { case events, clubs }

    @State private var selection: Tab = .events

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { StudentEventsView() }
                .tabItem {
                    Label("Events", systemImage: "calendar")
                }
                .tag(Tab.events)

            ClubsBrowserView()
                .tabItem {
                    Label("Clubs", systemImage: "person.3.fill")
                }
                .tag(Tab.clubs)
        }
        .tint(Theme.accent)
        .animation(AppMotion.smooth, value: selection)
    }
}
