//
//  SharedComponents.swift
//  Campus
//
//  Shared UI primitives. Every card row + badge follows the same
//  hierarchy: overline / title / meta / trailing. Numbers use rounded
//  SF. Motion is a single spring curve. Nothing here uses more than two
//  colors per component — restraint carries the design.
//

import SwiftUI

// MARK: - Status badge

struct StatusBadge: View {
    let status: EventStatus

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(label)
                .font(AppFont.overline)
                .tracking(1.2)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(foreground)
        .background(background,
                    in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(foreground.opacity(0.20),
                        lineWidth: AppLayout.hairline)
        )
    }

    private var label: String {
        status == .completed ? "Completed" : "Ongoing"
    }
    private var dotColor: Color {
        status == .completed ? Theme.positive : Theme.accent
    }
    private var foreground: Color {
        status == .completed ? Theme.positive : Theme.accent
    }
    private var background: Color {
        status == .completed
            ? Theme.positive.opacity(0.10)
            : Theme.accentSoft
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.inkFaint)
            Text(title)
                .font(AppFont.headline)
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(AppFont.body)
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }
}

// MARK: - Detail row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.inkMuted)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .overlineStyle()
                Text(value)
                    .font(AppFont.body)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Flow tags

struct FlowTags: View {
    let tags: [String]
    var tint: Color = Theme.accent

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(tags, id: \.self) { tag in
                Text(tag.capitalized)
                    .font(AppFont.captionStrong)
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.fill,
                                in: Capsule(style: .continuous))
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                    )
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Catering card

struct CateringCard: View {
    let catering: EventCatering

    private var trimmedNotes: String {
        catering.notes.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("Catering")
                    .overlineStyle(Theme.accent)
                Spacer()
            }
            if trimmedNotes.isEmpty {
                Text("Catering requested — details to be finalized.")
                    .font(AppFont.body)
                    .foregroundStyle(Theme.inkMuted)
            } else {
                Text(trimmedNotes)
                    .font(AppFont.body)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

// MARK: - Event card

struct EventCardRow: View {
    @EnvironmentObject private var store: DataStore
    let event: CampusEvent

    private var clubName: String? { store.club(by: event.clubId)?.name }

    private var subtitle: String {
        if event.status == .completed {
            let n = store.attendanceCount(for: event.id)
            return "\(n) attended · \(event.location)"
        }
        return "\(dateLine) · \(event.location)"
    }

    private var dateLine: String {
        event.startTime.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                if let club = clubName {
                    Text(club)
                        .overlineStyle()
                }
                Text(event.title)
                    .font(AppFont.heading)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(subtitle)
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 12) {
                StatusBadge(status: event.status)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(18)
        .surfaceCard()
        .contentShape(RoundedRectangle(cornerRadius: AppLayout.cardRadius,
                                       style: .continuous))
    }
}

// MARK: - Metric card

struct MetricCard: View {
    let title: String
    let value: String
    let icon:  String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .overlineStyle()
                Spacer()
            }
            Text(value)
                .font(compact ? AppFont.statNumber : AppFont.heroNumber)
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
                .monospacedDigit()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

// MARK: - Account menu

struct AccountMenu: View {
    @EnvironmentObject private var auth:     AuthService
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Menu {
            Section("Appearance") {
                ForEach(AppAppearance.allCases) { option in
                    Button {
                        withAnimation(AppMotion.smooth) {
                            settings.appearance = option
                        }
                    } label: {
                        Label {
                            HStack {
                                Text(option.label)
                                if settings.appearance == option {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        } icon: {
                            Image(systemName: icon(for: option))
                        }
                    }
                }
            }
            if let user = auth.currentUser {
                Section {
                    Text(user.name)
                    Text(user.email).font(AppFont.caption)
                }
            }
            Section {
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Label("Sign Out",
                          systemImage: "rectangle.portrait.and.arrow.right")
                }
            }
        } label: {
            Image(systemName: appearanceGlyph)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 36, height: 36)
                .background(Theme.surface,
                            in: Circle())
                .overlay(
                    Circle()
                        .stroke(Theme.rule, lineWidth: AppLayout.hairline)
                )
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var appearanceGlyph: String {
        switch settings.appearance {
        case .system: return "person.crop.circle"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
    private func icon(for option: AppAppearance) -> String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }
}

// MARK: - Section header

/// Reusable section header used across dashboards. Overline label +
/// optional trailing accessory (typically a count pill).
struct SectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String,
         @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).overlineStyle()
            Spacer()
            trailing()
        }
    }
}

// MARK: - Count pill

struct CountPill: View {
    let count: Int
    var tint: Color = Theme.accent
    var body: some View {
        Text("\(count)")
            .font(AppFont.captionStrong)
            .monospacedDigit()
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(tint.opacity(0.10),
                        in: Capsule(style: .continuous))
            .contentTransition(.numericText())
    }
}
