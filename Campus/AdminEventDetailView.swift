//
//  AdminEventDetailView.swift
//  Campus
//
//  Read-and-manage screen for admins. Shows full event info, live
//  attendance, leader debrief notes, lets admins (un)assign leaders,
//  and allows reopening a completed event back to `ongoing`.
//

import SwiftUI

struct AdminEventDetailView: View {
    let eventId: String

    @EnvironmentObject private var store: DataStore
    @State private var showAssignSheet = false
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
                VStack(alignment: .leading, spacing: 18) {
                    headerCard(event)
                    statusActionsCard(event)
                    leadersCard(event)
                    technicalCard(event)
                    attendanceCard(event)

                    if let debrief = store.debrief(for: event.id) {
                        debriefCard(debrief)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else if event.status == .completed {
                        Label("Debrief pending submission.",
                              systemImage: "hourglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(radius: 18)
                    }
                }
                .padding(20)
                .animation(.spring(response: 0.35, dampingFraction: 0.85),
                           value: event.status)
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
            Text("This will move the event back to Ongoing. The current debrief is preserved but the leader can submit a new one.")
        }
    }

    // MARK: - Cards

    private func headerCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StatusBadge(status: event.status)
                Spacer()
                if let club = store.club(by: event.clubId) {
                    Text(club.name)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .softCard(radius: 18)
                }
            }
            DetailRow(icon: "mappin.and.ellipse", label: "Venue",
                      value: event.location)
            DetailRow(icon: "clock", label: "Window",
                      value: "\(event.startTime.formatted(date: .abbreviated, time: .shortened)) → \(event.endTime.formatted(date: .omitted, time: .shortened))")
        }
        .padding(20)
        .glassCard(radius: 24)
    }

    @ViewBuilder
    private func statusActionsCard(_ event: CampusEvent) -> some View {
        if event.status == .completed {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Event is completed")
                        .font(.subheadline.weight(.semibold))
                    Text("Reopen if more work is still needed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showReopenConfirm = true
                } label: {
                    Label("Reopen", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .controlSize(.small)
            }
            .padding(16)
            .glassCard(tint: Theme.accent.opacity(0.32), radius: 18)
        }
    }

    private func leadersCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Assigned Leaders",
                      systemImage: "person.badge.shield.checkmark.fill")
                    .font(.headline)
                Spacer()
                Button {
                    showAssignSheet = true
                } label: {
                    Label("Manage", systemImage: "pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
            }

            let leaders = store.leaders(for: event.id)
            if leaders.isEmpty {
                Text("No leaders assigned yet. Tap Manage to add one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(leaders) { leader in
                        leaderRow(leader, eventId: event.id)
                    }
                }
            }
        }
        .padding(20)
        .glassCard(radius: 24)
    }

    private func leaderRow(_ leader: AppUser, eventId: String) -> some View {
        HStack {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading) {
                Text(leader.name)
                    .font(.subheadline.weight(.semibold))
                Text(leader.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.unassign(leaderId: leader.id, from: eventId)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red.opacity(0.85))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(leader.name)")
        }
        .padding(14)
        .softCard(radius: 14)
    }

    private func technicalCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Technical Needs",
                  systemImage: "wrench.and.screwdriver.fill")
                .font(.headline)
            FlowTags(tags: event.technicalNeeds)
        }
        .padding(20)
        .glassCard(radius: 24)
    }

    private func attendanceCard(_ event: CampusEvent) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Live Attendance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("\(store.attendanceCount(for: event.id))")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
            }
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 38))
                .foregroundStyle(Theme.accent.opacity(0.35))
        }
        .padding(22)
        .glassCard(tint: Theme.accent.opacity(0.32), radius: 26)
    }

    // MARK: - Debrief display (full 15-question view)

    private func debriefCard(_ debrief: EventDebrief) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Post-Event Debrief", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                occurrenceBadge(debrief.occurrenceStatus)
            }

            // Q1-Q4
            sectionLabel("Event")
            DetailRow(icon: "tag.fill",
                      label: "1. Category",
                      value: debrief.eventCategory.rawValue)
            DetailRow(icon: "person.3.fill",
                      label: "2. Club",
                      value: debrief.clubName)
            DetailRow(icon: "calendar.badge.checkmark",
                      label: "3. Event name",
                      value: debrief.eventName)
            DetailRow(icon: "calendar",
                      label: "4. Date",
                      value: debrief.eventDate
                        .formatted(.dateTime.month().day().year()))

            // Q5-Q7
            sectionLabel("Status")
            DetailRow(icon: debrief.occurrenceStatus.systemImage,
                      label: "5. Event status",
                      value: debrief.occurrenceStatus.rawValue)
            if debrief.occurrenceStatus != .happened {
                DetailRow(icon: "exclamationmark.bubble",
                          label: "6. Reason",
                          value: debrief.statusReason.isEmpty
                            ? "—" : debrief.statusReason)
            }
            if debrief.occurrenceStatus == .postponed,
               let date = debrief.postponedDate {
                DetailRow(icon: "calendar.badge.plus",
                          label: "7. Postponed to",
                          value: date.formatted(.dateTime.month().day().year()))
            }

            // Q8-Q9
            sectionLabel("Reach")
            DetailRow(icon: "person.3.sequence.fill",
                      label: "8. Peak attendees",
                      value: "\(debrief.peakAttendees)")
            DetailRow(icon: "target",
                      label: "9. Relates to club's mission",
                      value: debrief.relatedToMission ? "Yes" : "No")

            // Q10
            if !debrief.strengths.isEmpty {
                sectionLabel("Strengths")
                FlowTags(tags: debrief.strengths)
            }

            // Q11-Q12
            sectionLabel("Catering")
            DetailRow(icon: "fork.knife",
                      label: "11. Catering included",
                      value: debrief.hadCatering ? "Yes" : "No")
            if debrief.hadCatering, let onTime = debrief.cateringOnTime {
                DetailRow(icon: "clock.badge.checkmark",
                          label: "12. Arrived as scheduled",
                          value: onTime ? "Yes" : "No")
            }

            // Q13-Q14
            sectionLabel("SAO intervention")
            DetailRow(icon: "exclamationmark.shield.fill",
                      label: "13. Needed support",
                      value: debrief.requiredIntervention ? "Yes" : "No")
            if debrief.requiredIntervention {
                DetailRow(icon: "text.bubble.fill",
                          label: "14. How",
                          value: debrief.interventionDetail.isEmpty
                            ? "—" : debrief.interventionDetail)
            }

            // Q15
            if !debrief.additionalComments
                .trimmingCharacters(in: .whitespaces).isEmpty {
                sectionLabel("Comments")
                Text(debrief.additionalComments)
                    .font(.subheadline)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .softCard(radius: 12)
            }

            Divider().padding(.top, 4)
            HStack {
                Image(systemName: "person.crop.rectangle")
                    .foregroundStyle(.secondary)
                Text("Submitted by \(store.user(by: debrief.leaderId)?.name ?? "—")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(debrief.submittedAt
                        .formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .glassCard(radius: 24)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.6)
            .foregroundStyle(Theme.accent)
            .padding(.top, 4)
    }

    private func occurrenceBadge(_ status: DebriefOccurrenceStatus) -> some View {
        HStack(spacing: 6) {
            Image(systemName: status.systemImage)
            Text(status.rawValue)
        }
        .font(.caption2.weight(.bold))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(occurrenceColor(status).opacity(0.18), in: Capsule())
        .foregroundStyle(occurrenceColor(status))
    }

    private func occurrenceColor(_ status: DebriefOccurrenceStatus) -> Color {
        switch status {
        case .happened:  return .green
        case .postponed: return Theme.accent
        case .cancelled: return .red
        }
    }
}
