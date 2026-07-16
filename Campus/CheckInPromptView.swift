//
//  CheckInPromptView.swift
//  Campus
//
//  Sheet presented on the student's phone after they scan an event QR.
//  Enter Student ID → submit → attendance is appended to the event.
//
//  This view is opened by the deep-link handler in CampusApp when a
//  `campuspulse://checkin?event=<id>` URL arrives.
//

import SwiftUI
import Combine

/// Small ObservableObject that lives at the App root and stores the
/// most recent pending check-in eventId (if any). The root ContentView
/// observes it to present the sheet.
@MainActor
final class PendingCheckIn: ObservableObject {
    @Published var eventId: String?

    func begin(eventId: String) { self.eventId = eventId }
    func clear()                { self.eventId = nil }
}

struct CheckInPromptView: View {
    let eventId: String

    @Environment(\.dismiss)   private var dismiss
    @EnvironmentObject private var store: DataStore
    @EnvironmentObject private var auth:  AuthService

    @State private var studentId: String = ""
    @State private var feedback:  Feedback?

    private var event: CampusEvent? { store.event(by: eventId) }

    var body: some View {
        NavigationStack {
            GlassScene {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                        header
                        idCard
                        submitButton
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                    .contentFrame(max: AppLayout.readingMaxWidth)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button("Cancel") { dismiss() }
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(Theme.accent)
                }
            }
            .onAppear(perform: prefillFromSession)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Check-in").overlineStyle(Theme.accent)
            if let event = event {
                Text(event.title)
                    .font(AppFont.title)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 12) {
                    if let club = store.club(by: event.clubId) {
                        Text(club.name)
                            .font(AppFont.caption)
                            .foregroundStyle(Theme.inkMuted)
                    }
                    Text(event.location)
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
            } else {
                Text("Unknown event")
                    .font(AppFont.title)
                    .foregroundStyle(Theme.ink)
                Text("Ask the SAO leader to re-share the QR.")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
    }

    private var idCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Student ID").overlineStyle()
            Text("Enter your AUI Student ID to mark yourself present.")
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkMuted)

            TextField("e.g. 90234", text: $studentId)
                .iosAutocap()
                .autocorrectionDisabled()
                .font(AppFont.bodyEmphasis)
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(Theme.fill,
                            in: RoundedRectangle(cornerRadius: 12,
                                                 style: .continuous))
                .submitLabel(.send)
                .onSubmit(submit)

            if let f = feedback {
                HStack(spacing: 6) {
                    Image(systemName: f.success ? "checkmark.circle.fill"
                                                : "xmark.octagon.fill")
                    Text(f.text)
                }
                .font(AppFont.captionStrong)
                .foregroundStyle(f.success ? Theme.positive : Theme.negative)
                .transition(.opacity)
            }
        }
        .padding(18)
        .surfaceCard()
    }

    private var submitButton: some View {
        Button(action: submit) {
            Label("Check In", systemImage: "checkmark.circle.fill")
        }
        .buttonStyle(.glassPrimary)
        .disabled(event == nil ||
                  studentId.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    // MARK: - Logic

    private struct Feedback {
        let text: String
        let success: Bool
    }

    private func prefillFromSession() {
        // If the student is signed in as themselves, autofill from the
        // email's local-part as a convenient default. Manual edit stays
        // supported so guests can still enter any ID.
        guard studentId.isEmpty,
              let email = auth.currentUser?.email
        else { return }
        studentId = String(email.split(separator: "@").first ?? "")
    }

    private func submit() {
        guard event != nil else { return }
        let trimmed = studentId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if store.recordAttendance(eventId: eventId, studentId: trimmed) {
            withAnimation(AppMotion.smooth) {
                feedback = Feedback(text: "Checked in as \(trimmed).", success: true)
            }
            // Dismiss after a beat so the student sees the confirmation.
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            }
        } else {
            withAnimation(AppMotion.smooth) {
                feedback = Feedback(text: "\(trimmed) is already checked in.",
                                    success: false)
            }
        }
    }
}
