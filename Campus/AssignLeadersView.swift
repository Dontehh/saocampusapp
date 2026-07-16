//
//  AssignLeadersView.swift
//  Campus
//
//  Refined leader-assignment sheet. Hairline-separated list inside a
//  single surface card, star + checkmark controls per row, no
//  duplicated card chrome.
//

import SwiftUI

struct AssignLeadersView: View {
    let eventId: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: DataStore

    var body: some View {
        NavigationStack {
            GlassScene {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                        header
                        rosterCard
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
                    Button("Done") { dismiss() }
                        .font(AppFont.bodyEmphasis)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Roster").overlineStyle(Theme.accent)
            Text("Assign Leaders")
                .font(AppFont.title)
                .foregroundStyle(Theme.ink)
            Text("Tap to assign or unassign. Tap the star to designate the main leader — the primary contact for the event.")
                .font(AppFont.caption)
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var rosterCard: some View {
        VStack(spacing: 0) {
            let list = store.assignableStaff()
            ForEach(Array(list.enumerated()), id: \.element.id) { index, member in
                LeaderAssignmentRow(eventId: eventId, leader: member)
                if index != list.count - 1 { AppRule() }
            }
        }
        .padding(.horizontal, 18)
        .surfaceCard()
    }
}

// MARK: - Row

private struct LeaderAssignmentRow: View {
    let eventId: String
    let leader:  AppUser

    @EnvironmentObject private var store: DataStore

    private var isAssigned: Bool { store.leaderIds(for: eventId).contains(leader.id) }
    private var isMain:     Bool { store.isMainLeader(leader.id, for: eventId) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                .background(Circle().fill(Theme.fill))
                .frame(width: 34, height: 34)
                .overlay(Text(initials).font(AppFont.captionStrong)
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

            Spacer(minLength: 8)

            if isAssigned {
                Button {
                    store.setMainLeader(leaderId: leader.id, for: eventId)
                } label: {
                    Image(systemName: isMain ? "star.fill" : "star")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(isMain ? Theme.accent : Theme.inkFaint)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isMain)
                .accessibilityLabel(isMain
                                    ? "\(leader.name) is main leader"
                                    : "Set \(leader.name) as main")
            }

            Button {
                if isAssigned {
                    store.unassign(leaderId: leader.id, from: eventId)
                } else {
                    store.assign(leaderId: leader.id, to: eventId)
                }
            } label: {
                Image(systemName: isAssigned ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isAssigned ? Theme.accent : Theme.inkFaint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isAssigned
                                ? "Unassign \(leader.name)"
                                : "Assign \(leader.name)")
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .animation(AppMotion.snappy, value: isAssigned)
        .animation(AppMotion.snappy, value: isMain)
    }

    private var initials: String {
        let parts = leader.name.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
