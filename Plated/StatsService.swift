import Foundation

struct ProfileStats {
    let totalVolume: Double
    let workoutCount: Int
    let strengthTrend: StrengthTrend?
    let muscleGroupSets: [MuscleGroupStat]
}

struct StrengthTrend {
    let percentChange: Double

    var isUp: Bool { percentChange >= 0 }
}

struct MuscleGroupStat: Identifiable {
    let id = UUID()
    let name: String
    let setCount: Int
}

struct ExerciseRecord {
    let value: Double
    let date: Date
}

struct ExerciseChartPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct ExerciseHistoryEntry: Identifiable {
    let id: String
    let movement: Movement
    let variant: MovementVariant?

    var displayName: String {
        if let variant {
            return "\(variant.name) \(movement.name)"
        }
        return movement.name
    }
}

struct ExerciseSetLogEntry: Identifiable {
    let id = UUID()
    let date: Date
    let workoutName: String
    let setIndex: Int
    let reps: Int
    let weight: Double
}

struct ExerciseHistorySummary {
    let bestSetSeries: [ExerciseChartPoint]
    let volumeSeries: [ExerciseChartPoint]
    let allTimePR: ExerciseRecord?
    let bestE1RM: ExerciseRecord?
    let recentAverageWeight: Double?
    let setLogs: [ExerciseSetLogEntry]
}

enum StatsService {
    private static let sevenDays: TimeInterval = 7 * 24 * 60 * 60
    private static let fourteenDays: TimeInterval = 14 * 24 * 60 * 60
    private static let eightWeeks: TimeInterval = 56 * 24 * 60 * 60

    static func profileStats(sessions: [WorkoutSession], now: Date = Date()) -> ProfileStats {
        let completedSessions = sessions.filter { $0.status == .completed }
        let recentSessions = completedSessions.filter { $0.startTime >= now.addingTimeInterval(-sevenDays) }
        let workingSets = workingSets(in: recentSessions)

        let totalVolume = workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
        let workoutCount = recentSessions.count
        let muscleGroupSets = muscleGroupCounts(from: workingSets)
        let strengthTrend = strengthTrend(from: completedSessions, now: now)

        return ProfileStats(
            totalVolume: totalVolume,
            workoutCount: workoutCount,
            strengthTrend: strengthTrend,
            muscleGroupSets: muscleGroupSets
        )
    }

    static func exerciseHistoryEntries(from sessions: [WorkoutSession]) -> [ExerciseHistoryEntry] {
        var entries: [String: ExerciseHistoryEntry] = [:]

        for session in sessions where session.status == .completed {
            for item in session.sessionItems {
                guard let movement = item.movement,
                      item.performedSets.contains(where: isWorkingSet) else { continue }

                let variant = item.selectedVariant
                let key = "\(movement.id.uuidString)-\(variant?.id.uuidString ?? "none")"

                if entries[key] == nil {
                    entries[key] = ExerciseHistoryEntry(id: key, movement: movement, variant: variant)
                }
            }
        }

        return entries.values.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    static func exerciseHistory(
        for movement: Movement,
        variant: MovementVariant?,
        sessions: [WorkoutSession],
        now: Date = Date()
    ) -> ExerciseHistorySummary {
        let calendar = Calendar.current
        var bestSetByDay: [Date: Double] = [:]
        var volumeBySession: [Date: Double] = [:]
        var allTimePR: ExerciseRecord?
        var bestE1RM: ExerciseRecord?
        var recentWeights: [Double] = []
        var setLogs: [ExerciseSetLogEntry] = []

        let recentCutoff = now.addingTimeInterval(-fourteenDays)

        for session in sessions where session.status == .completed {
            let sessionDate = session.startTime
            let day = calendar.startOfDay(for: sessionDate)
            let movementItems = session.sessionItems.filter { item in
                guard item.movement?.id == movement.id else { return false }
                if let variant {
                    return item.selectedVariant?.id == variant.id
                }
                return true
            }
            let workingSets = movementItems.flatMap { $0.performedSets }.filter(isWorkingSet)

            guard !workingSets.isEmpty else { continue }

            let maxWeight = workingSets.map(\.weight).max() ?? 0
            bestSetByDay[day] = max(bestSetByDay[day] ?? 0, maxWeight)

            let totalVolume = workingSets.reduce(0) { $0 + $1.weight * Double($1.reps) }
            volumeBySession[sessionDate] = (volumeBySession[sessionDate] ?? 0) + totalVolume

            for set in workingSets {
                setLogs.append(
                    ExerciseSetLogEntry(
                        date: sessionDate,
                        workoutName: session.displayTitle,
                        setIndex: set.setIndex,
                        reps: set.reps,
                        weight: set.weight
                    )
                )

                if allTimePR == nil || set.weight > (allTimePR?.value ?? 0) {
                    allTimePR = ExerciseRecord(value: set.weight, date: sessionDate)
                }

                let e1rm = e1RM(weight: set.weight, reps: set.reps)
                if bestE1RM == nil || e1rm > (bestE1RM?.value ?? 0) {
                    bestE1RM = ExerciseRecord(value: e1rm, date: sessionDate)
                }

                if sessionDate >= recentCutoff {
                    recentWeights.append(set.weight)
                }
            }
        }

        let bestSetSeries = bestSetByDay
            .map { ExerciseChartPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }

        let volumeSeries = volumeBySession
            .map { ExerciseChartPoint(date: $0.key, value: $0.value) }
            .sorted { $0.date < $1.date }

        let recentAverage = recentWeights.isEmpty ? nil : recentWeights.reduce(0, +) / Double(recentWeights.count)

        let sortedLogs = setLogs.sorted { $0.date > $1.date }

        return ExerciseHistorySummary(
            bestSetSeries: bestSetSeries,
            volumeSeries: volumeSeries,
            allTimePR: allTimePR,
            bestE1RM: bestE1RM,
            recentAverageWeight: recentAverage,
            setLogs: sortedLogs
        )
    }

    private static func workingSets(in sessions: [WorkoutSession]) -> [PerformedSet] {
        sessions.flatMap { session in
            session.sessionItems.flatMap { $0.performedSets }.filter(isWorkingSet)
        }
    }

    private static func isWorkingSet(_ set: PerformedSet) -> Bool {
        !set.isWarmup && set.reps > 0
    }

    private static func muscleGroupCounts(from sets: [PerformedSet]) -> [MuscleGroupStat] {
        var counts: [String: Int] = [:]
        for set in sets {
            let rawCategory = set.sessionMovement?.movement?.category.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let category = rawCategory.isEmpty ? "Other" : rawCategory
            counts[category, default: 0] += 1
        }

        return counts
            .map { MuscleGroupStat(name: $0.key, setCount: $0.value) }
            .sorted { lhs, rhs in
                if lhs.setCount == rhs.setCount {
                    return lhs.name < rhs.name
                }
                return lhs.setCount > rhs.setCount
            }
            .prefix(5)
            .map { $0 }
    }

    private static func strengthTrend(from sessions: [WorkoutSession], now: Date) -> StrengthTrend? {
        let recentSessions = sessions.filter { $0.startTime >= now.addingTimeInterval(-eightWeeks) }
        let currentWindow = DateInterval(start: now.addingTimeInterval(-sevenDays), end: now)
        let pastWindow = DateInterval(start: now.addingTimeInterval(-sevenDays * 5), end: now.addingTimeInterval(-sevenDays * 4))

        guard
            let currentAverage = averageBenchmarkE1RM(in: recentSessions, window: currentWindow),
            let pastAverage = averageBenchmarkE1RM(in: recentSessions, window: pastWindow),
            pastAverage > 0
        else {
            return nil
        }

        let percentChange = (currentAverage - pastAverage) / pastAverage
        return StrengthTrend(percentChange: percentChange)
    }

    private static func averageBenchmarkE1RM(in sessions: [WorkoutSession], window: DateInterval) -> Double? {
        var bestByLift: [String: Double] = [:]

        for session in sessions where window.contains(session.startTime) {
            for item in session.sessionItems {
                guard let movement = item.movement,
                      let liftKey = benchmarkKey(for: movement.name) else { continue }

                let workingSets = item.performedSets.filter(isWorkingSet)
                guard !workingSets.isEmpty else { continue }

                let bestE1RMValue = workingSets
                    .map { e1RM(weight: $0.weight, reps: $0.reps) }
                    .max() ?? 0

                bestByLift[liftKey] = max(bestByLift[liftKey] ?? 0, bestE1RMValue)
            }
        }

        let values = bestByLift.values
        guard !values.isEmpty else { return nil }
        let total = values.reduce(0, +)
        return total / Double(values.count)
    }

    private static func benchmarkKey(for movementName: String) -> String? {
        let name = movementName.lowercased()
        if name.contains("bench") { return "Bench" }
        if name.contains("squat") { return "Squat" }
        if name.contains("deadlift") { return "Deadlift" }
        if name.contains("overhead press") || name.contains("shoulder press") || name.contains("ohp") {
            return "OHP"
        }
        return nil
    }

    private static func e1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return 0 }
        return weight * (1 + Double(reps) / 30.0)
    }
}
