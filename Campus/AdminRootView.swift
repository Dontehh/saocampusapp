//
//  AdminRootView.swift
//  Campus
//
//  Tabbed shell that admins land in after authentication.
//

import SwiftUI

struct AdminRootView: View {

    enum Tab: Hashable { case overview, events, clubs, analytics }

    @State private var selection: Tab = .overview

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { AdminOverviewView() }
                .tabItem {
                    Label("Overview",
                          systemImage: "chart.bar.doc.horizontal.fill")
                }
                .tag(Tab.overview)

            NavigationStack { AdminEventQueueView() }
                .tabItem {
                    Label("Events",
                          systemImage: "calendar")
                }
                .tag(Tab.events)

            ClubsBrowserView()
                .tabItem {
                    Label("Clubs",
                          systemImage: "person.3.fill")
                }
                .tag(Tab.clubs)

            NavigationStack { AdminAnalyticsView() }
                .tabItem {
                    Label("Analytics",
                          systemImage: "chart.pie.fill")
                }
                .tag(Tab.analytics)
        }
        .tint(Theme.accent)
        .animation(AppMotion.smooth, value: selection)
    }
}
