//
//  ClubsDataManager.swift
//  Campus
//
//  Loads the four club JSON files + the SAO team roster from the main
//  bundle, decodes them, injects a `category` field per club, and
//  exposes a single unified `@Published` array.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class ClubsDataManager: ObservableObject {

    /// Every club, all categories, decoded and ready to use.
    @Published private(set) var clubs: [SAOClub] = []
    /// Every SAO team semester roster (admins + leaders).
    @Published private(set) var saoTeam: [SAOTeamSemester] = []
    /// Decoded errors surfaced for the UI / debugging.
    @Published private(set) var loadErrors: [String] = []
    @Published private(set) var isLoaded: Bool = false

    private let decoder = JSONDecoder()

    init(autoLoad: Bool = true) {
        if autoLoad { loadAll() }
    }

    // MARK: - Loading

    func loadAll() {
        loadErrors.removeAll()
        var merged: [SAOClub] = []

        for category in ClubCategory.allCases {
            merged.append(contentsOf: load(filename: category.sourceFile,
                                           category: category))
        }
        merged.sort { $0.clubName.lowercased() < $1.clubName.lowercased() }

        clubs   = merged
        saoTeam = loadTeam(filename: "saoTeam")
            .sorted { $0.id < $1.id }
        isLoaded = true
    }

    private func load(filename: String,
                      category: ClubCategory) -> [SAOClub] {
        guard let url = Bundle.main.url(forResource: filename,
                                        withExtension: "json") else {
            loadErrors.append("Missing \(filename).json in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            var clubs = try decoder.decode([SAOClub].self, from: data)
            for i in clubs.indices {
                clubs[i].category = category
            }
            return clubs
        } catch {
            loadErrors.append("Failed to decode \(filename).json — \(error.localizedDescription)")
            return []
        }
    }

    private func loadTeam(filename: String) -> [SAOTeamSemester] {
        guard let url = Bundle.main.url(forResource: filename,
                                        withExtension: "json") else {
            loadErrors.append("Missing \(filename).json in bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode([SAOTeamSemester].self, from: data)
        } catch {
            loadErrors.append("Failed to decode \(filename).json — \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Convenience accessors

    /// Returns only the clubs that belong to the given category.
    func clubs(in category: ClubCategory) -> [SAOClub] {
        clubs.filter { $0.category == category }
    }

    /// All unique semester labels across all clubs, ordered chronologically.
    var allSemesters: [String] {
        let set = clubs.reduce(into: Set<String>()) { acc, club in
            acc.formUnion(club.boardMembers.keys)
            acc.formUnion(club.events.keys)
        }
        return Array(set).sorted(by: SAOClub.semesterIsAscending)
    }

    /// Newest team roster by id (i.e. latest semester recorded).
    var latestTeam: SAOTeamSemester? { saoTeam.last }
}
