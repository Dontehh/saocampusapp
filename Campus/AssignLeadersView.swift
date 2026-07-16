//
//  AssignLeadersView.swift
//  Campus
//
//  Admin/staff sheet for managing an event's leader roster.
//  Each row exposes two controls: a "Main" pill that promotes the
//  leader to primary contact, and an assign/unassign checkmark.
//

import SwiftUI

struct AssignLeadersView: View {
    let eventId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore

    var body: some View {
        NavigationStack {
            ZStack {
                SceneBackground()
                List {
                    Section {
                        ForEach(store.leaders()) { leader in
                            LeaderAssignmentRow(eventId: eventId,
                                                leader: leader)
                                .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Tap a name to assign / unassign · tap the star to set the main leader")
                    } footer: {
                        Text("Leaders come from the Summer 2026 SAO roster. The main leader is the primary contact for the event; only admins and staff can change assignments.")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Assign Leaders")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .trailingBar) {
                    Button("Done") { dismiss() }
                        .tint(Theme.accent)
                }
            }
        }
    }
}

// MARK: - Row

private struct LeaderAssignmentRow: View {
    let eventId: String
    let leader:  AppUser

    @EnvironmentObject private var store: DataStore

    private var isAssigned: Bool {
        store.leaderIds(for: eventId).contains(leader.id)
    }

    private var isMain: Bool {
        store.isMainLeader(leader.id, for: eventId)
    }

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(leader.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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

            if isAssigned {
                mainButton
            }
            assignButton
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .animation(AppMotion.snappy, value: isAssigned)
        .animation(AppMotion.snappy, value: isMain)
    }

    // MARK: - Controls

    private var avatar: some View {
        Image(systemName: "person.crop.circle.fill")
            .font(.title2)
            .foregroundStyle(Theme.accent)
    }

    private var mainButton: some View {
        Button {
            store.setMainLeader(leaderId: leader.id, for: eventId)
        } label: {
            Image(systemName: isMain ? "star.fill" : "star")
                .font(.title3)
                .foregroundStyle(isMain ? Theme.accent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isMain
                            ? "\(leader.name) is the main leader"
                            : "Set \(leader.name) as main leader")
        .disabled(isMain)
    }

    private var assignButton: some View {
        Button {
            if isAssigned {
                store.unassign(leaderId: leader.id, from: eventId)
            } else {
                store.assign(leaderId: leader.id, to: eventId)
            }
        } label: {
            Image(systemName: isAssigned ? "checkmark.circle.fill" : "circle")
                .font(.title2)
                .foregroundStyle(isAssigned ? Theme.accent : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isAssigned
                            ? "Unassign \(leader.name)"
                            : "Assign \(leader.name)")
    }
}
