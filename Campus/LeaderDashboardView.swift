//
//  LeaderDashboardView.swift
//  Campus
//
//  Editorial dashboard for SAO event leaders. Refined hierarchy:
//  masthead, hero (single accent card), lazy sections. No card-in-card
//  nesting; motion is a single spring curve.
//

import SwiftUI

struct LeaderRootView: View {
    enum Tab: Hashable { case events, clubs }
    @State private var selection: Tab = .events

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { LeaderDashboardView() }
                .tabItem { Label("My Events", systemImage: "calendar") }
                .tag(Tab.events)

            ClubsBrowserView()
                .tabItem { Label("Clubs", systemImage: "person.3") }
                .tag(Tab.clubs)
        }
        .tint(Theme.accent)
        .fluentTabBarBackground()
        .animation(AppMotion.smooth, value: selection)
    }
}

struct LeaderDashboardView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    // MARK: - Derived

    private var leaderEvents: [CampusEvent] {
        guard let id = auth.currentUser?.id else { return [] }
        return store.events(for: id).sorted { $0.startTime < $1.startTime }
    }
    private var upcoming: [CampusEvent] {
        leaderEvents.filter { $0.status == .ongoing }
    }
    private var past: [CampusEvent] {
        leaderEvents.filter { $0.status == .completed }
            .sorted { $0.startTime > $1.startTime }
    }
    private var totalAttended: Int {
        past.reduce(0) { $0 + store.attendanceCount(for: $1.id) }
    }
    private var firstName: String {
        auth.currentUser?.name.components(separatedBy: " ").first ?? "Leader"
    }

    // MARK: - Body

    var body: some View {
        GlassScene {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                    masthead
                    heroCard
                    if leaderEvents.isEmpty {
                        EmptyState(icon: "calendar",
                                   title: "No events yet",
                                   subtitle: "Your assignments appear here as SAO staff add them.")
                    } else {
                        if !upcoming.isEmpty { section("Upcoming",
                                                       count: upcoming.count,
                                                       tint: Theme.accent,
                                                       list: upcoming) }
                        if !past.isEmpty     { section("Past",
                                                       count: past.count,
                                                       tint: Theme.positive,
                                                       list: past) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .contentFrame()
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
        .navigationDestination(for: CampusEvent.self) { event in
            LeaderEventDetailView(eventId: event.id)
        }
        .animation(AppMotion.smooth, value: leaderEvents.map(\.id))
    }

    // MARK: - Pieces

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Leader").overlineStyle()
            Text(firstName)
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("This term").overlineStyle(Theme.accent)
                Spacer()
                if let next = upcoming.first {
                    Text("Next \(next.startTime.formatted(.relative(presentation: .named)))")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
            }
            HStack(spacing: 24) {
                stat("Upcoming", upcoming.count)
                divider
                stat("Completed", past.count)
                divider
                stat("Attended", totalAttended)
            }
            if let next = upcoming.first {
                AppRule()
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Next up").overlineStyle()
                        Text(next.title)
                            .font(AppFont.headline)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(1)
                        Text(next.startTime.formatted(date: .abbreviated,
                                                      time: .shortened))
                            .font(AppFont.caption)
                            .foregroundStyle(Theme.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .padding(22)
        .heroCard()
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.accent.opacity(0.18))
            .frame(width: AppLayout.hairline, height: 32)
    }

    private func stat(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(AppFont.statNumber)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label).overlineStyle()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func section(_ title: String,
                         count: Int,
                         tint: Color,
                         list: [CampusEvent]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title) { CountPill(count: count, tint: tint) }
            LazyVStack(spacing: 12) {
                ForEach(list) { event in
                    NavigationLink(value: event) {
                        EventCardRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
