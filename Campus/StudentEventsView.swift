//
//  StudentEventsView.swift
//  Campus
//
//  Read-only campus feed for general students. Editorial layout,
//  restrained accents, category filter chips, LazyVStack for perf.
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
    }

    // MARK: - Derived

    private var filtered: [CampusEvent] {
        let category: (CampusEvent) -> Bool = { event in
            switch self.filter {
            case .all: return true
            default:
                guard let club = self.store.club(by: event.clubId) else { return false }
                return club.category.caseInsensitiveCompare(self.filter.rawValue) == .orderedSame
            }
        }
        let search: (CampusEvent) -> Bool = { event in
            guard !self.query.isEmpty else { return true }
            let q = self.query.lowercased()
            if event.title.lowercased().contains(q) { return true }
            if event.location.lowercased().contains(q) { return true }
            if let c = self.store.club(by: event.clubId),
               c.name.lowercased().contains(q) { return true }
            return false
        }
        return store.events.filter(category).filter(search)
            .sorted { $0.startTime < $1.startTime }
    }
    private var upcoming: [CampusEvent] {
        let now = Date()
        return filtered.filter { $0.startTime >= now }
    }
    private var past: [CampusEvent] {
        let now = Date()
        return filtered.filter { $0.startTime < now }.reversed()
    }
    private var firstName: String {
        auth.currentUser?.name.components(separatedBy: " ").first ?? "there"
    }

    // MARK: - Body

    var body: some View {
        GlassScene {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                    masthead
                    filterStrip
                    if filtered.isEmpty {
                        EmptyState(icon: "magnifyingglass",
                                   title: "Nothing to see yet",
                                   subtitle: "Try a different filter or check back later.")
                    } else {
                        if !upcoming.isEmpty { section("Upcoming", count: upcoming.count, tint: Theme.accent, list: upcoming) }
                        if !past.isEmpty     { section("Past",     count: past.count,     tint: Theme.positive, list: past) }
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
        .searchableBar(text: $query, prompt: "Search events, clubs, venues")
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
        .navigationDestination(for: CampusEvent.self) { event in
            StudentEventDetailView(eventId: event.id)
        }
        .animation(AppMotion.smooth, value: filtered.map(\.id))
    }

    // MARK: - Pieces

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Al Akhawayn · Campus feed").overlineStyle(Theme.accent)
            Text("Hi, \(firstName)")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
            Text("Everything happening across campus.")
                .font(AppFont.body)
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CategoryFilter.allCases) { option in
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
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, count: Int, tint: Color,
                         list: [CampusEvent]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title) { CountPill(count: count, tint: tint) }
            LazyVStack(spacing: 12) {
                ForEach(list) { event in
                    NavigationLink(value: event) {
                        StudentEventCardRow(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Card row

struct StudentEventCardRow: View {
    @EnvironmentObject private var store: DataStore
    let event: CampusEvent

    private var clubName: String { store.club(by: event.clubId)?.name ?? "—" }
    private var leaderName: String {
        store.mainLeader(for: event.id)?.name ?? "TBA"
    }

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
                metaLine(icon: "mappin.and.ellipse", text: event.location)
                metaLine(icon: "clock",
                         text: event.startTime.formatted(date: .abbreviated,
                                                         time: .shortened))
            }
            HStack(spacing: 8) {
                metaLine(icon: "person.badge.shield.checkmark",
                         text: "Led by \(leaderName)")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(18)
        .surfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius,
                                       style: .continuous))
    }

    private func metaLine(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
            Text(text)
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkMuted)
                .lineLimit(1)
        }
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
                VStack(alignment: .leading, spacing: 20) {
                    header(event)
                    infoCard(event)
                    leaderCard(event)
                    if let catering = event.catering {
                        CateringCard(catering: catering)
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
                .contentFrame(max: AppLayout.readingMaxWidth)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(event.title)
        .inlineNavTitle()
    }

    private func header(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let club = store.club(by: event.clubId) {
                Text(club.name).overlineStyle(Theme.accent)
            }
            Text(event.title)
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
            StatusBadge(status: event.status)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoCard(_ event: CampusEvent) -> some View {
        VStack(spacing: 14) {
            DetailRow(icon: "mappin.and.ellipse",
                      label: "Location", value: event.location)
            AppRule()
            DetailRow(icon: "clock", label: "Starts",
                      value: event.startTime.formatted(date: .complete,
                                                       time: .shortened))
            AppRule()
            DetailRow(icon: "clock.badge.checkmark", label: "Ends",
                      value: event.endTime.formatted(date: .omitted,
                                                     time: .shortened))
        }
        .padding(18)
        .surfaceCard()
    }

    @ViewBuilder
    private func leaderCard(_ event: CampusEvent) -> some View {
        let leaders = store.leaders(for: event.id)
        let mainId  = store.mainLeader(for: event.id)?.id
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SAO Leader").overlineStyle()
                Spacer()
            }
            if leaders.isEmpty {
                Text("A SAO leader will be assigned soon.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaders.enumerated()), id: \.element.id) { index, leader in
                        HStack(spacing: 12) {
                            Circle()
                                .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                                .background(Circle().fill(Theme.fill))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(initials(leader.name))
                                        .font(AppFont.captionStrong)
                                        .foregroundStyle(Theme.ink)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(leader.name)
                                        .font(AppFont.bodyEmphasis)
                                        .foregroundStyle(Theme.ink)
                                    if leader.id == mainId {
                                        Text("MAIN").overlineStyle(Theme.accent)
                                    }
                                }
                                Text(leader.email)
                                    .font(AppFont.caption)
                                    .foregroundStyle(Theme.inkMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        if index != leaders.count - 1 {
                            AppRule()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .surfaceCard()
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
