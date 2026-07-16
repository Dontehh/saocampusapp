//
//  LeaderEventDetailView.swift
//  Campus
//
//  Refined leader event detail. Two-column-friendly stacking, hairline
//  dividers between rows, a single accent card for the live attendance
//  hero, and toned-down action buttons.
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
                VStack(alignment: .leading, spacing: 20) {
                    header(event)
                    liveAttendance(event)
                    infoCard(event)
                    actions(event)
                    technicalList(event)
                    if let catering = event.catering {
                        CateringCard(catering: catering)
                    }
                    if let debrief = store.debrief(for: event.id) {
                        debriefCard(debrief)
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

    // MARK: - Header

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
                Text(event.startTime.formatted(date: .abbreviated,
                                               time: .shortened))
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Live attendance hero

    private func liveAttendance(_ event: CampusEvent) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(event.status == .completed ? "Final Attendance"
                                                : "Live Attendance")
                    .overlineStyle(Theme.accent)
                Text("\(store.attendanceCount(for: event.id))")
                    .font(AppFont.displayNumber)
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.numericText())
                    .monospacedDigit()
                if let last = lastSimulated {
                    Text("Last check-in · \(last)")
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.inkMuted)
                        .transition(.opacity)
                }
            }
            Spacer()
        }
        .padding(20)
        .heroCard()
        .animation(AppMotion.smooth, value: store.attendanceCount(for: event.id))
        .animation(AppMotion.smooth, value: lastSimulated)
    }

    // MARK: - Info

    private func infoCard(_ event: CampusEvent) -> some View {
        VStack(spacing: 14) {
            DetailRow(icon: "mappin.and.ellipse",
                      label: "Location", value: event.location)
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

    // MARK: - Actions

    @ViewBuilder
    private func actions(_ event: CampusEvent) -> some View {
        if event.status == .ongoing {
            VStack(spacing: 10) {
                Button {
                    showQR = true
                } label: {
                    Label("Generate Check-In QR",
                          systemImage: "qrcode")
                }
                .buttonStyle(.glassPrimary)

                HStack(spacing: 10) {
                    Button {
                        let id = store.simulateScan(eventId: event.id)
                        if !id.isEmpty {
                            withAnimation(AppMotion.smooth) {
                                lastSimulated = id
                            }
                        }
                    } label: {
                        Label("Simulate scan", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.glassSecondary)

                    Button {
                        showDebrief = true
                    } label: {
                        Label("Complete", systemImage: "checkmark.seal")
                    }
                    .buttonStyle(.glassSecondary)
                }
            }
        } else {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                Text("Event marked completed")
            }
            .font(AppFont.captionStrong)
            .foregroundStyle(Theme.positive)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 14)
            .background(Theme.positive.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 14,
                                             style: .continuous))
        }
    }

    // MARK: - Technical needs

    private func technicalList(_ event: CampusEvent) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

    // MARK: - Debrief

    private func debriefCard(_ debrief: EventDebrief) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Debrief").overlineStyle()
                Spacer()
                StatusBadge(status: .completed)
            }
            DetailRow(icon: "person.3", label: "Peak attendees",
                      value: "\(debrief.peakAttendees)")
            if !debrief.strengths.isEmpty {
                AppRule()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Strengths").overlineStyle()
                    FlowTags(tags: debrief.strengths)
                }
            }
            if !debrief.additionalComments
                .trimmingCharacters(in: .whitespaces).isEmpty {
                AppRule()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Comments").overlineStyle()
                    Text(debrief.additionalComments)
                        .font(AppFont.body)
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(18)
        .surfaceCard()
    }
}
