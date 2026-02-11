import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query private var plans: [WorkoutPlan]
    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @AppStorage("unitPreference") private var unitPreference: String = "lb"

    @State private var showingPlanEditor = false
    @State private var profileStats: ProfileStats?

    private let weekdays = [
        (1, "Mon"), (2, "Tue"), (3, "Wed"), (4, "Thu"), (5, "Fri"), (6, "Sat"), (7, "Sun")
    ]

    var body: some View {
        List {
            if let profile = profiles.first {
                Section("Profile") {
                    ProfileHeaderView(profile: profile)
                }
            }

            Section("Stats") {
                StatsCardView(stats: profileStats, unitPreference: unitPreference)

                NavigationLink {
                    ExerciseHistoryListView()
                } label: {
                    Label("Exercise History", systemImage: "chart.xyaxis.line")
                }
            }

            Section("Quick Stats") {
                StatRow(label: "Total Workouts", value: "\(completedSessions.count)")
                StatRow(label: "Last Workout", value: lastWorkoutText)
                StatRow(label: "Weekly Streak", value: "\(weeklyStreakCount)")
            }

            Section("Workout Plan") {
                ForEach(planDays) { day in
                    PlanDaySummaryRow(day: day, weekdayName: weekdayName(for: day.weekday))
                }
                Button("Edit Plan") { showingPlanEditor = true }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showingPlanEditor) {
            if let plan = plans.first {
                PlanEditorView(plan: plan)
            }
        }
        .onAppear { ensureProfileAndPlan() }
        .task(id: completedSessions.count) {
            profileStats = StatsService.profileStats(sessions: completedSessions)
        }
    }

    private var planDays: [PlannedWorkoutDay] {
        plans.first?.sortedDays ?? []
    }

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }
    }

    private var lastWorkoutText: String {
        guard let latest = completedSessions.first else { return "None yet" }
        return PlatedFormatters.shortDateTime.string(from: latest.startTime)
    }

    private var weeklyStreakCount: Int {
        StreakCalculator.weeklyStreak(sessions: completedSessions)
    }

    private func weekdayName(for value: Int) -> String {
        weekdays.first(where: { $0.0 == value })?.1 ?? "Day"
    }

    private func ensureProfileAndPlan() {
        if profiles.isEmpty {
            modelContext.insert(UserProfile(name: "Athlete"))
        }
        if plans.isEmpty {
            let plan = WorkoutPlan()
            plan.days = weekdays.map { weekday in
                PlannedWorkoutDay(weekday: weekday.0, timeOfDay: "18:00", enabled: false, plan: plan)
            }
            modelContext.insert(plan)
        } else if let plan = plans.first, plan.days.count < 7 {
            let existing = Set(plan.days.map { $0.weekday })
            for day in weekdays where !existing.contains(day.0) {
                plan.days.append(PlannedWorkoutDay(weekday: day.0, timeOfDay: "18:00", enabled: false, plan: plan))
            }
        }
    }
}

private struct ProfileHeaderView: View {
    @Bindable var profile: UserProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $profile.name)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Member since \(PlatedFormatters.shortDate.string(from: profile.createdAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlanDaySummaryRow: View {
    let day: PlannedWorkoutDay
    let weekdayName: String

    var body: some View {
        HStack {
            Text(weekdayName)
                .fontWeight(.semibold)
            Spacer()
            if day.enabled {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(day.timeOfDay)
                    Text(day.template?.name ?? "No Template")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let split = day.splitLabel, !split.isEmpty {
                        Text(split)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Off")
                    .foregroundStyle(.secondary)
            }
        }
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

private struct StatsCardView: View {
    let stats: ProfileStats?
    let unitPreference: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatMetricRow(
                title: "Total Volume (7d)",
                value: volumeText
            )
            StatMetricRow(
                title: "Workouts (7d)",
                value: stats?.workoutCount.description ?? "—"
            )
            StatMetricRow(
                title: "Strength Trend",
                value: trendText,
                trend: stats?.strengthTrend
            )
            StatMetricRow(
                title: "Top Muscle Groups (7d)",
                value: muscleGroupText
            )
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var volumeText: String {
        guard let stats else { return "—" }
        let value = UnitConverter.formattedVolume(stats.totalVolume, unit: unitPreference)
        return "\(value) \(unitPreference.lowercased())"
    }

    private var trendText: String {
        guard let trend = stats?.strengthTrend else { return "Not enough data" }
        let percentValue = UnitConverter.formattedNumber(abs(trend.percentChange * 100))
        return trend.isUp ? "Up \(percentValue)%" : "Down \(percentValue)%"
    }

    private var muscleGroupText: String {
        guard let stats else { return "No recent data" }
        if stats.muscleGroupSets.isEmpty { return "No recent data" }
        return stats.muscleGroupSets
            .map { "\($0.name) \($0.setCount)" }
            .joined(separator: " · ")
    }
}

private struct StatMetricRow: View {
    let title: String
    let value: String
    var trend: StrengthTrend?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
            Spacer()
            if let trend {
                Image(systemName: trend.isUp ? "arrow.up.right" : "arrow.down.right")
                    .foregroundStyle(trend.isUp ? .green : .red)
            }
        }
    }
}
