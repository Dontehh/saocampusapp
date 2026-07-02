//
//  AdminEventQueueView.swift
//  Campus
//
//  Event Master Queue. Searchable + chip-filtered list of every event,
//  with an inline "+ Create Event" entry point in the toolbar.
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

        var systemImage: String {
            switch self {
            case .all:       return "tray.full.fill"
            case .ongoing:   return "calendar.badge.clock"
            case .completed: return "checkmark.seal.fill"
            }
        }
    }

    private var allEvents: [CampusEvent] { store.events }

    private var filteredEvents: [CampusEvent] {
        var list = allEvents
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

    private var counts: (all: Int, upcoming: Int, completed: Int) {
        let upcoming  = allEvents.filter { $0.status == .ongoing   }.count
        let completed = allEvents.filter { $0.status == .completed }.count
        return (allEvents.count, upcoming, completed)
    }

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    summaryStrip
                    filterChips
                    eventList
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .padding(.top, 4)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Event Master Queue")
        .largeNavTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) {
                Button {
                    showCreate = true
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
                .accessibilityLabel("Create new event")
            }
        }
        .searchableBar(text: $query, prompt: "Search events, clubs, venues")
        .sheet(isPresented: $showCreate) {
            CreateEventView()
        }
        .navigationDestination(for: CampusEvent.self) { event in
            AdminEventDetailView(eventId: event.id)
        }
    }

    // MARK: - Pieces

    private var summaryStrip: some View {
        let c = counts
        return HStack(spacing: 10) {
            summaryPill(value: c.all,
                        title: "Total",
                        color: Theme.accent,
                        icon: "tray.full.fill")
            summaryPill(value: c.upcoming,
                        title: "Upcoming",
                        color: Color.blue,
                        icon: "calendar.badge.clock")
            summaryPill(value: c.completed,
                        title: "Completed",
                        color: Color.green,
                        icon: "checkmark.seal.fill")
        }
    }

    private func summaryPill(value: Int, title: String,
                             color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                    .contentTransition(.numericText())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: color.opacity(0.18), radius: 16)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Filter.allCases) { option in
                    let isOn = filter == option
                    Button {
                        withAnimation(AppMotion.snappy) {
                            filter = option
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: option.systemImage)
                            Text(option.rawValue)
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassCard(
                            tint: isOn ? Theme.accent.opacity(0.6)
                                       : Theme.accent.opacity(0.12),
                            radius: 24
                        )
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var eventList: some View {
        if filteredEvents.isEmpty {
            EmptyState(
                icon: "magnifyingglass",
                title: "No events match",
                subtitle: query.isEmpty
                    ? "Tap the + button to create one."
                    : "Try a different search or filter."
            )
            .padding(.top, 24)
        } else {
            VStack(spacing: 12) {
                ForEach(filteredEvents) { event in
                    NavigationLink(value: event) {
                        AdminEventRow(event: event)
                    }
                    .buttonStyle(.plain)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.96).combined(with: .opacity),
                        removal:   .opacity
                    ))
                }
            }
            .animation(AppMotion.smooth,
                       value: filteredEvents.map(\.id))
        }
    }
}

struct AdminEventRow: View {
    @EnvironmentObject private var store: DataStore
    let event: CampusEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let club = store.club(by: event.clubId) {
                        Text(club.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                StatusBadge(status: event.status)
            }

            Divider().padding(.vertical, 2)

            HStack(spacing: 14) {
                Label(event.location, systemImage: "mappin.and.ellipse")
                Label(event.startTime.formatted(date: .abbreviated,
                                                time: .shortened),
                      systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("\(store.attendanceCount(for: event.id)) attended")
                        .contentTransition(.numericText())
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)

                if !event.technicalNeeds.isEmpty {
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(event.technicalNeeds.joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            let assignedLeaders = store.leaders(for: event.id)
            if !assignedLeaders.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .foregroundStyle(Theme.accent)
                        .font(.caption)
                    Text(assignedLeaders.map(\.name).joined(separator: ", "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            } else {
                Label("No leader assigned",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
        }
        .padding(18)
        .glassCard(tint: Theme.accent.opacity(0.14), radius: 22)
    }
}
