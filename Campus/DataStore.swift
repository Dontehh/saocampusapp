//
//  DataStore.swift
//  Campus
//
//  Bridges the immutable `ClubsDataManager` (which owns the JSON-decoded
//  SAO clubs + team roster) into the mutable, in-memory CampusPulse state
//  used by every view (events, assignments, attendance, debriefs).
//
//  Users come from saoTeam.json (latest semester), clubs come from the
//  four club JSON files, and events are seeded from each club's most
//  recent semester so analytics and dashboards are populated immediately.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class DataStore: ObservableObject {

    @Published private(set) var users:       [AppUser]          = []
    @Published private(set) var clubs:       [Club]             = []
    @Published private(set) var events:      [CampusEvent]      = []
    @Published private(set) var assignments: [EventAssignment]  = []
    @Published private(set) var attendance:  [Attendance]       = []
    @Published private(set) var debriefs:    [EventDebrief]     = []

    private let clubsManager: ClubsDataManager

    /// Demo accounts shown on the login screen — filled in after seeding.
    private(set) var demoAccounts: [(email: String, role: String)] = []

    /// Re-evaluates auto-completion every minute so events flip to
    /// `.completed` the moment both conditions hold (debrief filed AND
    /// end-time elapsed) without a manual refresh.
    private var autoTask: Task<Void, Never>?

    init(clubsManager: ClubsDataManager) {
        self.clubsManager = clubsManager
        seed()
        refreshAutoCompletion()
        startAutoCompletionTimer()
    }

    deinit {
        autoTask?.cancel()
    }

    // MARK: - Auto-completion

    /// Smart timing rule:
    ///   event.status == .completed  ⇔  a debrief exists AND endTime < now
    /// Run on init, after every debrief submission, and on a 60-second tick.
    func refreshAutoCompletion(now: Date = Date()) {
        let debriefedIds = Set(debriefs.map(\.eventId))
        for i in events.indices {
            let event = events[i]
            let shouldBeCompleted =
                debriefedIds.contains(event.id) && event.endTime < now
            let target: EventStatus = shouldBeCompleted ? .completed : .ongoing
            if events[i].status != target {
                events[i].status = target
            }
        }
    }

    private func startAutoCompletionTimer() {
        autoTask?.cancel()
        autoTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                self?.refreshAutoCompletion()
            }
        }
    }

    // MARK: - Seed

    private func seed() {
        seedUsers()
        seedClubs()
        seedEvents()
        seedAttendanceAndDebriefs()
        buildDemoAccounts()
    }

    private func seedUsers() {
        guard let team = clubsManager.latestTeam else {
            users = []
            return
        }

        let admins = team.admins.enumerated().map { idx, name in
            AppUser(id: "u-admin-\(idx + 1)",
                    name: name,
                    email: Self.email(for: name),
                    role: .admin)
        }
        let leaders = team.leaders.enumerated().map { idx, name in
            AppUser(id: "u-lead-\(idx + 1)",
                    name: name,
                    email: Self.email(for: name),
                    role: .leader)
        }
        users = admins + leaders
    }

    private func seedClubs() {
        clubs = clubsManager.clubs.enumerated().map { idx, club in
            Club(id: "c-\(idx + 1)",
                 name: club.clubName,
                 category: club.category?.rawValue ?? "Other")
        }
    }

    private func seedEvents() {
        let leaders = users.filter { $0.role == .leader }
        guard !leaders.isEmpty, !clubsManager.clubs.isEmpty else { return }

        let venues = [
            "Main Auditorium", "Hall A", "Hall B", "Black Box Theatre",
            "Sports Hall", "Outdoor Amphitheatre", "Conference Room 1",
            "Library Lecture Hall", "Lab 204", "Student Center",
        ]
        let techPool = [
            ["mics", "speakers"],
            ["mics", "speakers", "stage lighting"],
            ["mics", "projector", "cables"],
            ["mics", "LED wall routing", "speakers", "cables"],
            ["projector", "cables"],
            ["mics", "stage lighting"],
            ["speakers", "LED wall routing"],
        ]

        var seedEvents:      [CampusEvent]     = []
        var seedAssignments: [EventAssignment] = []
        var counter = 0
        var leaderCursor = 0
        var pastOffset    = -45   // days
        var futureOffset  =   2   // days

        for (clubIdx, saoClub) in clubsManager.clubs.enumerated() {
            // Pick up to 2 events from the latest semester that actually
            // recorded events. Falls back to scanning earlier semesters.
            let titles = upcomingEventTitles(for: saoClub, limit: 2)
            guard !titles.isEmpty else { continue }

            let clubId = clubs[clubIdx].id

            for (i, title) in titles.enumerated() {
                counter += 1
                let isPast = (i == 0) // first event = recent past, second = upcoming
                let baseOffset: Int = {
                    if isPast {
                        let v = pastOffset
                        pastOffset += 3
                        return v
                    } else {
                        let v = futureOffset
                        futureOffset += 4
                        return v
                    }
                }()
                let baseDate = Calendar.current.date(byAdding: .day,
                                                     value: baseOffset,
                                                     to: Date()) ?? Date()
                let start = Calendar.current.date(bySettingHour: 18,
                                                  minute: 0, second: 0,
                                                  of: baseDate) ?? baseDate
                let end   = Calendar.current.date(byAdding: .hour, value: 3,
                                                  to: start) ?? start

                let eventId = "e-\(counter)"
                seedEvents.append(
                    CampusEvent(
                        id: eventId,
                        title: title,
                        clubId: clubId,
                        location: venues[counter % venues.count],
                        startTime: start,
                        endTime: end,
                        technicalNeeds: techPool[counter % techPool.count],
                        status: isPast ? .completed : .ongoing
                    )
                )
                let leader = leaders[leaderCursor % leaders.count]
                leaderCursor += 1
                seedAssignments.append(
                    EventAssignment(eventId: eventId, leaderId: leader.id)
                )
            }
        }

        events      = seedEvents
        assignments = seedAssignments
    }

    /// Walk the club's semesters from newest to oldest and return up to
    /// `limit` event titles. Clubs that have no recorded events are skipped.
    private func upcomingEventTitles(for club: SAOClub, limit: Int) -> [String] {
        var picks: [String] = []
        for semester in club.allSemesters.reversed() {
            guard picks.count < limit,
                  let titles = club.events[semester], !titles.isEmpty
            else { continue }
            for t in titles {
                let trimmed = t.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, !picks.contains(trimmed) {
                    picks.append(trimmed)
                    if picks.count >= limit { break }
                }
            }
        }
        return picks
    }

    private func seedAttendanceAndDebriefs() {
        var seedAttendance: [Attendance] = []
        var seedDebriefs:   [EventDebrief] = []

        for event in events where event.status == .completed {
            let leaderId = assignments.first { $0.eventId == event.id }?.leaderId
                        ?? "u-lead-1"
            let count = Int.random(in: 40...220)
            for i in 0..<count {
                seedAttendance.append(
                    Attendance(id: UUID().uuidString,
                               eventId: event.id,
                               studentId: String(format: "S%05d-%@",
                                                 i + 1, event.id),
                               scannedAt: event.startTime)
                )
            }

            let strengths: [String] = {
                let pool = ["High Attendance", "Started on Time",
                            "Smooth Organization", "Strong Audience Interaction",
                            "Well-Managed Time", "Engaging Content"]
                return Array(pool.shuffled().prefix(Int.random(in: 2...4)))
            }()

            let club = clubs.first { $0.id == event.clubId }
            seedDebriefs.append(
                EventDebrief(
                    eventId:               event.id,
                    leaderId:              leaderId,
                    eventCategory:         .club,
                    clubName:              club?.name ?? "—",
                    eventName:             event.title,
                    eventDate:             event.startTime,
                    occurrenceStatus:      .happened,
                    statusReason:          "",
                    postponedDate:         nil,
                    peakAttendees:         count,
                    relatedToMission:      true,
                    strengths:             strengths,
                    otherStrength:         "",
                    hadCatering:           Bool.random(),
                    cateringOnTime:        Bool.random(),
                    requiredIntervention:  Bool.random() && Bool.random(),
                    interventionDetail:    "",
                    additionalComments:    "",
                    submittedAt:           event.endTime
                )
            )
        }

        attendance = seedAttendance
        debriefs   = seedDebriefs
    }

    private func buildDemoAccounts() {
        var picks: [(String, String)] = []
        if let admin = users.first(where: { $0.role == .admin }) {
            picks.append((admin.email, "Administrator"))
        }
        if let leaderA = users.first(where: { $0.role == .leader }) {
            picks.append((leaderA.email, "Event Leader"))
        }
        if let leaderB = users.last(where: { $0.role == .leader }),
           leaderB.email != picks.last?.0 {
            picks.append((leaderB.email, "Event Leader"))
        }
        demoAccounts = picks
    }

    // MARK: - Email derivation

    /// AUI Microsoft tenant convention:
    ///   first-name-initial + "." + last-name  @aui.ma
    ///
    /// Middle names are ignored — only the first token contributes the
    /// initial and only the last token contributes the surname.
    ///
    ///   "Aymane Ouajjou"           → "a.ouajjou@aui.ma"
    ///   "Fatima Zahra Belallali"   → "f.belallali@aui.ma"
    ///   "Mohammed Amine Jaddari"   → "m.jaddari@aui.ma"
    static func email(for name: String) -> String {
        let stripped = name
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
        let allowed = CharacterSet.lowercaseLetters
            .union(CharacterSet(charactersIn: " "))
        let cleaned = String(stripped.unicodeScalars.filter { allowed.contains($0) })
        let parts = cleaned
            .split(separator: " ", omittingEmptySubsequences: true)
            .map(String.init)

        let local: String
        switch parts.count {
        case 0:
            local = "user"
        case 1:
            local = parts[0]
        default:
            let initial = parts[0].prefix(1)
            let last    = parts.last ?? ""
            local = "\(initial).\(last)"
        }
        return "\(local)@aui.ma"
    }

    // MARK: - Lookups

    func club(by id: String)    -> Club?         { clubs.first  { $0.id == id } }
    func user(by id: String)    -> AppUser?      { users.first  { $0.id == id } }
    func event(by id: String)   -> CampusEvent?  { events.first { $0.id == id } }
    func debrief(for eventId: String) -> EventDebrief? {
        debriefs.first { $0.eventId == eventId }
    }

    func leaders() -> [AppUser] { users.filter { $0.role == .leader } }

    func leaderIds(for eventId: String) -> [String] {
        assignments.filter { $0.eventId == eventId }.map { $0.leaderId }
    }

    func leaders(for eventId: String) -> [AppUser] {
        leaderIds(for: eventId).compactMap { user(by: $0) }
    }

    func events(for leaderId: String) -> [CampusEvent] {
        let ids = Set(assignments.filter { $0.leaderId == leaderId }.map(\.eventId))
        return events.filter { ids.contains($0.id) }
    }

    func attendanceCount(for eventId: String) -> Int {
        attendance.lazy.filter { $0.eventId == eventId }.count
    }

    // MARK: - Mutations

    @discardableResult
    func recordAttendance(eventId: String, studentId: String) -> Bool {
        let trimmed = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let exists = attendance.contains {
            $0.eventId == eventId &&
            $0.studentId.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !exists else { return false }
        attendance.append(
            Attendance(id: UUID().uuidString,
                       eventId: eventId,
                       studentId: trimmed,
                       scannedAt: Date())
        )
        return true
    }

    @discardableResult
    func simulateScan(eventId: String) -> String {
        var attempts = 0
        repeat {
            let candidate = String(format: "SIM-%04d", Int.random(in: 1000...9999))
            if recordAttendance(eventId: eventId, studentId: candidate) {
                return candidate
            }
            attempts += 1
        } while attempts < 8
        return ""
    }

    @discardableResult
    func createEvent(title: String,
                     clubId: String,
                     location: String,
                     startTime: Date,
                     endTime: Date,
                     technicalNeeds: [String],
                     leaderId: String?) -> String {
        let newId = "e-\(Int(Date().timeIntervalSince1970 * 1000))"
        let event = CampusEvent(
            id: newId,
            title: title,
            clubId: clubId,
            location: location,
            startTime: startTime,
            endTime: endTime,
            technicalNeeds: technicalNeeds,
            status: .ongoing
        )
        events.insert(event, at: 0)
        if let leaderId, !leaderId.isEmpty {
            assignments.append(EventAssignment(eventId: newId, leaderId: leaderId))
        }
        return newId
    }

    func assign(leaderId: String, to eventId: String) {
        guard !assignments.contains(where: { $0.eventId == eventId && $0.leaderId == leaderId }) else { return }
        assignments.append(EventAssignment(eventId: eventId, leaderId: leaderId))
    }

    func unassign(leaderId: String, from eventId: String) {
        assignments.removeAll { $0.eventId == eventId && $0.leaderId == leaderId }
    }

    func submitDebrief(_ debrief: EventDebrief) {
        debriefs.removeAll { $0.eventId == debrief.eventId }
        debriefs.append(debrief)
        // Don't force completion here — let the auto-rule decide. The
        // event only flips to `.completed` once endTime has actually
        // elapsed, so an early-submitted debrief is preserved but the
        // event stays `.ongoing` until the event is actually over.
        refreshAutoCompletion()
    }

    /// Admin-only: take an event out of the completed state. To honor
    /// the smart-timing rule we drop the debrief; the leader resubmits
    /// once the work is wrapped up, and the auto-rule re-flips it the
    /// moment both conditions are satisfied again.
    func reopenEvent(eventId: String) {
        debriefs.removeAll { $0.eventId == eventId }
        refreshAutoCompletion()
    }
}
