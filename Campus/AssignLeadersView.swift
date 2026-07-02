//
//  AssignLeadersView.swift
//  Campus
//
//  Admin-only sheet for assigning / removing leaders on an event.
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
                        leaderRow(leader)
                    }
                } header: {
                    Text("Tap a leader to toggle their assignment")
                } footer: {
                    Text("Leaders are pre-registered in the backend. Only admins can manage assignments.")
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

    private func leaderRow(_ leader: AppUser) -> some View {
        let assigned = store.leaderIds(for: eventId).contains(leader.id)
        return Button {
            if assigned {
                store.unassign(leaderId: leader.id, from: eventId)
            } else {
                store.assign(leaderId: leader.id, to: eventId)
            }
        } label: {
            HStack {
                Image(systemName: "person.crop.circle.fill")
                    .foregroundStyle(Theme.accent)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(leader.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(leader.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: assigned ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(assigned ? Theme.accent : Color.secondary)
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }
}
