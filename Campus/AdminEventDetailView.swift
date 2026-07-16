//
//  AdminEventDetailView.swift
//  Campus
//
//  Refined admin/staff event detail. Removes card-in-card nesting, uses
//  hairline dividers between rows, restrained accent — only the header
//  and reopen banner carry color.
//

import SwiftUI

struct AdminEventDetailView: View {
    let eventId: String

    @EnvironmentObject private var store: DataStore
    @State private var showAssignSheet   = false
    @State private var showReopenConfirm = false

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
                    reopenBanner(event)
                    infoCard(event)
                    liveAttendance(event)
                    leadersCard(event)
                    technicalCard(event)
                    if let catering = event.catering {
                        CateringCard(catering: catering)
                    }
                    if let d = store.debrief(for: event.id) {
                        debriefCard(d)
                    } else if event.status == .completed {
                        pendingBanner
                    }
                }
                .padding(20)
                .padding(.bottom, 40)
                .contentFrame(max: AppLayout.readingMaxWidth)
                .animation(AppMotion.smooth, value: event.status)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle(event.title)
        .inlineNavTitle()
        .sheet(isPresented: $showAssignSheet) {
            AssignLeadersView(eventId: event.id)
        }
        .alert("Reopen event?", isPresented: $showReopenConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reopen", role: .destructive) {
                store.reopenEvent(eventId: event.id)
            }
        } message: {
            Text("This moves the event back to Ongoing. The leader can resubmit the debrief once complete.")
        }
    }

    // MARK: - Pieces

    private func header(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let club = store.club(by: event.clubId) {
                Text(club.name).overlineStyle(Theme.accent)
            }
            Text(event.title)
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                StatusBadge(status: event.status)
                Text("Window \(event.startTime.formatted(date: .abbreviated, time: .shortened)) → \(event.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func reopenBanner(_ event: CampusEvent) -> some View {
        if event.status == .completed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Event is completed")
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(Theme.ink)
                    Text("Reopen if more work is still needed.")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Button("Reopen") { showReopenConfirm = true }
                    .font(AppFont.captionStrong)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.accent,
                                in: Capsule(style: .continuous))
            }
            .padding(16)
            .background(Theme.accentSoft,
                        in: RoundedRectangle(cornerRadius: AppLayout.cardRadius,
                                             style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cardRadius,
                                 style: .continuous)
                    .stroke(Theme.accent.opacity(0.25),
                            lineWidth: AppLayout.hairline)
            )
        }
    }

    private func infoCard(_ event: CampusEvent) -> some View {
        VStack(spacing: 14) {
            DetailRow(icon: "mappin.and.ellipse",
                      label: "Venue", value: event.location)
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

    private func liveAttendance(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.status == .completed
                 ? "Final Attendance"
                 : "Live Attendance")
                .overlineStyle(Theme.accent)
            Text("\(store.attendanceCount(for: event.id))")
                .font(AppFont.displayNumber)
                .foregroundStyle(Theme.ink)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .heroCard()
    }

    private func leadersCard(_ event: CampusEvent) -> some View {
        let leaders = store.leaders(for: event.id)
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Assigned Leaders").overlineStyle()
                Spacer()
                Button("Manage") { showAssignSheet = true }
                    .font(AppFont.captionStrong)
                    .foregroundStyle(Theme.accent)
            }
            if leaders.isEmpty {
                Text("No leaders assigned yet.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(leaders.enumerated()), id: \.element.id) { index, leader in
                        leaderRow(leader, eventId: event.id)
                        if index != leaders.count - 1 { AppRule() }
                    }
                }
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private func leaderRow(_ leader: AppUser, eventId: String) -> some View {
        let isMain = store.isMainLeader(leader.id, for: eventId)
        return HStack(spacing: 12) {
            Circle()
                .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                .background(Circle().fill(Theme.fill))
                .frame(width: 34, height: 34)
                .overlay(Text(initials(leader.name))
                    .font(AppFont.captionStrong)
                    .foregroundStyle(Theme.ink))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(leader.name)
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(Theme.ink)
                    if isMain {
                        Text("MAIN").overlineStyle(Theme.accent)
                    }
                }
                Text(leader.email)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer()
            if !isMain {
                Button {
                    store.setMainLeader(leaderId: leader.id, for: eventId)
                } label: {
                    Image(systemName: "star")
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Set \(leader.name) as main")
            }
            Button {
                store.unassign(leaderId: leader.id, from: eventId)
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(Theme.negative.opacity(0.85))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(leader.name)")
        }
        .padding(.vertical, 12)
    }

    private func technicalCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Needs").overlineStyle()
            if event.technicalNeeds.isEmpty {
                Text("None requested.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                FlowTags(tags: event.technicalNeeds)
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private var pendingBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "hourglass")
                .foregroundStyle(Theme.warning)
            Text("Debrief pending submission.")
                .font(AppFont.captionStrong)
                .foregroundStyle(Theme.ink)
            Spacer()
        }
        .padding(14)
        .surfaceCard()
    }

    // MARK: - Debrief

    private func debriefCard(_ d: EventDebrief) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Debrief").overlineStyle()
                Spacer()
                Text(d.occurrenceStatus.rawValue)
                    .font(AppFont.captionStrong)
                    .foregroundStyle(Theme.accent)
            }
            debriefBlock(title: "Event",
                         rows: [
                            ("Category",   d.eventCategory.rawValue),
                            ("Club",       d.clubName),
                            ("Name",       d.eventName),
                            ("Date",       d.eventDate.formatted(.dateTime.month().day().year())),
                         ])
            if d.occurrenceStatus != .happened {
                debriefBlock(title: "Status",
                             rows: [("Reason", d.statusReason.isEmpty ? "—" : d.statusReason)])
            }
            debriefBlock(title: "Reach",
                         rows: [
                            ("Peak Attendees",  "\(d.peakAttendees)"),
                            ("Mission Aligned", d.relatedToMission ? "Yes" : "No"),
                         ])
            if !d.strengths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Strengths").overlineStyle()
                    FlowTags(tags: d.strengths)
                }
            }
            debriefBlock(title: "Catering",
                         rows: [
                            ("Included",   d.hadCatering ? "Yes" : "No"),
                            ("On Time",    d.cateringOnTime.map { $0 ? "Yes" : "No" } ?? "—"),
                         ])
            debriefBlock(title: "Intervention",
                         rows: [
                            ("Needed", d.requiredIntervention ? "Yes" : "No"),
                            ("Detail", d.requiredIntervention
                                ? (d.interventionDetail.isEmpty ? "—" : d.interventionDetail)
                                : "—"),
                         ])
            if !d.additionalComments
                .trimmingCharacters(in: .whitespaces).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comments").overlineStyle()
                    Text(d.additionalComments)
                        .font(AppFont.body)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            AppRule()
            HStack {
                Text("Submitted by \(store.user(by: d.leaderId)?.name ?? "—")")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
                Spacer()
                Text(d.submittedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private func debriefBlock(title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).overlineStyle()
            VStack(spacing: 8) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.0)
                            .font(AppFont.caption)
                            .foregroundStyle(Theme.inkMuted)
                        Spacer()
                        Text(entry.1)
                            .font(AppFont.bodyEmphasis)
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
