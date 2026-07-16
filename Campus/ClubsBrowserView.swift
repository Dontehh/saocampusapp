//
//  ClubsBrowserView.swift
//  Campus
//
//  Refined club directory. Masthead, restrained stat strip, hairline
//  separated rows inside surface cards. Category grouping via overline
//  section headers instead of colored labels.
//

import SwiftUI

struct ClubsBrowserView: View {
    @EnvironmentObject private var manager: ClubsDataManager
    @State private var query = ""

    private var groups: [(category: ClubCategory, clubs: [SAOClub])] {
        let filtered = manager.clubs.filter { club in
            query.isEmpty ||
            club.clubName.lowercased().contains(query.lowercased())
        }
        return ClubCategory.allCases.map { cat in
            (cat, filtered.filter { $0.category == cat })
        }
    }

    var body: some View {
        NavigationStack {
            GlassScene {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                        masthead
                        statStrip
                        if !manager.loadErrors.isEmpty { errorList }
                        ForEach(groups, id: \.category) { entry in
                            if !entry.clubs.isEmpty {
                                categoryBlock(entry.category, entry.clubs)
                            }
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
            .searchableBar(text: $query, prompt: "Search clubs")
            .navigationDestination(for: SAOClub.self) { club in
                ClubDetailView(club: club)
            }
        }
    }

    // MARK: - Pieces

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SAO · Directory").overlineStyle(Theme.accent)
            Text("Clubs")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
        }
    }

    private var statStrip: some View {
        HStack(spacing: 12) {
            stat("\(manager.clubs.count)", "Clubs")
            stat("\(manager.allSemesters.count)", "Semesters")
            stat("\(manager.saoTeam.last?.leaders.count ?? 0)", "Leaders")
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(AppFont.statNumber)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
            Text(label).overlineStyle()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard(radius: 16)
    }

    private var errorList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Load errors").overlineStyle(Theme.negative)
            ForEach(manager.loadErrors, id: \.self) { msg in
                Text(msg)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.negative)
            }
        }
        .padding(16)
        .surfaceCard()
    }

    private func categoryBlock(_ category: ClubCategory,
                               _ clubs: [SAOClub]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(category.rawValue.uppercased()) {
                CountPill(count: clubs.count)
            }
            VStack(spacing: 0) {
                ForEach(Array(clubs.enumerated()), id: \.element.id) { index, club in
                    NavigationLink(value: club) {
                        ClubRow(club: club)
                    }
                    .buttonStyle(.plain)
                    if index != clubs.count - 1 {
                        AppRule()
                    }
                }
            }
            .padding(.horizontal, 18)
            .surfaceCard()
        }
    }
}

// MARK: - Row

private struct ClubRow: View {
    let club: SAOClub

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(club.clubName)
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 12) {
                    if let latest = club.latestSemester {
                        meta(icon: "calendar", text: latest)
                    }
                    meta(icon: "list.bullet",
                         text: "\(club.totalEventCount) events")
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }

    private func meta(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(text).font(AppFont.caption)
        }
        .foregroundStyle(Theme.inkMuted)
    }
}

// MARK: - Detail

private struct ClubDetailView: View {
    let club: SAOClub

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    boardCard
                    currentEventsCard
                    historyCard
                }
                .padding(20)
                .padding(.bottom, 40)
                .contentFrame(max: AppLayout.readingMaxWidth)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(club.clubName)
        .inlineNavTitle()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let category = club.category {
                Text(category.rawValue).overlineStyle(Theme.accent)
            }
            Text(club.clubName)
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
            if let latest = club.latestSemester {
                Text("Latest term · \(latest)")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }

    private var boardCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Current Board").overlineStyle()
                Spacer()
                if let latest = club.latestSemester {
                    Text(latest).font(AppFont.caption).foregroundStyle(Theme.inkFaint)
                }
            }
            if club.currentBoard.isEmpty {
                Text("No board recorded for this semester.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                VStack(spacing: 0) {
                    let keys = club.currentBoard.keys.sorted()
                    ForEach(Array(keys.enumerated()), id: \.element) { index, role in
                        HStack {
                            Text(role)
                                .font(AppFont.caption)
                                .foregroundStyle(Theme.inkMuted)
                            Spacer()
                            Text(club.currentBoard[role] ?? "—")
                                .font(AppFont.bodyEmphasis)
                                .foregroundStyle(Theme.ink)
                        }
                        .padding(.vertical, 10)
                        if index != keys.count - 1 { AppRule() }
                    }
                }
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private var currentEventsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Current Semester Events").overlineStyle()
            if club.currentEvents.isEmpty {
                Text("No events recorded.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(club.currentEvents.enumerated()), id: \.offset) { index, event in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)".padded(to: 2))
                                .font(AppFont.mono)
                                .foregroundStyle(Theme.inkFaint)
                            Text(event)
                                .font(AppFont.body)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        if index != club.currentEvents.count - 1 { AppRule() }
                    }
                }
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("All Semesters").overlineStyle()
            VStack(spacing: 0) {
                let sems = club.allSemesters.reversed()
                ForEach(Array(sems.enumerated()), id: \.element) { index, sem in
                    DisclosureGroup(sem) {
                        if let events = club.events[sem], !events.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(events, id: \.self) { e in
                                    Text("• \(e)")
                                        .font(AppFont.caption)
                                        .foregroundStyle(Theme.inkMuted)
                                }
                            }
                            .padding(.top, 6)
                        } else {
                            Text("No events recorded.")
                                .font(AppFont.caption)
                                .foregroundStyle(Theme.inkFaint)
                                .padding(.top, 4)
                        }
                    }
                    .font(AppFont.bodyEmphasis)
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 8)
                    if index != sems.count - 1 { AppRule() }
                }
            }
        }
        .padding(18)
        .surfaceCard()
    }
}

private extension String {
    func padded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}

#Preview {
    ClubsBrowserView()
        .environmentObject(ClubsDataManager())
}
