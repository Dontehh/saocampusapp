//
//  DebriefFormView.swift
//  Campus
//
//  Mandatory 15-question SAO post-event debrief. Until this is submitted
//  the event cannot move out of the `ongoing` status.
//

import SwiftUI

struct DebriefFormView: View {
    let eventId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth:  AuthService
    @EnvironmentObject private var store: DataStore

    // Q1
    @State private var eventCategory: DebriefEventCategory = .club
    // Q2-Q4
    @State private var clubName  = ""
    @State private var eventName = ""
    @State private var eventDate = Date()
    // Q5-Q7
    @State private var occurrence:    DebriefOccurrenceStatus = .happened
    @State private var statusReason  = ""
    @State private var postponedDate = Date()
    // Q8-Q9
    @State private var peakAttendees    = 0
    @State private var relatedToMission = true
    // Q10
    @State private var selectedStrengths: Set<String> = []
    @State private var otherStrengthText = ""
    // Q11-Q12
    @State private var hadCatering            = false
    @State private var cateringOnTime: Bool?  = nil
    // Q13-Q14
    @State private var requiredIntervention = false
    @State private var interventionDetail   = ""
    // Q15
    @State private var additionalComments = ""

    @State private var validationMessage: String?
    @State private var showValidation = false

    private static let presetStrengths = [
        "High Attendance",
        "Started on Time",
        "Smooth Organization",
        "Strong Audience Interaction",
        "Well-Managed Time",
        "Engaging Content",
        "Other",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                SceneBackground()
                Form {
                // Q1-Q4 ----------------------------------------------------
                Section {
                    Picker("1. Event category", selection: $eventCategory) {
                        ForEach(DebriefEventCategory.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    LabeledContent("2. Club name") {
                        TextField("Club", text: $clubName)
                            .multilineTextAlignment(.trailing)
                            .iosAutocap(false)
                    }
                    LabeledContent("3. Event name") {
                        TextField("Title", text: $eventName)
                            .multilineTextAlignment(.trailing)
                            .iosAutocap(false)
                    }
                    DatePicker("4. Date of the event",
                               selection: $eventDate,
                               displayedComponents: .date)
                } header: {
                    Text("Event Info")
                } footer: {
                    Text("Auto-filled from the event record. Override if needed.")
                }

                // Q5-Q7 ----------------------------------------------------
                Section("Event Status") {
                    Picker("5. Event status", selection: $occurrence) {
                        ForEach(DebriefOccurrenceStatus.allCases) { option in
                            Label(option.rawValue,
                                  systemImage: option.systemImage)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    if occurrence != .happened {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("6. Reason of \(occurrence == .postponed ? "postponement" : "cancellation")")
                                .font(.callout)
                            TextField("Reason", text: $statusReason,
                                      axis: .vertical)
                                .lineLimit(2, reservesSpace: true)
                        }
                    }
                    if occurrence == .postponed {
                        DatePicker("7. Postponed to which date",
                                   selection: $postponedDate,
                                   displayedComponents: .date)
                    }
                }

                // Q8 ------------------------------------------------------
                Section {
                    HStack {
                        Text("8. Peak number of attendees")
                        Spacer()
                        Stepper("\(peakAttendees)",
                                value: $peakAttendees, in: 0...20_000)
                            .labelsHidden()
                        Text("\(peakAttendees)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Theme.accent)
                            .frame(minWidth: 60, alignment: .trailing)
                            .contentTransition(.numericText())
                    }
                } header: {
                    Text("Attendance")
                } footer: {
                    Text("Pre-filled from QR check-ins; adjust to reflect peak headcount.")
                }

                // Q9 ------------------------------------------------------
                Section("Mission Alignment") {
                    Picker("9. Related to club's mission?",
                           selection: $relatedToMission) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                // Q10 -----------------------------------------------------
                Section {
                    Text("10. Event strengths")
                        .font(.callout)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 130),
                                                 spacing: 8)],
                              alignment: .leading,
                              spacing: 8) {
                        ForEach(Self.presetStrengths, id: \.self) { item in
                            StrengthChip(label: item,
                                         isOn: selectedStrengths.contains(item)) {
                                withAnimation(.spring(response: 0.3,
                                                      dampingFraction: 0.78)) {
                                    if selectedStrengths.contains(item) {
                                        selectedStrengths.remove(item)
                                    } else {
                                        selectedStrengths.insert(item)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)

                    if selectedStrengths.contains("Other") {
                        TextField("Describe other strength",
                                  text: $otherStrengthText)
                            .iosAutocap(false)
                    }
                } header: {
                    Text("Strengths")
                } footer: {
                    Text("Tap all that apply.")
                }

                // Q11-Q12 -------------------------------------------------
                Section("Catering") {
                    Picker("11. Did this event include catering?",
                           selection: $hadCatering) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if hadCatering {
                        Picker("12. Did it arrive as scheduled?",
                               selection: Binding(
                                get: { cateringOnTime ?? true },
                                set: { cateringOnTime = $0 }
                               )) {
                            Text("Yes").tag(true)
                            Text("No").tag(false)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Q13-Q14 -------------------------------------------------
                Section("SAO Intervention") {
                    Picker("13. Did you have to call for SAO support?",
                           selection: $requiredIntervention) {
                        Text("Yes").tag(true)
                        Text("No").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if requiredIntervention {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("14. How did you intervene?")
                                .font(.callout)
                            TextField("Describe what happened",
                                      text: $interventionDetail,
                                      axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                }

                // Q15 -----------------------------------------------------
                Section("Additional Comments") {
                    TextField("15. Anything else SAO should know?",
                              text: $additionalComments,
                              axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }

                Section {
                    Button(action: submit) {
                        Label("Submit & Mark Completed",
                              systemImage: "paperplane.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .listRowBackground(Color.clear)
                }
            }
                .scrollContentBackground(.hidden)
            }
            .tint(Theme.accent)
            .navigationTitle("Post-Event Debrief")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear(perform: prefill)
            .alert("Please review",
                   isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage ?? "Some required fields are missing.")
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: occurrence)
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: hadCatering)
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: requiredIntervention)
            .animation(.spring(response: 0.3, dampingFraction: 0.85),
                       value: selectedStrengths.contains("Other"))
        }
    }

    // MARK: - Logic

    private func prefill() {
        guard let event = store.event(by: eventId) else { return }
        if eventName.isEmpty { eventName = event.title }
        if clubName.isEmpty,
           let club = store.club(by: event.clubId) {
            clubName = club.name
        }
        eventDate     = event.startTime
        postponedDate = event.startTime
        peakAttendees = store.attendanceCount(for: eventId)
    }

    private func submit() {
        let trimmedClub  = clubName.trimmingCharacters(in: .whitespaces)
        let trimmedEvent = eventName.trimmingCharacters(in: .whitespaces)

        guard !trimmedClub.isEmpty else {
            validationMessage = "Please enter the club name."
            showValidation = true; return
        }
        guard !trimmedEvent.isEmpty else {
            validationMessage = "Please enter the event name."
            showValidation = true; return
        }
        if occurrence != .happened &&
            statusReason.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Please explain why the event was \(occurrence == .postponed ? "postponed" : "cancelled")."
            showValidation = true; return
        }
        if requiredIntervention &&
            interventionDetail.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Please describe how you intervened."
            showValidation = true; return
        }
        if selectedStrengths.contains("Other") &&
            otherStrengthText.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Please describe the 'Other' strength."
            showValidation = true; return
        }

        var strengths = Array(selectedStrengths).sorted()
        if let idx = strengths.firstIndex(of: "Other"),
           !otherStrengthText.trimmingCharacters(in: .whitespaces).isEmpty {
            strengths[idx] = "Other: \(otherStrengthText.trimmingCharacters(in: .whitespaces))"
        }

        let debrief = EventDebrief(
            eventId: eventId,
            leaderId: auth.currentUser?.id ?? "unknown",
            eventCategory: eventCategory,
            clubName: trimmedClub,
            eventName: trimmedEvent,
            eventDate: eventDate,
            occurrenceStatus: occurrence,
            statusReason: statusReason.trimmingCharacters(in: .whitespaces),
            postponedDate: occurrence == .postponed ? postponedDate : nil,
            peakAttendees: peakAttendees,
            relatedToMission: relatedToMission,
            strengths: strengths,
            otherStrength: otherStrengthText.trimmingCharacters(in: .whitespaces),
            hadCatering: hadCatering,
            cateringOnTime: hadCatering ? (cateringOnTime ?? true) : nil,
            requiredIntervention: requiredIntervention,
            interventionDetail: requiredIntervention
                ? interventionDetail.trimmingCharacters(in: .whitespaces)
                : "",
            additionalComments: additionalComments.trimmingCharacters(in: .whitespaces),
            submittedAt: Date()
        )

        store.submitDebrief(debrief)
        dismiss()
    }
}

private struct StrengthChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                Text(label)
                    .lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isOn ? Theme.accent.opacity(0.18)
                     : Theme.surfaceElevated,
                in: Capsule()
            )
            .foregroundStyle(isOn ? Theme.accent : Color.secondary)
            .overlay(
                Capsule().stroke(
                    isOn ? Theme.accent.opacity(0.45) : Color.clear,
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(.plain)
    }
}
