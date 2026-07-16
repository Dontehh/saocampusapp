//
//  AdminEventQueueView.swift
//  Campus
//
//  Refined master queue. Editorial masthead, restrained filter chips,
//  hairline-separated LazyVStack of rows for smooth scroll performance.
//

import SwiftUI

struct AdminEventQueueView: View {
    @EnvironmentObject private var store: DataStore

    @State private var query  = ""
    @State private var filter: Filter = .all
    @State private var showCreate = false

    enum Filter: String, CaseIterable, Identifiable {
        case all       = "All"
        case ongoing   = "Ongoing"
        case completed = "Completed"
        var id: String { rawValue }
    }

    // MARK: - Derived

    private var counts: (total: Int, ongoing: Int, completed: Int) {
        let ongoing   = store.events.filter { $0.status == .ongoing   }.count
        let completed = store.events.filter { $0.status == .completed }.count
        return (store.events.count, ongoing, completed)
    }

    private var filteredEvents: [CampusEvent] {
        var list = store.events
        switch filter {
        case .all:       break
        case .ongoing:   list = list.filter { $0.status == .ongoing   }
        case .completed: list = list.filter { $0.status == .completed }
        }
        if !query.isEmpty {
            let q = query.lowercased()
            list = list.filter { event in
                event.title.lowercased().contains(q) ||
                event.location.lowercased().contains(q) ||
                (store.club(by: event.clubId)?.name.lowercased().contains(q) ?? false)
            }
        }
        return list.sorted { $0.startTime > $1.startTime }
    }

    // MARK: - Body

    var body: some View {
        GlassScene {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                    masthead
                    summaryStrip
                    filterStrip
                    if filteredEvents.isEmpty {
                        EmptyState(icon: "magnifyingglass",
                                   title: "Nothing matches",
                                   subtitle: query.isEmpty
                                        ? "Tap + to schedule a new event."
                                        : "Try a different filter or search.")
                    } else {
                        eventList
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
            ToolbarItem(placement: .trailingBar) {
                Button {
                    showCreate = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 36, height: 36)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.rule,
                                                 lineWidth: AppLayout.hairline))
                }
                .accessibilityLabel("Create event")
            }
        }
        .searchableBar(text: $query, prompt: "Search events, clubs, venues")
        .sheet(isPresented: $showCreate) { CreateEventView() }
        .navigationDestination(for: CampusEvent.self) { event in
            AdminEventDetailView(eventId: event.id)
        }
    }

    // MARK: - Pieces

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Master Queue").overlineStyle(Theme.accent)
            Text("Events")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
        }
    }

    private var summaryStrip: some View {
        HStack(spacing: 12) {
            summary("Total",     counts.total,     Theme.ink)
            summary("Ongoing",   counts.ongoing,   Theme.accent)
            summary("Completed", counts.completed, Theme.positive)
        }
    }

    private func summary(_ label: String, _ value: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(AppFont.statNumber)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 5, height: 5)
                Text(label).font(AppFont.overline).tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(radius: 16)
    }

    private var filterStrip: some View {
        HStack(spacing: 8) {
            ForEach(Filter.allCases) { option in
                let isOn = filter == option
                Button {
                    withAnimation(AppMotion.snappy) { filter = option }
                } label: {
                    Text(option.rawValue)
                        .font(AppFont.captionStrong)
                        .foregroundStyle(isOn ? Color.white : Theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule(style: .continuous)
                                .fill(isOn ? Theme.accent : Theme.surface)
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(isOn ? Color.clear : Theme.rule,
                                        lineWidth: AppLayout.hairline)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var eventList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredEvents) { event in
                NavigationLink(value: event) {
                    AdminEventRow(event: event)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Row

struct AdminEventRow: View {
    @EnvironmentObject private var store: DataStore
    let event: CampusEvent

    private var clubName: String { store.club(by: event.clubId)?.name ?? "—" }
    private var attendance: Int { store.attendanceCount(for: event.id) }
    private var mainLeader: AppUser? { store.mainLeader(for: event.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(clubName).overlineStyle()
                Spacer()
                StatusBadge(status: event.status)
            }
            Text(event.title)
                .font(AppFont.heading)
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            HStack(spacing: 16) {
                meta(icon: "clock",
                     text: event.startTime.formatted(date: .abbreviated,
                                                     time: .shortened))
                meta(icon: "mappin.and.ellipse", text: event.location)
            }
            HStack(spacing: 12) {
                meta(icon: "person.crop.circle",
                     text: mainLeader?.name ?? "No leader assigned",
                     tint: mainLeader == nil ? Theme.warning : Theme.inkMuted)
                Spacer()
                meta(icon: "person.3",
                     text: "\(attendance)",
                     tint: Theme.accent)
            }
        }
        .padding(18)
        .surfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius,
                                       style: .continuous))
    }

    private func meta(icon: String, text: String,
                      tint: Color = Theme.inkMuted) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
        }
    }
}
