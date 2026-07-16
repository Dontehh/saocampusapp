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
    @Published private(set) var events:      [CampusEvent]      = [] {
        didSet { rebuildEventIndex() }
    }
    @Published private(set) var assignments: [EventAssignment]  = [] {
        didSet { rebuildAssignmentIndex() }
    }
    @Published private(set) var attendance:  [Attendance]       = [] {
        didSet { rebuildAttendanceIndex() }
    }
    @Published private(set) var debriefs:    [EventDebrief]     = [] {
        didSet { rebuildDebriefIndex() }
    }

    // MARK: - Lookup indexes (rebuilt on each source mutation)
    //
    // These trade a small amount of memory for O(1) reads in the hot
    // paths that every list view walks — attendance count per event,
    // leader lookup, and debrief presence checks.

    private var eventIndex:      [String: CampusEvent]     = [:]
    private var attendanceIndex: [String: Int]             = [:]
    private var assignmentIndex: [String: [EventAssignment]] = [:]
    private var debriefIndex:    [String: EventDebrief]    = [:]
    private var userIndex:       [String: AppUser]         = [:]

    private func rebuildEventIndex() {
        eventIndex = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
    }
    private func rebuildAttendanceIndex() {
        var counts: [String: Int] = [:]
        counts.reserveCapacity(events.count)
        for record in attendance {
            counts[record.eventId, default: 0] += 1
        }
        attendanceIndex = counts
    }
    private func rebuildAssignmentIndex() {
        var index: [String: [EventAssignment]] = [:]
        for a in assignments {
            index[a.eventId, default: []].append(a)
        }
        assignmentIndex = index
    }
    private func rebuildDebriefIndex() {
        debriefIndex = Dictionary(uniqueKeysWithValues: debriefs.map { ($0.eventId, $0) })
    }
    private func rebuildUserIndex() {
        userIndex = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }

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
        // `didSet` fires on subsequent assignments but not on the
        // initial value the property was declared with, so we rebuild
        // every index once seeding is done.
        rebuildUserIndex()
        rebuildEventIndex()
        rebuildAttendanceIndex()
        rebuildAssignmentIndex()
        rebuildDebriefIndex()
    }

    /// Actual on-campus venues that SAO books events into. Exposed
    /// publicly so CreateEventView (and any future venue filters) share
    /// the same canonical list.
    static let campusVenues: [String] = [
        "Auditorium 4",
        "Auditorium 8b",
        "Zen Space",
        "Event Room",
        "SAO Lounge",
        "Auditorium 17",
        "Auditorium 16",
    ]

    /// Assigned university staff (outside SAO leadership) who need the
    /// same view as admins. Emails are provided verbatim by SAO — do not
    /// derive from the name-to-email rule (they diverge for cases like
    /// "Ayoub" which uses a two-letter prefix to disambiguate).
    private static let seededStaff: [(name: String, email: String)] = [
        (name: "Ayoub Bounasser",   email: "ay.bounasser@aui.ma"),
        (name: "Soumiya Bellabair", email: "s.bellabair@aui.ma"),
        (name: "Farah Boukarmane",  email: "f.boukarmane@aui.ma"),
    ]

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
        let staff = Self.seededStaff.enumerated().map { idx, member in
            AppUser(id: "u-staff-\(idx + 1)",
                    name: member.name,
                    email: member.email,
                    role: .staff)
        }
        users = admins + leaders + staff
    }

    /// Provision a general-student record for any @aui.ma email that
    /// isn't already on the roster. Called by AuthService the first
    /// time a student signs in.
    @discardableResult
    func provisionStudent(email rawEmail: String) -> AppUser {
        let email = rawEmail.lowercased()
        if let existing = users.first(where: { $0.email.lowercased() == email }) {
            return existing
        }
        let student = AppUser(
            id: "u-student-\(email)",
            name: Self.displayName(from: email),
            email: email,
            role: .student
        )
        users.append(student)
        return student
    }

    /// Turn "j.smith@aui.ma" → "J. Smith" for the student's display name.
    static func displayName(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "Student"
        let parts = local
            .split(separator: ".", omittingEmptySubsequences: true)
            .map(String.init)
        guard !parts.isEmpty else { return "Student" }
        if parts.count == 1 { return parts[0].capitalized }
        // First token becomes "J." (single-letter initial keeps its dot),
        // subsequent tokens get full capitalisation.
        let head = parts.first!
        let tail = parts.dropFirst().map { $0.capitalized }.joined(separator: " ")
        let leading = head.count == 1
            ? "\(head.uppercased())."
            : head.capitalized
        return "\(leading) \(tail)".trimmingCharacters(in: .whitespaces)
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

        let venues = Self.campusVenues
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
                    EventAssignment(eventId: eventId,
                                    leaderId: leader.id,
                                    isMain: true)
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
        if let leader = users.first(where: { $0.role == .leader }) {
            picks.append((leader.email, "Event Leader"))
        }
        if let staff = users.first(where: { $0.role == .staff }) {
            picks.append((staff.email, "Assigned Staff"))
        }
        // Any un-rostered @aui.ma email is auto-provisioned as a student.
        picks.append(("student@aui.ma", "Student (auto)"))
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

    // MARK: - Lookups (O(1) via the maintained indexes)

    func club(by id: String)    -> Club?         { clubs.first  { $0.id == id } }
    func user(by id: String)    -> AppUser?      { userIndex[id] }
    func event(by id: String)   -> CampusEvent?  { eventIndex[id] }
    func debrief(for eventId: String) -> EventDebrief? { debriefIndex[eventId] }

    func leaders() -> [AppUser] { users.filter { $0.role == .leader } }

    /// All leaders assigned to an event, main first.
    func leaders(for eventId: String) -> [AppUser] {
        let rows = assignmentIndex[eventId] ?? []
        let ordered = rows.sorted { $0.isMain && !$1.isMain }
        return ordered.compactMap { userIndex[$0.leaderId] }
    }

    func leaderIds(for eventId: String) -> [String] {
        leaders(for: eventId).map(\.id)
    }

    /// The primary/main leader assigned to an event, if one is designated.
    /// Falls back to the first assigned leader when no main has been set.
    func mainLeader(for eventId: String) -> AppUser? {
        let rows = assignmentIndex[eventId] ?? []
        if let mainRow = rows.first(where: { $0.isMain }),
           let user = userIndex[mainRow.leaderId] {
            return user
        }
        return rows.first.flatMap { userIndex[$0.leaderId] }
    }

    func isMainLeader(_ leaderId: String, for eventId: String) -> Bool {
        (assignmentIndex[eventId] ?? [])
            .contains { $0.leaderId == leaderId && $0.isMain }
    }

    func events(for leaderId: String) -> [CampusEvent] {
        let ids = Set(assignments.filter { $0.leaderId == leaderId }.map(\.eventId))
        return events.filter { ids.contains($0.id) }
    }

    func attendanceCount(for eventId: String) -> Int {
        attendanceIndex[eventId] ?? 0
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
                     leaderId: String?,
                     catering: EventCatering? = nil) -> String {
        let newId = "e-\(Int(Date().timeIntervalSince1970 * 1000))"
        let event = CampusEvent(
            id: newId,
            title: title,
            clubId: clubId,
            location: location,
            startTime: startTime,
            endTime: endTime,
            technicalNeeds: technicalNeeds,
            status: .ongoing,
            catering: catering
        )
        events.insert(event, at: 0)
        if let leaderId, !leaderId.isEmpty {
            assignments.append(
                EventAssignment(eventId: newId,
                                leaderId: leaderId,
                                isMain: true)
            )
        }
        return newId
    }

    /// Assign a leader to an event. If `asMain` is true (or nothing else
    /// is main yet) the leader is promoted to the primary contact and
    /// any other main flag for that event is cleared.
    func assign(leaderId: String, to eventId: String, asMain: Bool = false) {
        guard !assignments.contains(where: {
            $0.eventId == eventId && $0.leaderId == leaderId
        }) else { return }

        let hasMain    = assignments.contains { $0.eventId == eventId && $0.isMain }
        let becomeMain = asMain || !hasMain

        if becomeMain && hasMain {
            demoteMain(for: eventId)
        }
        assignments.append(
            EventAssignment(eventId: eventId,
                            leaderId: leaderId,
                            isMain: becomeMain)
        )
    }

    /// Promote an existing assignment to main. Only works for leaders
    /// already assigned to the event.
    func setMainLeader(leaderId: String, for eventId: String) {
        guard assignments.contains(where: {
            $0.eventId == eventId && $0.leaderId == leaderId
        }) else { return }
        for i in assignments.indices where assignments[i].eventId == eventId {
            assignments[i].isMain = (assignments[i].leaderId == leaderId)
        }
    }

    func unassign(leaderId: String, from eventId: String) {
        let wasMain = assignments.contains {
            $0.eventId == eventId && $0.leaderId == leaderId && $0.isMain
        }
        assignments.removeAll {
            $0.eventId == eventId && $0.leaderId == leaderId
        }
        if wasMain,
           let idx = assignments.firstIndex(where: { $0.eventId == eventId }) {
            assignments[idx].isMain = true
        }
    }

    private func demoteMain(for eventId: String) {
        for i in assignments.indices
        where assignments[i].eventId == eventId && assignments[i].isMain {
            assignments[i].isMain = false
        }
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
