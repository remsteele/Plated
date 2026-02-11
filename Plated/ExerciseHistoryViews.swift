import SwiftUI
import Charts
import SwiftData

struct ExerciseHistoryListView: View {
    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var searchText = ""
    @State private var performedMovements: [Movement] = []

    var body: some View {
        List {
            if filteredMovements.isEmpty {
                ContentUnavailableView("No exercise history yet", systemImage: "chart.xyaxis.line")
            } else {
                ForEach(filteredMovements) { movement in
                    NavigationLink(movement.name) {
                        ExerciseHistoryDetailView(movement: movement)
                    }
                }
            }
        }
        .navigationTitle("Exercise History")
        .searchable(text: $searchText)
        .task(id: sessions.count) {
            performedMovements = StatsService.performedMovements(from: sessions)
        }
    }

    private var filteredMovements: [Movement] {
        guard !searchText.isEmpty else { return performedMovements }
        return performedMovements.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

private struct ExerciseHistoryDetailView: View {
    enum ChartMode: String, CaseIterable {
        case bestSet = "Best Set"
        case volume = "Total Volume"
    }

    let movement: Movement

    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @AppStorage("unitPreference") private var unitPreference: String = "lb"

    @State private var summary: ExerciseHistorySummary?
    @State private var chartMode: ChartMode = .bestSet
    @State private var visibleLogCount = 25

    var body: some View {
        List {
            Section("Progress") {
                Picker("Chart", selection: $chartMode) {
                    ForEach(ChartMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let chartPoints = chartPoints, !chartPoints.isEmpty {
                    Chart {
                        ForEach(chartPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", UnitConverter.displayWeight(from: point.value, unit: unitPreference))
                            )
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Value", UnitConverter.displayWeight(from: point.value, unit: unitPreference))
                            )
                        }
                    }
                    .frame(height: 200)
                } else {
                    Text("No data yet for this exercise.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Quick Stats") {
                StatRow(label: "All-time PR", value: recordText(summary?.allTimePR))
                StatRow(label: "Best e1RM", value: recordText(summary?.bestE1RM))
                StatRow(label: "Recent Avg (14d)", value: recentAverageText)
            }

            Section("Set Log") {
                if let logs = summary?.setLogs, logs.isEmpty {
                    Text("No logged sets yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleLogs) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(PlatedFormatters.shortDate.string(from: entry.date)) • \(entry.workoutName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Set \(entry.setIndex)")
                                Spacer()
                                Text("\(UnitConverter.formattedWeight(entry.weight, unit: unitPreference)) \(unitPreference.lowercased()) x \(entry.reps)")
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if let logs = summary?.setLogs, visibleLogCount < logs.count {
                        Button("Load more") {
                            visibleLogCount += 25
                        }
                    }
                }
            }
        }
        .navigationTitle(movement.name)
        .task(id: sessions.count) {
            summary = StatsService.exerciseHistory(for: movement, sessions: sessions)
        }
    }

    private var chartPoints: [ExerciseChartPoint]? {
        guard let summary else { return nil }
        switch chartMode {
        case .bestSet:
            return summary.bestSetSeries
        case .volume:
            return summary.volumeSeries
        }
    }

    private var visibleLogs: [ExerciseSetLogEntry] {
        guard let logs = summary?.setLogs else { return [] }
        return Array(logs.prefix(visibleLogCount))
    }

    private var recentAverageText: String {
        guard let average = summary?.recentAverageWeight else { return "No recent data" }
        return "\(UnitConverter.formattedWeight(average, unit: unitPreference)) \(unitPreference.lowercased())"
    }

    private func recordText(_ record: ExerciseRecord?) -> String {
        guard let record else { return "No data" }
        let value = UnitConverter.formattedWeight(record.value, unit: unitPreference)
        let dateText = PlatedFormatters.shortDate.string(from: record.date)
        return "\(value) \(unitPreference.lowercased()) • \(dateText)"
    }
}

private struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
