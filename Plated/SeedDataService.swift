import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func seedIfNeeded(context: ModelContext) async {
        let movementCount = (try? context.fetchCount(FetchDescriptor<Movement>())) ?? 0
        if movementCount > 0 {
            return
        }

        let profileCount = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        if profileCount == 0 {
            context.insert(UserProfile(name: "Athlete"))
        }

        let plan = WorkoutPlan()
        plan.days = (1...7).map { weekday in
            PlannedWorkoutDay(weekday: weekday, timeOfDay: "18:00", enabled: false, plan: plan)
        }
        context.insert(plan)

        let bench = Movement(name: "Bench Press", category: "Chest", defaultSetCount: 3)
        bench.variants = [
            MovementVariant(movement: bench, name: "Barbell", resistanceType: .totalWeight),
            MovementVariant(movement: bench, name: "Dumbbell", resistanceType: .perDumbbell),
            MovementVariant(movement: bench, name: "Machine", resistanceType: .totalWeight)
        ]

        let shoulderPress = Movement(name: "Shoulder Press", category: "Shoulders", defaultSetCount: 3)
        shoulderPress.variants = [
            MovementVariant(movement: shoulderPress, name: "Dumbbell", resistanceType: .perDumbbell),
            MovementVariant(movement: shoulderPress, name: "Barbell", resistanceType: .totalWeight),
            MovementVariant(movement: shoulderPress, name: "Machine", resistanceType: .totalWeight)
        ]

        let lateralRaise = Movement(name: "Lateral Raise", category: "Shoulders", defaultSetCount: 3)
        lateralRaise.variants = [
            MovementVariant(movement: lateralRaise, name: "Dumbbell", resistanceType: .perDumbbell),
            MovementVariant(movement: lateralRaise, name: "Cable", resistanceType: .cableStack),
            MovementVariant(movement: lateralRaise, name: "Machine", resistanceType: .totalWeight)
        ]

        let triceps = Movement(name: "Triceps Pushdown", category: "Arms", defaultSetCount: 3)
        triceps.variants = [
            MovementVariant(movement: triceps, name: "Cable", resistanceType: .cableStack),
            MovementVariant(movement: triceps, name: "Machine", resistanceType: .totalWeight)
        ]

        let squat = Movement(name: "Squat", category: "Legs", defaultSetCount: 4)
        squat.variants = [
            MovementVariant(movement: squat, name: "Barbell", resistanceType: .totalWeight),
            MovementVariant(movement: squat, name: "Machine", resistanceType: .totalWeight)
        ]

        let latPulldown = Movement(name: "Lat Pulldown", category: "Back", defaultSetCount: 3)
        latPulldown.variants = [
            MovementVariant(movement: latPulldown, name: "Cable", resistanceType: .cableStack),
            MovementVariant(movement: latPulldown, name: "Machine", resistanceType: .totalWeight)
        ]

        [bench, shoulderPress, lateralRaise, triceps, squat, latPulldown].forEach { context.insert($0) }

        let pushTemplate = WorkoutTemplate(name: "PUSH")
        pushTemplate.templateItems = [
            TemplateItem(template: pushTemplate, movement: bench, quantity: 1, targetSets: 3, orderingIndex: 0),
            TemplateItem(template: pushTemplate, movement: shoulderPress, quantity: 1, targetSets: 3, orderingIndex: 1),
            TemplateItem(template: pushTemplate, movement: lateralRaise, quantity: 1, targetSets: 3, orderingIndex: 2),
            TemplateItem(template: pushTemplate, movement: triceps, quantity: 1, targetSets: 3, orderingIndex: 3)
        ]

        let pullTemplate = WorkoutTemplate(name: "PULL")
        pullTemplate.templateItems = [
            TemplateItem(template: pullTemplate, movement: latPulldown, quantity: 1, targetSets: 3, orderingIndex: 0),
            TemplateItem(template: pullTemplate, movement: bench, quantity: 1, targetSets: 3, orderingIndex: 1)
        ]

        let legsTemplate = WorkoutTemplate(name: "LEGS")
        legsTemplate.templateItems = [
            TemplateItem(template: legsTemplate, movement: squat, quantity: 1, targetSets: 4, orderingIndex: 0)
        ]

        [pushTemplate, pullTemplate, legsTemplate].forEach { context.insert($0) }

        if let monday = plan.days.first(where: { $0.weekday == 1 }) {
            monday.enabled = true
            monday.template = pushTemplate
            monday.splitLabel = "Push"
        }
        if let wednesday = plan.days.first(where: { $0.weekday == 3 }) {
            wednesday.enabled = true
            wednesday.template = pullTemplate
            wednesday.splitLabel = "Pull"
        }
        if let friday = plan.days.first(where: { $0.weekday == 5 }) {
            friday.enabled = true
            friday.template = legsTemplate
            friday.splitLabel = "Legs"
        }
    }
}
