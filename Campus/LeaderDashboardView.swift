//
//  LeaderDashboardView.swift
//  Campus
//
//  Liquid-Glass dashboard for event leaders. Hero card sits on the
//  SceneBackground so the orange/violet blobs refract through it.
//

import SwiftUI

struct LeaderRootView: View {

    enum Tab: Hashable { case events, clubs }

    @State private var selection: Tab = .events

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { LeaderDashboardView() }
                .tabItem {
                    Label("My Events", systemImage: "calendar")
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

struct LeaderDashboardView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

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
        leaderEvents
            .filter { $0.status == .completed }
            .reduce(0) { $0 + store.attendanceCount(for: $1.id) }
    }

    private var nextEvent: CampusEvent? { upcoming.first }

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard

                    if leaderEvents.isEmpty {
                        EmptyState(
                            icon: "calendar.badge.exclamationmark",
                            title: "No events yet",
                            subtitle: "Your assignments will appear here once SAO staff add them."
                        )
                        .padding(.top, 40)
                    } else {
                        if !upcoming.isEmpty {
                            sectionHeader("Upcoming", count: upcoming.count,
                                          tint: Theme.accent)
                            cards(for: upcoming)
                        }
                        if !past.isEmpty {
                            sectionHeader("Past", count: past.count,
                                          tint: Color.green)
                            cards(for: past)
                        }
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("My Events")
        .largeNavTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
        .navigationDestination(for: CampusEvent.self) { event in
            LeaderEventDetailView(eventId: event.id)
        }
        .animation(AppMotion.smooth,
                   value: leaderEvents.map(\.id))
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hello, \(firstName) 👋")
                        .font(.title2.weight(.bold))
                    Text("Here's what's on your plate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 10) {
                heroStat(value: "\(upcoming.count)",
                         label: "Upcoming",
                         icon: "calendar.badge.clock")
                heroStat(value: "\(past.count)",
                         label: "Completed",
                         icon: "checkmark.seal.fill")
                heroStat(value: "\(totalAttended)",
                         label: "Total Attended",
                         icon: "person.3.fill")
            }

            if let next = nextEvent {
                Divider().padding(.vertical, 2)
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(colors: [Theme.accent,
                                                        Color(red: 0.86, green: 0.32, blue: 0.06)],
                                               startPoint: .topLeading,
                                               endPoint:   .bottomTrailing)
                            )
                            .frame(width: 42, height: 42)
                        Image(systemName: "calendar.badge.clock")
                            .font(.title3)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Next up")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.accent)
                        Text(next.title)
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                        Text(next.startTime
                                .formatted(date: .abbreviated,
                                           time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(22)
        .glassCard(tint: Theme.accent.opacity(0.28), radius: 28)
    }

    private func heroStat(value: String, label: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .softCard(radius: 14)
    }

    // MARK: - Sections

    private var firstName: String {
        auth.currentUser?.name.components(separatedBy: " ").first ?? "Leader"
    }

    private func cards(for list: [CampusEvent]) -> some View {
        VStack(spacing: 14) {
            ForEach(list) { event in
                NavigationLink(value: event) {
                    EventCardRow(event: event)
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.96).combined(with: .opacity),
                    removal:   .opacity
                ))
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            HStack(spacing: 4) {
                Text("\(count)")
                    .contentTransition(.numericText())
                Text(title.lowercased())
            }
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassCard(tint: tint.opacity(0.22), radius: 14)
            .foregroundStyle(tint)
        }
        .padding(.top, 4)
    }
}
