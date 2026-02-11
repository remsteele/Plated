import Foundation

enum StreakCalculator {
    static func weeklyStreak(sessions: [WorkoutSession]) -> Int {
        guard !sessions.isEmpty else { return 0 }
        let calendar = Calendar.current
        var streak = 0
        var weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start

        while let start = weekStart {
            let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            let hasWorkout = sessions.contains { $0.startTime >= start && $0.startTime < end }
            if hasWorkout {
                streak += 1
                weekStart = calendar.date(byAdding: .day, value: -7, to: start)
            } else {
                break
            }
        }
        return streak
    }
}
