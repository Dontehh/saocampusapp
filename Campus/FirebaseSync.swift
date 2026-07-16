//
//  FirebaseSync.swift
//  Campus
//
//  Cross-device backend. Guarded with `canImport(FirebaseFirestore)`
//  so the project still builds without the SDK — as soon as the
//  Firebase iOS SDK is added via Swift Package Manager, this file
//  starts syncing events / assignments / attendance / debriefs to
//  Firestore in real time.
//
//  Setup instructions live in `firebase-setup.md` at the project root.
//

import Foundation
import Combine
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

@MainActor
final class FirebaseSync {
    static let shared = FirebaseSync()
    private init() {}

    /// True once the Firebase SDK is compiled in AND the app called
    /// `FirebaseApp.configure()` successfully. Views that want to
    /// display connection state can bind to this.
    private(set) var isEnabled: Bool = false

    #if canImport(FirebaseFirestore)
    private var db: Firestore { Firestore.firestore() }
    private var eventsListener:      ListenerRegistration?
    private var assignmentsListener: ListenerRegistration?
    private var attendanceListener:  ListenerRegistration?
    private var debriefsListener:    ListenerRegistration?
    #endif

    // MARK: - Start / stop

    /// Called once at app launch (after `FirebaseApp.configure()`).
    /// Attaches snapshot listeners that push remote changes into the
    /// local DataStore so every device sees the same data.
    func start(dataStore: DataStore) {
        #if canImport(FirebaseFirestore)
        isEnabled = true
        listenEvents(into: dataStore)
        listenAssignments(into: dataStore)
        listenAttendance(into: dataStore)
        listenDebriefs(into: dataStore)
        #endif
    }

    func stop() {
        #if canImport(FirebaseFirestore)
        eventsListener?.remove();      eventsListener = nil
        assignmentsListener?.remove(); assignmentsListener = nil
        attendanceListener?.remove();  attendanceListener = nil
        debriefsListener?.remove();    debriefsListener = nil
        isEnabled = false
        #endif
    }

    // MARK: - Writes (invoked by DataStore mutations)

    func upsertEvent(_ event: CampusEvent) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("events").document(event.id)
            .setData(event.firestorePayload, merge: true)
        #endif
    }

    func upsertAssignment(_ a: EventAssignment) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("assignments").document(a.id)
            .setData(a.firestorePayload, merge: true)
        #endif
    }

    func removeAssignment(id: String) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("assignments").document(id).delete()
        #endif
    }

    func upsertAttendance(_ record: Attendance) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("attendance").document(record.id)
            .setData(record.firestorePayload, merge: true)
        #endif
    }

    func upsertDebrief(_ debrief: EventDebrief) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("debriefs").document(debrief.id)
            .setData(debrief.firestorePayload, merge: true)
        #endif
    }

    func removeDebrief(id: String) {
        #if canImport(FirebaseFirestore)
        guard isEnabled else { return }
        db.collection("debriefs").document(id).delete()
        #endif
    }

    // MARK: - Listeners

    #if canImport(FirebaseFirestore)
    private func listenEvents(into dataStore: DataStore) {
        eventsListener = db.collection("events")
            .addSnapshotListener { [weak dataStore] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let events = docs.compactMap { CampusEvent(firestore: $0) }
                Task { @MainActor in
                    dataStore?.replaceEvents(with: events)
                }
            }
    }

    private func listenAssignments(into dataStore: DataStore) {
        assignmentsListener = db.collection("assignments")
            .addSnapshotListener { [weak dataStore] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let list = docs.compactMap { EventAssignment(firestore: $0) }
                Task { @MainActor in
                    dataStore?.replaceAssignments(with: list)
                }
            }
    }

    private func listenAttendance(into dataStore: DataStore) {
        attendanceListener = db.collection("attendance")
            .addSnapshotListener { [weak dataStore] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let list = docs.compactMap { Attendance(firestore: $0) }
                Task { @MainActor in
                    dataStore?.replaceAttendance(with: list)
                }
            }
    }

    private func listenDebriefs(into dataStore: DataStore) {
        debriefsListener = db.collection("debriefs")
            .addSnapshotListener { [weak dataStore] snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let list = docs.compactMap { EventDebrief(firestore: $0) }
                Task { @MainActor in
                    dataStore?.replaceDebriefs(with: list)
                }
            }
    }
    #endif
}

// MARK: - Model ↔ Firestore

#if canImport(FirebaseFirestore)

extension CampusEvent {
    var firestorePayload: [String: Any] {
        [
            "id":              id,
            "title":           title,
            "clubId":          clubId,
            "location":        location,
            "startTime":       Timestamp(date: startTime),
            "endTime":         Timestamp(date: endTime),
            "technicalNeeds":  technicalNeeds,
            "status":          status.rawValue,
            "cateringNotes":   catering?.notes ?? NSNull(),
        ]
    }

    init?(firestore snap: QueryDocumentSnapshot) {
        let d = snap.data()
        guard
            let title    = d["title"]    as? String,
            let clubId   = d["clubId"]   as? String,
            let location = d["location"] as? String,
            let startTS  = d["startTime"] as? Timestamp,
            let endTS    = d["endTime"]   as? Timestamp,
            let needs    = d["technicalNeeds"] as? [String],
            let statusRaw = d["status"]  as? String,
            let status   = EventStatus(rawValue: statusRaw)
        else { return nil }
        let cateringNotes = d["cateringNotes"] as? String
        self.init(
            id: snap.documentID,
            title: title,
            clubId: clubId,
            location: location,
            startTime: startTS.dateValue(),
            endTime:   endTS.dateValue(),
            technicalNeeds: needs,
            status: status,
            catering: (cateringNotes.flatMap { $0.isEmpty ? nil : EventCatering(notes: $0) })
        )
    }
}

extension EventAssignment {
    var firestorePayload: [String: Any] {
        [
            "eventId":  eventId,
            "leaderId": leaderId,
            "isMain":   isMain,
        ]
    }

    init?(firestore snap: QueryDocumentSnapshot) {
        let d = snap.data()
        guard let eventId  = d["eventId"]  as? String,
              let leaderId = d["leaderId"] as? String
        else { return nil }
        self.init(
            eventId: eventId,
            leaderId: leaderId,
            isMain: d["isMain"] as? Bool ?? false
        )
    }
}

extension Attendance {
    var firestorePayload: [String: Any] {
        [
            "eventId":   eventId,
            "studentId": studentId,
            "scannedAt": Timestamp(date: scannedAt),
        ]
    }

    init?(firestore snap: QueryDocumentSnapshot) {
        let d = snap.data()
        guard let eventId   = d["eventId"]   as? String,
              let studentId = d["studentId"] as? String,
              let ts        = d["scannedAt"] as? Timestamp
        else { return nil }
        self.init(
            id: snap.documentID,
            eventId: eventId,
            studentId: studentId,
            scannedAt: ts.dateValue()
        )
    }
}

extension EventDebrief {
    var firestorePayload: [String: Any] {
        [
            "eventId":           eventId,
            "leaderId":          leaderId,
            "eventCategory":     eventCategory.rawValue,
            "clubName":          clubName,
            "eventName":         eventName,
            "eventDate":         Timestamp(date: eventDate),
            "occurrenceStatus":  occurrenceStatus.rawValue,
            "statusReason":      statusReason,
            "postponedDate":     postponedDate.map { Timestamp(date: $0) } as Any,
            "peakAttendees":     peakAttendees,
            "relatedToMission":  relatedToMission,
            "strengths":         strengths,
            "otherStrength":     otherStrength,
            "hadCatering":       hadCatering,
            "cateringOnTime":    cateringOnTime as Any,
            "requiredIntervention": requiredIntervention,
            "interventionDetail":   interventionDetail,
            "additionalComments":   additionalComments,
            "submittedAt":       Timestamp(date: submittedAt),
        ]
    }

    init?(firestore snap: QueryDocumentSnapshot) {
        let d = snap.data()
        guard let eventId  = d["eventId"]  as? String,
              let leaderId = d["leaderId"] as? String,
              let categoryRaw = d["eventCategory"] as? String,
              let category    = DebriefEventCategory(rawValue: categoryRaw),
              let clubName    = d["clubName"]  as? String,
              let eventName   = d["eventName"] as? String,
              let eventDateTS = d["eventDate"] as? Timestamp,
              let occRaw      = d["occurrenceStatus"] as? String,
              let occ         = DebriefOccurrenceStatus(rawValue: occRaw),
              let peak        = d["peakAttendees"] as? Int,
              let relatesTo   = d["relatedToMission"] as? Bool,
              let strengths   = d["strengths"] as? [String],
              let hadCatering = d["hadCatering"] as? Bool,
              let neededHelp  = d["requiredIntervention"] as? Bool,
              let submittedAt = d["submittedAt"] as? Timestamp
        else { return nil }
        self.init(
            eventId: eventId,
            leaderId: leaderId,
            eventCategory: category,
            clubName: clubName,
            eventName: eventName,
            eventDate: eventDateTS.dateValue(),
            occurrenceStatus: occ,
            statusReason: d["statusReason"] as? String ?? "",
            postponedDate: (d["postponedDate"] as? Timestamp)?.dateValue(),
            peakAttendees: peak,
            relatedToMission: relatesTo,
            strengths: strengths,
            otherStrength: d["otherStrength"] as? String ?? "",
            hadCatering: hadCatering,
            cateringOnTime: d["cateringOnTime"] as? Bool,
            requiredIntervention: neededHelp,
            interventionDetail: d["interventionDetail"] as? String ?? "",
            additionalComments: d["additionalComments"] as? String ?? "",
            submittedAt: submittedAt.dateValue()
        )
    }
}

#endif
