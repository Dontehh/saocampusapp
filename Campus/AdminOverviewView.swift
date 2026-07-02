//
//  AdminOverviewView.swift
//  Campus
//
//  Landing tab for admins. Headline metric cards in orange + a quick chart.
//

import SwiftUI
import Charts

struct AdminOverviewView: View {
    @EnvironmentObject private var store: DataStore

    private var totalEvents: Int { store.events.count }
    private var totalAttendance: Int { store.attendance.count }

    private var venueBreakdown: [(venue: String, count: Int)] {
        Dictionary(grouping: store.events, by: { $0.location })
            .map { (venue: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    private var mostActiveVenue: String {
        venueBreakdown.first?.venue ?? "—"
    }

    var body: some View {
        GlassScene {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    metricsGrid
                    quickChartCard
                    statusBreakdownCard
                }
                .padding(20)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Overview")
        .largeNavTitle()
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SAO Control Center")
                .font(.title2.weight(.bold))
            Text("Live snapshot across every club and event.")
                .foregroundStyle(.secondary)
        }
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)],
                  spacing: 14) {
            MetricCard(title: "Events Hosted",
                       value: "\(totalEvents)",
                       icon:  "calendar.badge.checkmark")
            MetricCard(title: "Student Attendance",
                       value: "\(totalAttendance)",
                       icon:  "person.3.fill")
            MetricCard(title: "Most Active Venue",
                       value: mostActiveVenue,
                       icon:  "mappin.and.ellipse",
                       compact: true)
        }
    }

    private var quickChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Clubs by Turnout")
                .font(.headline)
            ClubBarChart(limit: 5)
                .frame(height: 230)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24)
    }

    private var statusBreakdownCard: some View {
        let assigned  = store.events.filter { $0.status == .ongoing   }.count
        let completed = store.events.filter { $0.status == .completed }.count

        return VStack(alignment: .leading, spacing: 12) {
            Text("Status Pipeline")
                .font(.headline)
            HStack(spacing: 14) {
                pillCard(title: "Ongoing",
                         value: assigned,
                         color: Theme.accent,
                         systemImage: "calendar.badge.clock")
                pillCard(title: "Completed",
                         value: completed,
                         color: Color.green,
                         systemImage: "checkmark.seal.fill")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 24)
    }

    private func pillCard(title: String, value: Int,
                          color: Color, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.title3.weight(.bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .softCard(radius: 16)
    }
}
