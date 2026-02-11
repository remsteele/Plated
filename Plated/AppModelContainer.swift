import Foundation
import SwiftData

@MainActor
enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            WorkoutPlan.self,
            PlannedWorkoutDay.self,
            Movement.self,
            MovementVariant.self,
            WorkoutTemplate.self,
            TemplateItem.self,
            WorkoutSession.self,
            SessionMovement.self,
            PerformedSet.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
