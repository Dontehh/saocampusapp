//
//  StudentEventsView.swift
//  Campus
//
//  Campus-wide read-only feed of events for general students.
//  Grouped by "Upcoming" (startTime in the future) and
//  "Past" (already began). Filter chips let the student narrow by
//  category and there's a search bar over titles/clubs/venues.
//

import SwiftUI

struct StudentEventsView: View {
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    @State private var query: String = ""
    @State private var filter: CategoryFilter = .all

    enum CategoryFilter: String, CaseIterable, Identifiable {
        case all           = "All"
        case cultural      = "Cultural"
        case educational   = "Educational"
        case entertainment = "Entertainment"
        case humanitarian  = "Humanitarian"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .all:           return "square.grid.2x2.fill"
            case .cultural:      return "globe.europe.africa.fill"
            case .educational:   return "graduationcap.fill"
            case .entertainment: return "theatermasks.fill"
            case .humanitarian:  return "heart.fill"
            }
        }
    }

    // MARK: - Derived data

    private var sortedEvents: [CampusEvent] {
        let matchingCategory: (CampusEvent) -> Bool = { event in
            switch filter {
            case .all: return true
            default:
                guard let club = store.club(by: event.clubId) else { return false }
                return club.category.caseInsensitiveCompare(filter.rawValue) == .orderedSame
            }
        }
        let matchingQuery: (CampusEvent) -> Bool = { event in
            guard !query.isEmpty else { return true }
            let q = query.lowercased()
            if event.title.lowercased().contains(q) { return true }
            if event.location.lowercased().contains(q) { return true }
            if let club = store.club(by: event.clubId),
               club.name.lowercased().contains(q) { return true }
            return false
        }
        return store.events
            .filter(matchingCategory)
            .filter(matchingQuery)
            .sorted { $0.startTime < $1.startTime }
    }

    private var upcoming: [CampusEvent] {
        let now = Date()
        return sortedEvents
            .filter { $0.startTime >= now }
    }

    private var past: [CampusEvent] {
        let now = Date()
        return sortedEvents
            .filter { $0.startTime < now }
            .reversed()  // newest-first for past
    }

    // MARK: - Body

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    heroCard
                    filterChips

                    if sortedEvents.isEmpty {
                        EmptyState(
                            icon: "magnifyingglass",
                            title: "Nothing to see yet",
                            subtitle: "Try a different filter or check back later — the SAO team publishes new events every week."
                        )
                        .padding(.top, 40)
                    } else {
                        if !upcoming.isEmpty {
                            section(title: "Upcoming",
                                    count: upcoming.count,
                                    tint:  Theme.accent)
                            cards(for: upcoming)
                        }
                        if !past.isEmpty {
                            section(title: "Past",
                                    count: past.count,
                                    tint:  Color.green)
                            cards(for: past)
                        }
                    }
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Campus Events")
        .largeNavTitle()
        .searchableBar(text: $query,
                       prompt: "Search events, clubs, venues")
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
        .navigationDestination(for: CampusEvent.self) { event in
            StudentEventDetailView(eventId: event.id)
        }
        .animation(AppMotion.smooth, value: sortedEvents.map(\.id))
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hi \(firstName) 👋")
                        .font(.title2.weight(.bold))
                    Text("Everything happening on campus, in one place.")
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
                heroStat(value: "\(store.clubs.count)",
                         label: "Active Clubs",
                         icon: "person.3.fill")
                heroStat(value: "\(past.count)",
                         label: "Past",
                         icon: "checkmark.seal.fill")
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

    // MARK: - Chips

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CategoryFilter.allCases) { option in
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
                            tint: isOn
                                ? Theme.accent.opacity(0.55)
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

    // MARK: - Cards / sections

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

    private func section(title: String, count: Int, tint: Color) -> some View {
        HStack {
            Text(title).font(.headline)
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

    // MARK: - Helpers

    private var firstName: String {
        auth.currentUser?.name.components(separatedBy: " ").first ?? "there"
    }
}

// MARK: - Detail

struct StudentEventDetailView: View {
    let eventId: String

    @EnvironmentObject private var store: DataStore

    private var event: CampusEvent? { store.event(by: eventId) }

    var body: some View {
        Group {
            if let event {
                content(event: event)
            } else {
                ContentUnavailableView("Event not found",
                                       systemImage: "calendar.badge.exclamationmark")
            }
        }
    }

    @ViewBuilder
    private func content(event: CampusEvent) -> some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard(event)
                    attendanceCard(event)
                    aboutCard(event)
                }
                .padding(20)
                .animation(AppMotion.smooth, value: event.status)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(event.title)
        .inlineNavTitle()
    }

    private func headerCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(status: event.status)
                Spacer()
                if let club = store.club(by: event.clubId) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill").font(.caption)
                        Text(club.name).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .softCard(radius: 16)
                }
            }
            DetailRow(icon: "mappin.and.ellipse", label: "Venue",
                      value: event.location)
            DetailRow(icon: "clock", label: "Starts",
                      value: event.startTime.formatted(date: .complete,
                                                       time: .shortened))
            DetailRow(icon: "clock.badge.checkmark", label: "Ends",
                      value: event.endTime.formatted(date: .omitted,
                                                     time: .shortened))
        }
        .padding(20)
        .glassCard(tint: Theme.accent.opacity(0.15), radius: 24)
    }

    private func attendanceCard(_ event: CampusEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.status == .completed
                     ? "Total Attendance"
                     : "Live Attendance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(store.attendanceCount(for: event.id))")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                Text(event.status == .completed
                     ? "students checked in"
                     : "students so far")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent.opacity(0.35))
        }
        .padding(22)
        .glassCard(tint: Theme.accent.opacity(0.32), radius: 26)
    }

    @ViewBuilder
    private func aboutCard(_ event: CampusEvent) -> some View {
        if let club = store.club(by: event.clubId) {
            VStack(alignment: .leading, spacing: 10) {
                Label("About the host", systemImage: "info.circle.fill")
                    .font(.headline)
                DetailRow(icon: "person.3.fill", label: "Club",
                          value: club.name)
                DetailRow(icon: "tag.fill", label: "Category",
                          value: club.category)
            }
            .padding(20)
            .glassCard(radius: 24)
        }
    }
}
