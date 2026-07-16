//
//  AdminAnalyticsView.swift
//  Campus
//
//  Refined charts. Each chart lives in a surface card with a small
//  overline label and a single number annotation. Palette is limited to
//  the accent + ink so charts feel considered rather than colorful.
//

import SwiftUI
import Charts

struct AdminAnalyticsView: View {
    @EnvironmentObject private var store: DataStore

    var body: some View {
        GlassScene {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                    masthead
                    ChartCard(
                        title: "Top Clubs",
                        subtitle: "Total check-ins per club",
                        accent: topClubName
                    ) { ClubBarChart(limit: 6).frame(height: 260) }
                    ChartCard(
                        title: "Attendance",
                        subtitle: "Daily QR check-ins",
                        accent: "\(store.attendance.count) total"
                    ) { AttendanceTrendChart().frame(height: 220) }
                    ChartCard(
                        title: "Venues",
                        subtitle: "Share of events by location",
                        accent: "\(uniqueVenueCount) venues"
                    ) { VenueSectorChart().frame(height: 260) }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .contentFrame()
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("")
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reports").overlineStyle(Theme.accent)
            Text("Analytics")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
        }
    }

    private var topClubName: String {
        let grouped = Dictionary(grouping: store.attendance) {
            store.event(by: $0.eventId)?.clubId ?? ""
        }
        let topId = grouped.max(by: { $0.value.count < $1.value.count })?.key ?? ""
        return store.club(by: topId)?.name ?? "—"
    }
    private var uniqueVenueCount: Int {
        Set(store.events.map(\.location)).count
    }
}

// MARK: - Chart card

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).overlineStyle()
                    Text(subtitle)
                        .font(AppFont.caption)
                        .foregroundStyle(Theme.inkMuted)
                }
                Spacer()
                Text(accent)
                    .font(AppFont.captionStrong)
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentSoft,
                                in: Capsule(style: .continuous))
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}

// MARK: - Charts

struct ClubBarChart: View {
    @EnvironmentObject private var store: DataStore
    var limit: Int = 5

    private struct Row: Identifiable {
        let id = UUID()
        let club: String
        let turnout: Int
    }

    private var rows: [Row] {
        let grouped = Dictionary(grouping: store.attendance) { att -> String in
            store.event(by: att.eventId)?.clubId ?? ""
        }
        let mapped: [Row] = grouped.compactMap { clubId, atts in
            guard let club = store.club(by: clubId) else { return nil }
            return Row(club: club.name, turnout: atts.count)
        }
        return Array(mapped.sorted { $0.turnout > $1.turnout }.prefix(limit))
    }

    var body: some View {
        Chart(rows) { row in
            BarMark(
                x: .value("Turnout", row.turnout),
                y: .value("Club", row.club)
            )
            .foregroundStyle(Theme.accent)
            .cornerRadius(4)
            .annotation(position: .trailing) {
                Text("\(row.turnout)")
                    .font(AppFont.captionStrong)
                    .monospacedDigit()
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.rule)
                AxisValueLabel().font(AppFont.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().font(AppFont.captionStrong)
                    .foregroundStyle(Theme.ink)
            }
        }
        .animation(AppMotion.gentle, value: rows.map(\.turnout))
    }
}

struct AttendanceTrendChart: View {
    @EnvironmentObject private var store: DataStore

    private struct Point: Identifiable {
        let id = UUID()
        let date:  Date
        let count: Int
    }

    private var points: [Point] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.attendance) { att in
            cal.startOfDay(for: att.scannedAt)
        }
        return grouped
            .map { Point(date: $0.key, count: $0.value.count) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        Chart(points) { p in
            AreaMark(x: .value("Date", p.date),
                     y: .value("Attendance", p.count))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent.opacity(0.15))
            LineMark(x: .value("Date", p.date),
                     y: .value("Attendance", p.count))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Theme.accent)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
            PointMark(x: .value("Date", p.date),
                      y: .value("Attendance", p.count))
                .foregroundStyle(Theme.accent)
                .symbolSize(24)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Theme.rule)
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Theme.rule)
                AxisValueLabel().font(AppFont.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .animation(AppMotion.gentle, value: points.map(\.count))
    }
}

struct VenueSectorChart: View {
    @EnvironmentObject private var store: DataStore

    private struct Slice: Identifiable {
        let id = UUID()
        let venue: String
        let count: Int
    }

    private var slices: [Slice] {
        Dictionary(grouping: store.events, by: { $0.location })
            .map { Slice(venue: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    private var totalEvents: Int { slices.reduce(0) { $0 + $1.count } }

    private let palette: [Color] = [
        Theme.accent,
        Theme.accent.opacity(0.72),
        Theme.accent.opacity(0.54),
        Theme.accent.opacity(0.40),
        Theme.accent.opacity(0.28),
        Theme.accent.opacity(0.20),
        Theme.accent.opacity(0.14),
    ]

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Events", slice.count),
                innerRadius: .ratio(0.62),
                angularInset: 2
            )
            .cornerRadius(4)
            .foregroundStyle(by: .value("Venue", slice.venue))
        }
        .chartForegroundStyleScale(range: palette)
        .chartLegend(position: .bottom, alignment: .center, spacing: 10)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame.map({ geo[$0] }) {
                    VStack(spacing: 2) {
                        Text("\(totalEvents)")
                            .font(AppFont.heroNumber)
                            .foregroundStyle(Theme.ink)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                        Text("events").overlineStyle()
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .animation(AppMotion.gentle, value: slices.map(\.count))
    }
}
