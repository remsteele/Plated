import Foundation
import SwiftData

enum ResistanceType: String, Codable, CaseIterable, Identifiable {
    case perDumbbell
    case totalWeight
    case cableStack
    case bodyweight
    case assisted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .perDumbbell: return "Per Dumbbell"
        case .totalWeight: return "Total Weight"
        case .cableStack: return "Cable Stack"
        case .bodyweight: return "Bodyweight"
        case .assisted: return "Assisted"
        }
    }

    var weightLabel: String {
        switch self {
        case .perDumbbell: return "Weight per dumbbell"
        case .totalWeight: return "Total weight"
        case .cableStack: return "Stack weight"
        case .bodyweight: return "Bodyweight"
        case .assisted: return "Assistance weight"
        }
    }
}

enum SessionStatus: String, Codable, CaseIterable, Identifiable {
    case inProgress
    case completed
    case cancelled

    var id: String { rawValue }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutPlan {
    @Attribute(.unique) var id: UUID
    var days: [PlannedWorkoutDay]

    init(id: UUID = UUID(), days: [PlannedWorkoutDay] = []) {
        self.id = id
        self.days = days
    }

    var sortedDays: [PlannedWorkoutDay] {
        days.sorted { $0.weekday < $1.weekday }
    }
}

@Model
final class PlannedWorkoutDay {
    @Attribute(.unique) var id: UUID
    var weekday: Int
    var timeOfDay: String
    var template: WorkoutTemplate?
    var splitLabel: String?
    var enabled: Bool
    var plan: WorkoutPlan?

    init(
        id: UUID = UUID(),
        weekday: Int,
        timeOfDay: String = "18:00",
        template: WorkoutTemplate? = nil,
        splitLabel: String? = nil,
        enabled: Bool = false,
        plan: WorkoutPlan? = nil
    ) {
        self.id = id
        self.weekday = weekday
        self.timeOfDay = timeOfDay
        self.template = template
        self.splitLabel = splitLabel
        self.enabled = enabled
        self.plan = plan
    }
}

@Model
final class Movement {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var name: String
    var category: String
    var notes: String?
    var defaultSetCount: Int
    var variants: [MovementVariant]

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        notes: String? = nil,
        defaultSetCount: Int = 3,
        variants: [MovementVariant] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.notes = notes
        self.defaultSetCount = defaultSetCount
        self.variants = variants
    }

    var sortedVariants: [MovementVariant] {
        variants.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

@Model
final class MovementVariant {
    @Attribute(.unique) var id: UUID
    var movement: Movement?
    var name: String
    var resistanceType: ResistanceType
    var notes: String?

    init(
        id: UUID = UUID(),
        movement: Movement? = nil,
        name: String,
        resistanceType: ResistanceType = .totalWeight,
        notes: String? = nil
    ) {
        self.id = id
        self.movement = movement
        self.name = name
        self.resistanceType = resistanceType
        self.notes = notes
    }
}

@Model
final class WorkoutTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var templateItems: [TemplateItem]
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        templateItems: [TemplateItem] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.templateItems = templateItems
        self.notes = notes
    }

    var sortedItems: [TemplateItem] {
        templateItems.sorted { $0.orderingIndex < $1.orderingIndex }
    }
}

@Model
final class TemplateItem {
    @Attribute(.unique) var id: UUID
    var template: WorkoutTemplate?
    var movement: Movement?
    var defaultVariant: MovementVariant?
    var quantity: Int
    var targetSets: Int?
    var orderingIndex: Int

    init(
        id: UUID = UUID(),
        template: WorkoutTemplate? = nil,
        movement: Movement? = nil,
        defaultVariant: MovementVariant? = nil,
        quantity: Int = 1,
        targetSets: Int? = nil,
        orderingIndex: Int = 0
    ) {
        self.id = id
        self.template = template
        self.movement = movement
        self.defaultVariant = defaultVariant
        self.quantity = quantity
        self.targetSets = targetSets
        self.orderingIndex = orderingIndex
    }
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var templateUsed: WorkoutTemplate?
    var startTime: Date
    var endTime: Date?
    var durationSeconds: Int
    var status: SessionStatus
    var sessionItems: [SessionMovement]

    init(
        id: UUID = UUID(),
        templateUsed: WorkoutTemplate? = nil,
        startTime: Date = Date(),
        endTime: Date? = nil,
        durationSeconds: Int = 0,
        status: SessionStatus = .inProgress,
        sessionItems: [SessionMovement] = []
    ) {
        self.id = id
        self.templateUsed = templateUsed
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
        self.status = status
        self.sessionItems = sessionItems
    }

    var orderedMovements: [SessionMovement] {
        sessionItems.sorted { $0.orderingIndex < $1.orderingIndex }
    }

    var personalRecordCount: Int {
        sessionItems.flatMap { $0.performedSets }.filter { $0.isPR }.count
    }

    var displayTitle: String {
        templateUsed?.name ?? "Custom Workout"
    }
}

@Model
final class SessionMovement {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    var movement: Movement?
    var selectedVariant: MovementVariant?
    var orderingIndex: Int
    var targetSetCount: Int
    var performedSets: [PerformedSet]
    var notes: String?

    init(
        id: UUID = UUID(),
        session: WorkoutSession? = nil,
        movement: Movement? = nil,
        selectedVariant: MovementVariant? = nil,
        orderingIndex: Int = 0,
        targetSetCount: Int = 3,
        performedSets: [PerformedSet] = [],
        notes: String? = nil
    ) {
        self.id = id
        self.session = session
        self.movement = movement
        self.selectedVariant = selectedVariant
        self.orderingIndex = orderingIndex
        self.targetSetCount = targetSetCount
        self.performedSets = performedSets
        self.notes = notes
    }

    var orderedSets: [PerformedSet] {
        performedSets.sorted { $0.setIndex < $1.setIndex }
    }

    var bestSet: PerformedSet? {
        orderedSets.max { lhs, rhs in
            if lhs.weight == rhs.weight {
                return lhs.reps < rhs.reps
            }
            return lhs.weight < rhs.weight
        }
    }
}

@Model
final class PerformedSet {
    @Attribute(.unique) var id: UUID
    var sessionMovement: SessionMovement?
    var setIndex: Int
    var reps: Int
    var weight: Double
    var isWarmup: Bool
    var isPR: Bool
    var isCompleted: Bool
    var timestamp: Date

    init(
        id: UUID = UUID(),
        sessionMovement: SessionMovement? = nil,
        setIndex: Int,
        reps: Int = 0,
        weight: Double = 0,
        isWarmup: Bool = false,
        isPR: Bool = false,
        isCompleted: Bool = false,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.sessionMovement = sessionMovement
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.isWarmup = isWarmup
        self.isPR = isPR
        self.isCompleted = isCompleted
        self.timestamp = timestamp
    }
}
