//
//  Models.swift
//  Campus
//
//  Schema mirrors the backend (Firestore/Supabase) collections.
//

import Foundation

// MARK: - Users

enum UserRole: String, Codable, CaseIterable, Hashable {
    /// SAO administrators — full read/write access to every screen.
    case admin
    /// SAO event leaders — run assigned events, generate check-in QRs,
    /// file post-event debriefs.
    case leader
    /// Assigned university staff who need the same read/write surface
    /// as an admin (faculty coordinators, registrar liaisons, etc.).
    case staff
    /// General AUI students — read-only browsing of on-campus events
    /// and clubs. Auto-provisioned on first sign-in.
    case student
}

/// Roles are pre-assigned in the backend by staff. Users cannot change their own role.
struct AppUser: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let email: String
    let role: UserRole
}

// MARK: - Clubs

struct Club: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: String
}

// MARK: - Events

/// `ongoing` covers any event that hasn't been wrapped yet (planned + in-progress).
/// `completed` is set once the leader submits the post-event debrief.
/// Admins can flip a completed event back to `ongoing`.
enum EventStatus: String, Codable, CaseIterable, Hashable {
    case ongoing
    case completed
}

/// Optional catering plan attached to an event at creation time.
/// Absent when the event doesn't include food service. `notes` is a
/// free-form description of what's needed (menu, servings, dietary
/// requirements, delivery timing, etc.).
struct EventCatering: Codable, Hashable {
    var notes: String
}

struct CampusEvent: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var clubId: String
    var location: String
    var startTime: Date
    var endTime: Date
    var technicalNeeds: [String]
    var status: EventStatus
    var catering: EventCatering? = nil
}

// MARK: - Assignments

struct EventAssignment: Identifiable, Codable, Hashable {
    var id: String { "\(eventId)::\(leaderId)" }
    let eventId:  String
    let leaderId: String
    /// True for the single leader designated as the primary contact for
    /// the event. There is at most one main per event.
    var isMain:   Bool = false
}

// MARK: - Attendance

struct Attendance: Identifiable, Codable, Hashable {
    let id: String
    let eventId: String
    let studentId: String
    let scannedAt: Date
}

// MARK: - Debriefs

enum DebriefEventCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case sao    = "SAO"
    case club   = "Club"
    case collab = "SAO & Club Collab"
    var id: String { rawValue }
}

enum DebriefOccurrenceStatus: String, Codable, CaseIterable, Identifiable, Hashable {
    case happened  = "Happened as planned"
    case postponed = "Postponed"
    case cancelled = "Cancelled"
    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .happened:  return "checkmark.circle.fill"
        case .postponed: return "calendar.badge.exclamationmark"
        case .cancelled: return "xmark.octagon.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .happened:  return "green"
        case .postponed: return "orange"
        case .cancelled: return "red"
        }
    }
}

/// The 15-question SAO post-event debrief. Mandatory before an event
/// can be marked `completed`.
struct EventDebrief: Identifiable, Codable, Hashable {
    var id: String { eventId }
    let eventId:  String
    let leaderId: String

    // Q1–Q15
    var eventCategory:       DebriefEventCategory     // Q1
    var clubName:            String                   // Q2
    var eventName:           String                   // Q3
    var eventDate:           Date                     // Q4
    var occurrenceStatus:    DebriefOccurrenceStatus  // Q5
    var statusReason:        String                   // Q6  (postponed/cancelled)
    var postponedDate:       Date?                    // Q7  (postponed only)
    var peakAttendees:       Int                      // Q8
    var relatedToMission:    Bool                     // Q9
    var strengths:           [String]                 // Q10 (multi-select + Other)
    var otherStrength:       String                   // Q10 free text when Other selected
    var hadCatering:         Bool                     // Q11
    var cateringOnTime:      Bool?                    // Q12 (only if hadCatering)
    var requiredIntervention: Bool                    // Q13
    var interventionDetail:  String                   // Q14
    var additionalComments:  String                   // Q15

    let submittedAt: Date
}
