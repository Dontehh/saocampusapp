//
//  SharedComponents.swift
//  Campus
//
//  Reusable UI building blocks used across leader and admin views.
//

import SwiftUI

// MARK: - Status badge

struct StatusBadge: View {
    let status: EventStatus

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: status == .completed
                  ? "checkmark.seal.fill"
                  : "circle.dotted")
            Text(status.rawValue.capitalized)
        }
        .font(.caption2.weight(.bold))
        .tracking(0.4)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassCard(tint: foreground.opacity(0.22), radius: 20)
        .foregroundStyle(foreground)
    }

    private var foreground: Color {
        status == .completed ? Color.green : Theme.accent
    }
}

// MARK: - Empty state

struct EmptyState: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 46))
                .foregroundStyle(Theme.accent.opacity(0.55))
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

// MARK: - Detail row

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Flow-style tag list

struct FlowTags: View {
    let tags: [String]
    var tint: Color = Theme.accent

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 110), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(tags, id: \.self) { tag in
                Text(tag.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(tint.opacity(0.15), in: Capsule())
                    .foregroundStyle(tint)
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Event card row (used in lists)

struct EventCardRow: View {
    @EnvironmentObject private var store: DataStore
    let event: CampusEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let club = store.club(by: event.clubId) {
                        Text(club.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                StatusBadge(status: event.status)
            }

            HStack(spacing: 14) {
                Label(event.location, systemImage: "mappin.and.ellipse")
                Label(event.startTime.formatted(date: .abbreviated, time: .shortened),
                      systemImage: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack {
                if event.status == .completed {
                    Image(systemName: "person.3.fill")
                        .foregroundStyle(Theme.accent)
                    Text("\(store.attendanceCount(for: event.id)) attended")
                        .font(.caption.weight(.semibold))
                        .contentTransition(.numericText())
                } else {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(Theme.accent)
                    Text(event.technicalNeeds.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(18)
        .glassCard(tint: Theme.accent.opacity(0.12), radius: 22)
    }
}

// MARK: - Metric card (admin overview)

struct MetricCard: View {
    let title: String
    let value: String
    let icon:  String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(colors: [Theme.accent,
                                                Color(red: 0.86, green: 0.32, blue: 0.06)],
                                       startPoint: .topLeading,
                                       endPoint:   .bottomTrailing)
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.white)
            }

            Text(value)
                .font(compact
                      ? .title3.weight(.bold)
                      : .system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .contentTransition(.numericText())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: Theme.accent.opacity(0.18), radius: 22)
    }
}

// MARK: - Account / appearance menu

struct AccountMenu: View {
    @EnvironmentObject private var auth:     AuthService
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        Menu {
            Section("Appearance") {
                ForEach(AppAppearance.allCases) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
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
            Divider()
            if let user = auth.currentUser {
                Text(user.name)
                Text(user.email).font(.caption)
            }
            Divider()
            Button(role: .destructive) {
                auth.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: appearanceGlyph)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .padding(10)
                .glassCard(tint: Theme.accent.opacity(0.22), radius: 22)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var appearanceGlyph: String {
        switch settings.appearance {
        case .system: return "person.crop.circle"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private func icon(for option: AppAppearance) -> String {
        switch option {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }
}
