//
//  CreateEventView.swift
//  Campus
//
//  Admin sheet for creating a new event. Validates required fields,
//  then writes through DataStore.createEvent(...).
//

import SwiftUI

struct CreateEventView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore

    @State private var title:    String = ""
    @State private var clubId:   String = ""
    @State private var location: String = ""
    @State private var start:    Date   = Self.defaultStart
    @State private var end:      Date   = Self.defaultEnd
    @State private var leaderId: String = ""
    @State private var customNeed: String = ""
    @State private var needs: Set<String> = []

    @State private var showValidation = false
    @State private var validationMessage = ""

    private static var defaultStart: Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0,
                              of: Calendar.current.date(byAdding: .day,
                                                        value: 1,
                                                        to: Date()) ?? Date())
            ?? Date()
    }

    private static var defaultEnd: Date {
        Calendar.current.date(byAdding: .hour, value: 3,
                              to: defaultStart) ?? defaultStart
    }

    private let presetNeeds = [
        "mics", "speakers", "stage lighting", "LED wall routing",
        "projector", "cables", "scoreboard", "live stream"
    ]

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty &&
        !clubId.isEmpty &&
        start < end
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SceneBackground()
                Form {
                Section("Event") {
                    TextField("Title", text: $title)
                    Picker("Club", selection: $clubId) {
                        Text("Select a club").tag("")
                        ForEach(store.clubs) { club in
                            Text(club.name).tag(club.id)
                        }
                    }
                    TextField("Location / venue", text: $location)
                }

                Section("Schedule") {
                    DatePicker("Starts", selection: $start)
                    DatePicker("Ends",   selection: $end)
                    if start >= end {
                        Label("End time must be after start time.",
                              systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    presetGrid
                    customNeedField
                } header: {
                    Text("Technical Needs")
                } footer: {
                    Text("Tap a chip to toggle it. Add custom needs below if missing.")
                }

                Section("Assign Leader (optional)") {
                    Picker("Leader", selection: $leaderId) {
                        Text("Unassigned").tag("")
                        ForEach(store.leaders()) { leader in
                            Text(leader.name).tag(leader.id)
                        }
                    }
                }

                Section {
                    Button(action: submit) {
                        Label("Create Event", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSubmit)
                    .listRowBackground(Color.clear)
                }
            }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("New Event")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .leadingBar) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Cannot create event",
                   isPresented: $showValidation) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
        }
    }

    // MARK: - Pieces

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
                  alignment: .leading,
                  spacing: 8) {
            ForEach(presetNeeds, id: \.self) { item in
                NeedChip(label: item, isOn: needs.contains(item)) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        if needs.contains(item) {
                            needs.remove(item)
                        } else {
                            needs.insert(item)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var customNeedField: some View {
        HStack {
            TextField("Add custom need…", text: $customNeed)
                .iosAutocap()
                .submitLabel(.done)
                .onSubmit(addCustomNeed)
            Button {
                addCustomNeed()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(customNeed.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Actions

    private func addCustomNeed() {
        let trimmed = customNeed
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !trimmed.isEmpty else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            needs.insert(trimmed)
            customNeed = ""
        }
    }

    private func submit() {
        let trimmedTitle    = title.trimmingCharacters(in: .whitespaces)
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter a title."
            showValidation = true; return
        }
        guard !clubId.isEmpty else {
            validationMessage = "Please select a club."
            showValidation = true; return
        }
        guard !trimmedLocation.isEmpty else {
            validationMessage = "Please enter a location."
            showValidation = true; return
        }
        guard start < end else {
            validationMessage = "End time must be after start time."
            showValidation = true; return
        }

        store.createEvent(
            title: trimmedTitle,
            clubId: clubId,
            location: trimmedLocation,
            startTime: start,
            endTime: end,
            technicalNeeds: Array(needs).sorted(),
            leaderId: leaderId.isEmpty ? nil : leaderId
        )
        dismiss()
    }
}

private struct NeedChip: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "plus.circle")
                Text(label.capitalized)
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
