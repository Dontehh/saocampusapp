//
//  CreateEventView.swift
//  Campus
//
//  Admin/staff sheet for creating a new event. Venue is a Picker over
//  the canonical SAO venues plus a "Custom classroom" fallback. Tech
//  needs are structured: Mics (with count), Speakers, Projectors, Lights.
//

import SwiftUI

struct CreateEventView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore

    // Basic info
    @State private var title:  String = ""
    @State private var clubId: String = ""

    // Venue — Picker + custom classroom fallback
    private static let customVenueTag = "__custom__"
    @State private var venueSelection: String = DataStore.campusVenues.first
                                                    ?? Self.customVenueTag
    @State private var customVenue: String = ""

    // Schedule
    @State private var start: Date = Self.defaultStart
    @State private var end:   Date = Self.defaultEnd

    // Leader assignment (optional, multi-select)
    @State private var selectedLeaderIds: Set<String> = []
    @State private var mainLeaderId:      String?     = nil

    // Tech needs — structured
    @State private var micCount:      Int  = 0
    @State private var wantsSpeakers:   Bool = false
    @State private var wantsProjector:  Bool = false
    @State private var wantsLights:     Bool = false

    // Catering
    @State private var wantsCatering: Bool   = false
    @State private var cateringNotes: String = ""

    // Validation
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

    // MARK: - Derived

    private var resolvedVenue: String {
        if venueSelection == Self.customVenueTag {
            return customVenue.trimmingCharacters(in: .whitespaces)
        }
        return venueSelection
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !clubId.isEmpty &&
        !resolvedVenue.isEmpty &&
        start < end
    }

    private var composedTechNeeds: [String] {
        var needs: [String] = []
        if micCount > 0 {
            needs.append(micCount == 1 ? "1 mic" : "\(micCount) mics")
        }
        if wantsSpeakers  { needs.append("Speakers") }
        if wantsProjector { needs.append("Projector") }
        if wantsLights    { needs.append("Lights") }
        return needs
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                SceneBackground()
                Form {
                    eventSection
                    venueSection
                    scheduleSection
                    technicalNeedsSection
                    cateringSection
                    leaderSection
                    submitSection
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

    // MARK: - Sections

    private var eventSection: some View {
        Section("Event") {
            TextField("Title", text: $title)
            Picker("Club", selection: $clubId) {
                Text("Select a club").tag("")
                ForEach(store.clubs) { club in
                    Text(club.name).tag(club.id)
                }
            }
        }
    }

    private var venueSection: some View {
        Section {
            Picker("Venue", selection: $venueSelection) {
                ForEach(DataStore.campusVenues, id: \.self) { venue in
                    Text(venue).tag(venue)
                }
                Divider()
                Text("Custom classroom…").tag(Self.customVenueTag)
            }
            .pickerStyle(.menu)

            if venueSelection == Self.customVenueTag {
                HStack(spacing: 12) {
                    Image(systemName: "building.2.fill")
                        .foregroundStyle(Theme.accent)
                        .frame(width: 18)
                    TextField("Classroom (e.g. Building 6 · Room 104)",
                              text: $customVenue)
                        .iosAutocap(false)
                }
            }
        } header: {
            Text("Venue")
        } footer: {
            Text("Pick a SAO venue or choose \"Custom classroom…\" to type a room number.")
        }
    }

    private var scheduleSection: some View {
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
    }

    private var technicalNeedsSection: some View {
        Section {
            micRow
            Toggle(isOn: $wantsSpeakers) {
                Label("Speakers", systemImage: "speaker.wave.3.fill")
            }
            Toggle(isOn: $wantsProjector) {
                Label("Projector", systemImage: "videoprojector.fill")
            }
            Toggle(isOn: $wantsLights) {
                Label("Lights", systemImage: "lightbulb.fill")
            }
        } header: {
            Text("Technical Needs")
        } footer: {
            if composedTechNeeds.isEmpty {
                Text("No tech requested.")
            } else {
                Text("Requested: \(composedTechNeeds.joined(separator: ", ")).")
            }
        }
        .tint(Theme.accent)
    }

    private var micRow: some View {
        HStack {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mics")
                    Text(micCount == 0
                         ? "None"
                         : (micCount == 1 ? "1 mic" : "\(micCount) mics"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "mic.fill")
            }
            Spacer()
            Stepper("\(micCount)",
                    value: $micCount, in: 0...20)
                .labelsHidden()
            Text("\(micCount)")
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 34, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }

    private var cateringSection: some View {
        Section {
            Toggle(isOn: $wantsCatering.animation(AppMotion.snappy)) {
                Label("Include catering", systemImage: "fork.knife")
            }

            if wantsCatering {
                TextField("Menu, servings, dietary needs, delivery time…",
                          text: $cateringNotes,
                          axis: .vertical)
                    .lineLimit(3...8)
                    .iosAutocap(false)
            }
        } header: {
            Text("Catering")
        } footer: {
            Text(wantsCatering
                 ? "SAO will coordinate with the catering team based on the details above."
                 : "Toggle on to request food service for this event.")
        }
        .tint(Theme.accent)
    }

    private var leaderSection: some View {
        Section {
            if store.leaders().isEmpty {
                Text("No leaders on the roster yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.leaders()) { leader in
                    leaderPickerRow(leader)
                }
            }
        } header: {
            HStack {
                Text("Assign Leaders")
                Spacer()
                if !selectedLeaderIds.isEmpty {
                    Text("\(selectedLeaderIds.count) selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .contentTransition(.numericText())
                }
            }
        } footer: {
            Text("Tap a name to add or remove. Star sets the main leader — the primary contact for this event.")
        }
    }

    @ViewBuilder
    private func leaderPickerRow(_ leader: AppUser) -> some View {
        let isSelected = selectedLeaderIds.contains(leader.id)
        let isMain     = isSelected && mainLeaderId == leader.id

        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                if isMain {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(Theme.accent, in: Circle())
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(leader.name)
                        .font(.subheadline.weight(.semibold))
                    if isMain {
                        Text("MAIN")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.accent.opacity(0.22), in: Capsule())
                            .foregroundStyle(Theme.accent)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                Text(leader.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isSelected {
                Button {
                    withAnimation(AppMotion.snappy) {
                        mainLeaderId = leader.id
                    }
                } label: {
                    Image(systemName: isMain ? "star.fill" : "star")
                        .font(.title3)
                        .foregroundStyle(isMain ? Theme.accent : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isMain)
                .accessibilityLabel(isMain
                                    ? "\(leader.name) is main leader"
                                    : "Set \(leader.name) as main")
            }

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Theme.accent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(AppMotion.snappy) {
                toggleLeader(leader.id)
            }
        }
        .animation(AppMotion.snappy, value: isMain)
    }

    private func toggleLeader(_ leaderId: String) {
        if selectedLeaderIds.contains(leaderId) {
            selectedLeaderIds.remove(leaderId)
            if mainLeaderId == leaderId {
                mainLeaderId = selectedLeaderIds.first
            }
        } else {
            selectedLeaderIds.insert(leaderId)
            if mainLeaderId == nil {
                mainLeaderId = leaderId
            }
        }
    }

    private var submitSection: some View {
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

    // MARK: - Actions

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let venue        = resolvedVenue

        guard !trimmedTitle.isEmpty else {
            validationMessage = "Please enter a title."
            showValidation = true; return
        }
        guard !clubId.isEmpty else {
            validationMessage = "Please select a club."
            showValidation = true; return
        }
        guard !venue.isEmpty else {
            validationMessage = venueSelection == Self.customVenueTag
                ? "Please enter the classroom name."
                : "Please pick a venue."
            showValidation = true; return
        }
        guard start < end else {
            validationMessage = "End time must be after start time."
            showValidation = true; return
        }

        let mainId = mainLeaderId ?? selectedLeaderIds.first
        let catering: EventCatering? = wantsCatering
            ? EventCatering(
                notes: cateringNotes.trimmingCharacters(in: .whitespacesAndNewlines))
            : nil

        let newEventId = store.createEvent(
            title: trimmedTitle,
            clubId: clubId,
            location: venue,
            startTime: start,
            endTime: end,
            technicalNeeds: composedTechNeeds,
            leaderId: mainId,
            catering: catering
        )
        // createEvent flags the passed leader as main; add the remaining
        // selected leaders as regular assignments so we don't disturb
        // the main flag.
        for leaderId in selectedLeaderIds where leaderId != mainId {
            store.assign(leaderId: leaderId, to: newEventId)
        }
        dismiss()
    }
}
