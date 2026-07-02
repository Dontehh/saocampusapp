//
//  ClubsBrowserView.swift
//  Campus
//
//  Verification screen for ClubsDataManager. Lists every loaded SAO club
//  grouped by category and shows the most recent semester's board + events
//  when tapped.
//

import SwiftUI

struct ClubsBrowserView: View {
    @EnvironmentObject private var manager: ClubsDataManager
    @State private var query = ""

    private var grouped: [(category: ClubCategory, clubs: [SAOClub])] {
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
                List {
                    if !manager.loadErrors.isEmpty {
                        Section("Errors") {
                            ForEach(manager.loadErrors, id: \.self) { msg in
                                Label(msg, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                    .font(.caption)
                            }
                        }
                    }

                    summarySection

                    ForEach(grouped, id: \.category) { entry in
                        if !entry.clubs.isEmpty {
                            Section {
                                ForEach(entry.clubs) { club in
                                    NavigationLink(value: club) {
                                        ClubRow(club: club)
                                    }
                                }
                            } header: {
                                Label(entry.category.rawValue,
                                      systemImage: entry.category.systemImage)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("SAO Clubs")
            .searchableBar(text: $query, prompt: "Search clubs")
            .navigationDestination(for: SAOClub.self) { club in
                ClubDetailView(club: club)
            }
        }
    }

    private var summarySection: some View {
        Section {
            HStack(spacing: 12) {
                stat("\(manager.clubs.count)", "Clubs")
                stat("\(manager.allSemesters.count)", "Semesters")
                stat("\(manager.saoTeam.last?.leaders.count ?? 0)",
                     "Leaders (latest)")
            }
        }
        .listRowBackground(Color.clear)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .softCard(radius: 14)
    }
}

// MARK: - Row

private struct ClubRow: View {
    let club: SAOClub

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(club.clubName)
                .font(.headline)
            HStack(spacing: 12) {
                if let category = club.category {
                    Label(category.rawValue,
                          systemImage: category.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let latest = club.latestSemester {
                    Label(latest, systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Label("\(club.totalEventCount) events",
                      systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

private struct ClubDetailView: View {
    let club: SAOClub

    var body: some View {
        GlassScene {
            List {
                Section("Current Board (\(club.latestSemester ?? "—"))") {
                    if club.currentBoard.isEmpty {
                        Text("No board recorded for this semester.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(club.currentBoard.keys.sorted(), id: \.self) { role in
                            LabeledContent(role,
                                           value: club.currentBoard[role] ?? "—")
                        }
                    }
                }

                Section("Events (\(club.latestSemester ?? "—"))") {
                    if club.currentEvents.isEmpty {
                        Text("No events recorded.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(club.currentEvents, id: \.self) { event in
                            Text(event)
                        }
                    }
                }

                Section("All Semesters") {
                    ForEach(club.allSemesters.reversed(), id: \.self) { sem in
                        DisclosureGroup(sem) {
                            if let events = club.events[sem], !events.isEmpty {
                                ForEach(events, id: \.self) { e in
                                    Text("• \(e)").font(.footnote)
                                }
                            } else {
                                Text("No events recorded.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(club.clubName)
        .inlineNavTitle()
    }
}

#Preview {
    ClubsBrowserView()
        .environmentObject(ClubsDataManager())
}
