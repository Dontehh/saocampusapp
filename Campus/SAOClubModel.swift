//
//  SAOClubModel.swift
//  Campus
//
//  Unified Codable representation of every SAO club, regardless of the
//  source JSON file. `boardMembers` and `events` are stored as
//  dictionaries keyed by the semester string ("Fall 2024", "Spring 2026"…)
//  because the source data uses dynamic semester keys.
//

import Foundation

// MARK: - Club category (injected at decode time)

enum ClubCategory: String, Codable, Hashable, CaseIterable, Identifiable {
    case cultural      = "Cultural"
    case educational   = "Educational"
    case entertainment = "Entertainment"
    case humanitarian  = "Humanitarian"

    var id: String { rawValue }

    var sourceFile: String {
        switch self {
        case .cultural:      return "culturalClubs"
        case .educational:   return "educationalClubs"
        case .entertainment: return "entertainmentClubs"
        case .humanitarian:  return "humanitarianClubs"
        }
    }

    var systemImage: String {
        switch self {
        case .cultural:      return "globe.europe.africa.fill"
        case .educational:   return "graduationcap.fill"
        case .entertainment: return "theatermasks.fill"
        case .humanitarian:  return "heart.fill"
        }
    }
}

// MARK: - Club

struct SAOClub: Codable, Identifiable, Hashable {
    let clubName: String
    /// Semester string ("Fall 2024") → role → person.
    let boardMembers: [String: [String: String]]
    /// Semester string ("Fall 2024") → list of event titles.
    let events: [String: [String]]

    /// Injected by the loader after decoding so analytics / UI know which
    /// JSON file this club came from.
    var category: ClubCategory?

    var id: String { clubName }

    // The JSON does not contain `category`; we only encode/decode the
    // three core fields and let the loader populate `category`.
    private enum CodingKeys: String, CodingKey {
        case clubName, boardMembers, events
    }

    /// All semester labels present on this club, ordered chronologically.
    var allSemesters: [String] {
        let set = Set(boardMembers.keys).union(events.keys)
        return set.sorted(by: Self.semesterIsAscending)
    }

    /// The most recent semester for which we have data.
    var latestSemester: String? { allSemesters.last }

    /// Convenience for the "current" board (newest semester listed).
    var currentBoard: [String: String] {
        guard let s = latestSemester else { return [:] }
        return boardMembers[s] ?? [:]
    }

    /// Convenience for the "current" event list (newest semester listed).
    var currentEvents: [String] {
        guard let s = latestSemester else { return [] }
        return events[s] ?? []
    }

    var totalEventCount: Int {
        events.values.reduce(0) { $0 + $1.count }
    }
}

// MARK: - Semester ordering

extension SAOClub {
    /// Sort helper: "Spring 2022" < "Summer 2022" < "Fall 2022" < "Spring 2023" …
    nonisolated static func semesterIsAscending(_ lhs: String, _ rhs: String) -> Bool {
        let (lt, ly) = parseSemester(lhs)
        let (rt, ry) = parseSemester(rhs)
        if ly != ry { return ly < ry }
        return lt.order < rt.order
    }

    nonisolated private enum TermBucket: Int {
        case spring = 0, summer = 1, fall = 2, other = 3
        var order: Int { rawValue }
    }

    nonisolated private static func parseSemester(_ raw: String) -> (TermBucket, Int) {
        let parts = raw.split(separator: " ")
        let bucket: TermBucket = {
            switch parts.first?.lowercased() {
            case "spring": return .spring
            case "summer": return .summer
            case "fall":   return .fall
            default:       return .other
            }
        }()
        let year = Int(parts.dropFirst().first ?? "0") ?? 0
        return (bucket, year)
    }
}

// MARK: - SAO Team (admins + leaders per semester)

struct SAOTeamSemester: Codable, Identifiable, Hashable {
    let id: Int
    let semester: String
    let admins:  [String]
    let leaders: [String]
}
