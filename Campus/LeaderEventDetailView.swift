//
//  LeaderEventDetailView.swift
//  Campus
//
//  Detail page shown after a leader taps an event card.
//  Hosts the QR code generator, simulate-scan button, and debrief flow.
//

import SwiftUI

struct LeaderEventDetailView: View {
    let eventId: String

    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    @State private var showQR        = false
    @State private var showDebrief   = false
    @State private var lastSimulated: String?

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
                    attendanceCard(event)
                    actionButtons(event)
                    technicalChecklist(event)
                    if let catering = event.catering {
                        CateringCard(catering: catering)
                    }

                    if let debrief = store.debrief(for: event.id) {
                        debriefCard(debrief)
                            .transition(.move(edge: .bottom)
                                .combined(with: .opacity))
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
        .sheet(isPresented: $showQR) {
            QRCodeView(eventId: event.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDebrief) {
            DebriefFormView(eventId: event.id)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Cards

    private func headerCard(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StatusBadge(status: event.status)
                Spacer()
                if let club = store.club(by: event.clubId) {
                    HStack(spacing: 6) {
                        Image(systemName: "person.3.fill").font(.caption)
                        Text(club.name).font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .softCard(radius: 16)
                }
            }
            DetailRow(icon: "mappin.and.ellipse", label: "Venue", value: event.location)
            DetailRow(icon: "clock", label: "Starts",
                      value: event.startTime.formatted(date: .complete, time: .shortened))
            DetailRow(icon: "clock.badge.checkmark", label: "Ends",
                      value: event.endTime.formatted(date: .omitted, time: .shortened))
        }
        .padding(20)
        .glassCard(tint: Theme.accent.opacity(0.15), radius: 24)
    }

    private func technicalChecklist(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Required Technical Equipment",
                  systemImage: "wrench.and.screwdriver.fill")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(event.technicalNeeds, id: \.self) { need in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.accent)
                        Text(need.capitalized)
                        Spacer()
                    }
                    .padding(12)
                    .softCard(radius: 12)
                }
            }
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
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.accent)
                    .contentTransition(.numericText())
                if let last = lastSimulated {
                    Text("Last sim scan: \(last)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            Spacer()
            Image(systemName: "person.3.sequence.fill")
                .font(.system(size: 40))
                .foregroundStyle(Theme.accent.opacity(0.35))
                .symbolEffect(.pulse, options: .repeating,
                              value: event.status == .ongoing)
        }
        .padding(22)
        .glassCard(tint: Theme.accent.opacity(0.32), radius: 26)
        .animation(.spring(response: 0.4, dampingFraction: 0.7),
                   value: store.attendanceCount(for: event.id))
        .animation(.easeInOut(duration: 0.25), value: lastSimulated)
    }

    @ViewBuilder
    private func actionButtons(_ event: CampusEvent) -> some View {
        VStack(spacing: 12) {
            if event.status == .ongoing {
                Button {
                    showQR = true
                } label: {
                    Label("Generate Check-In QR", systemImage: "qrcode")
                }
                .buttonStyle(.glassPrimary)

                Button {
                    let id = store.simulateScan(eventId: event.id)
                    if !id.isEmpty {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            lastSimulated = id
                        }
                    }
                } label: {
                    Label("Simulate Student Scan",
                          systemImage: "wand.and.stars")
                }
                .buttonStyle(.glassSecondary)

                Button {
                    showDebrief = true
                } label: {
                    Label("Complete Event",
                          systemImage: "checkmark.seal.fill")
                }
                .buttonStyle(.glassSecondary)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Event marked completed")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .glassCard(tint: Color.green.opacity(0.25), radius: 18)
            }
        }
    }

    private func debriefCard(_ debrief: EventDebrief) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Post-Event Debrief", systemImage: "doc.text.fill")
                    .font(.headline)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: debrief.occurrenceStatus.systemImage)
                    Text(debrief.occurrenceStatus.rawValue)
                }
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
            }
            DetailRow(icon: "person.3.sequence.fill",
                      label: "Peak attendees",
                      value: "\(debrief.peakAttendees)")
            DetailRow(icon: "tag.fill", label: "Category",
                      value: debrief.eventCategory.rawValue)
            if !debrief.strengths.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Strengths")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowTags(tags: debrief.strengths)
            }
            if !debrief.additionalComments
                .trimmingCharacters(in: .whitespaces).isEmpty {
                Divider().padding(.vertical, 4)
                Text("Comments")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(debrief.additionalComments)
                    .font(.subheadline)
            }
            Divider().padding(.vertical, 4)
            DetailRow(icon: "calendar", label: "Submitted",
                      value: debrief.submittedAt
                        .formatted(date: .abbreviated, time: .shortened))
        }
        .padding(20)
        .glassCard(radius: 24)
    }
}
