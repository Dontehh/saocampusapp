//
//  AdminAnalyticsView.swift
//  Campus
//
//  Swift Charts driven analytics: bar (clubs), line (trend), sector (venue).
//  Each chart sits in its own card with title, subtitle, and a key metric chip.
//

import SwiftUI
import Charts

// MARK: - Tab container

struct AdminAnalyticsView: View {
    @EnvironmentObject private var store: DataStore

    @State private var didAppear = false

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headline

                    ChartCard(
                        title: "Top Clubs by Turnout",
                        subtitle: "Total student check-ins per club",
                        accent: "Top: \(topClubName)",
                        icon: "trophy.fill"
                    ) {
                        ClubBarChart(limit: 6).frame(height: 280)
                    }

                    ChartCard(
                        title: "Attendance Trend",
                        subtitle: "Daily QR check-ins across all events",
                        accent: "\(store.attendance.count) scans",
                        icon: "waveform.path.ecg"
                    ) {
                        AttendanceTrendChart().frame(height: 240)
                    }

                    ChartCard(
                        title: "Events by Venue",
                        subtitle: "Share of events hosted at each location",
                        accent: "\(uniqueVenueCount) venues",
                        icon: "mappin.circle.fill"
                    ) {
                        VenueSectorChart().frame(height: 320)
                    }
                }
                .padding(20)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 10)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.35)) {
                        didAppear = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Analytics")
        .largeNavTitle()
    }

    // MARK: - Header

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Live insights across campus")
                .font(.title3.weight(.semibold))
            Text("Charts update instantly as new check-ins flow in.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Helpers

    private var topClubName: String {
        let grouped = Dictionary(grouping: store.attendance) {
            store.event(by: $0.eventId)?.clubId ?? ""
        }
        let topId = grouped
            .max(by: { $0.value.count < $1.value.count })?.key ?? ""
        return store.club(by: topId)?.name ?? "—"
    }

    private var uniqueVenueCount: Int {
        Set(store.events.map(\.location)).count
    }
}

// MARK: - Chart Card wrapper

struct ChartCard<Content: View>: View {
    let title: String
    let subtitle: String
    let accent: String
    let icon: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: icon)
                    Text(accent)
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassCard(tint: Theme.accent.opacity(0.22), radius: 14)
                .foregroundStyle(Theme.accent)
            }
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24)
    }
}

// MARK: - Bar chart: top clubs by turnout

struct ClubBarChart: View {
    @EnvironmentObject private var store: DataStore
    var limit: Int = 5

    @State private var selectedClub: String?

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
            .foregroundStyle(
                LinearGradient(colors: [Theme.accent,
                                        Theme.accent.opacity(0.65)],
                               startPoint: .leading, endPoint: .trailing)
            )
            .cornerRadius(8)
            .opacity(selectedClub == nil || selectedClub == row.club ? 1 : 0.35)
            .annotation(position: .trailing) {
                Text("\(row.turnout)")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel().font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisValueLabel().font(.caption.weight(.semibold))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85),
                   value: rows.map(\.turnout))
    }
}

// MARK: - Line chart: attendance trend over time

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
            AreaMark(
                x: .value("Date", p.date),
                y: .value("Attendance", p.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(colors: [Theme.accent.opacity(0.45),
                                        Theme.accent.opacity(0.0)],
                               startPoint: .top, endPoint: .bottom)
            )

            LineMark(
                x: .value("Date", p.date),
                y: .value("Attendance", p.count)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Theme.accent)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))

            PointMark(
                x: .value("Date", p.date),
                y: .value("Attendance", p.count)
            )
            .foregroundStyle(Theme.accent)
            .symbolSize(48)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.25))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.2))
                AxisValueLabel().font(.caption2)
            }
        }
        .animation(.easeInOut(duration: 0.4),
                   value: points.map(\.count))
    }
}

// MARK: - Sector / pie chart: events grouped by venue

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
        Color(red: 0.99, green: 0.65, blue: 0.30),
        Color(red: 0.34, green: 0.55, blue: 0.95),
        Color(red: 0.55, green: 0.40, blue: 0.92),
        Color(red: 0.18, green: 0.72, blue: 0.55),
        Color(red: 0.96, green: 0.40, blue: 0.55),
        Color(red: 0.42, green: 0.75, blue: 0.86),
    ]

    var body: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Events", slice.count),
                innerRadius: .ratio(0.6),
                angularInset: 3
            )
            .cornerRadius(8)
            .foregroundStyle(by: .value("Venue", slice.venue))
        }
        .chartForegroundStyleScale(range: palette)
        .chartLegend(position: .bottom, alignment: .center, spacing: 10)
        .chartBackground { proxy in
            GeometryReader { geo in
                if let frame = proxy.plotFrame.map({ geo[$0] }) {
                    VStack(spacing: 2) {
                        Text("\(totalEvents)")
                            .font(.system(size: 36, weight: .bold,
                                          design: .rounded))
                            .foregroundStyle(Theme.accent)
                            .contentTransition(.numericText())
                        Text("events")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8),
                   value: slices.map(\.count))
    }
}
