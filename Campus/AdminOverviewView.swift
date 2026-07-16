//
//  AdminOverviewView.swift
//  Campus
//
//  Editorial control-center. Uses a masthead + refined metric grid;
//  chart is embedded inside the surface card with hairline dividers.
//

import SwiftUI
import Charts

struct AdminOverviewView: View {
    @EnvironmentObject private var store: DataStore

    private var totalEvents:    Int { store.events.count }
    private var totalAttendance: Int { store.attendance.count }
    private var ongoingCount:   Int { store.events.filter { $0.status == .ongoing }.count }
    private var completedCount: Int { store.events.filter { $0.status == .completed }.count }

    private var venueBreakdown: [(venue: String, count: Int)] {
        Dictionary(grouping: store.events, by: { $0.location })
            .map { (venue: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    private var mostActiveVenue: String { venueBreakdown.first?.venue ?? "—" }

    var body: some View {
        GlassScene {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppLayout.sectionGap) {
                    masthead
                    metrics
                    statusPipeline
                    chartCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
                .contentFrame()
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .trailingBar) { AccountMenu() }
        }
    }

    // MARK: - Pieces

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Control Center").overlineStyle(Theme.accent)
            Text("Overview")
                .font(AppFont.display)
                .foregroundStyle(Theme.ink)
            Text("Every event, club and check-in — at a glance.")
                .font(AppFont.body)
                .foregroundStyle(Theme.inkMuted)
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 14)],
                  spacing: 14) {
            MetricCard(title: "Events Hosted",
                       value: "\(totalEvents)",
                       icon:  "calendar")
            MetricCard(title: "Student Attendance",
                       value: "\(totalAttendance)",
                       icon:  "person.3")
            MetricCard(title: "Most Active Venue",
                       value: mostActiveVenue,
                       icon:  "mappin.and.ellipse",
                       compact: true)
        }
    }

    private var statusPipeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader("Pipeline")
            HStack(spacing: 12) {
                pipelinePill(count: ongoingCount,
                             label: "Ongoing",
                             tint: Theme.accent)
                pipelinePill(count: completedCount,
                             label: "Completed",
                             tint: Theme.positive)
            }
        }
    }

    private func pipelinePill(count: Int, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(count)")
                .font(AppFont.heroNumber)
                .foregroundStyle(Theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(label).font(AppFont.captionStrong)
                    .foregroundStyle(Theme.inkMuted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Top Clubs").overlineStyle()
                Spacer()
                Text("By turnout")
                    .font(AppFont.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
            ClubBarChart(limit: 5).frame(height: 220)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surfaceCard()
    }
}
