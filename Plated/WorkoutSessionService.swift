import Foundation
import SwiftData

enum WorkoutSessionService {
    static func createSession(template: WorkoutTemplate?, context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(templateUsed: template, startTime: Date(), status: .inProgress)
        context.insert(session)

        if let template {
            // Template expansion: expand each template item by quantity into ordered session movements.
            var orderingIndex = 0
            for item in template.sortedItems {
                let count = max(item.quantity, 1)
                for _ in 0..<count {
                    orderingIndex += 1
                    if let movement = item.movement {
                        let targetSets = item.targetSets ?? movement.defaultSetCount
                        let preferredVariant = item.defaultVariant
                        let sessionMovement = buildSessionMovement(
                            movement: movement,
                            targetSets: targetSets,
                            orderingIndex: orderingIndex,
                            selectedVariant: preferredVariant,
                            context: context
                        )
                        sessionMovement.session = session
                        session.sessionItems.append(sessionMovement)
                    }
                }
            }
        }

        return session
    }

    static func addMovement(
        to session: WorkoutSession,
        movement: Movement,
        targetSets: Int? = nil,
        context: ModelContext
    ) -> SessionMovement {
        let nextIndex = (session.sessionItems.map { $0.orderingIndex }.max() ?? 0) + 1
        let setCount = targetSets ?? movement.defaultSetCount
        let sessionMovement = buildSessionMovement(
            movement: movement,
            targetSets: setCount,
            orderingIndex: nextIndex,
            context: context
        )
        sessionMovement.session = session
        session.sessionItems.append(sessionMovement)
        return sessionMovement
    }

    static func duplicateSession(from session: WorkoutSession, context: ModelContext) -> WorkoutSession {
        let newSession = WorkoutSession(templateUsed: session.templateUsed, startTime: Date(), status: .inProgress)
        context.insert(newSession)

        var orderingIndex = 0
        for item in session.orderedMovements {
            guard let movement = item.movement else { continue }
            orderingIndex += 1
            let targetSets = item.targetSetCount
            let sessionMovement = buildSessionMovement(
                movement: movement,
                targetSets: targetSets,
                orderingIndex: orderingIndex,
                context: context
            )
            sessionMovement.selectedVariant = item.selectedVariant
            sessionMovement.session = newSession
            newSession.sessionItems.append(sessionMovement)
        }

        return newSession
    }

    static func finishSession(_ session: WorkoutSession, context: ModelContext) {
        session.endTime = Date()
        session.durationSeconds = Int(session.endTime?.timeIntervalSince(session.startTime) ?? 0)
        session.status = .completed
        updatePersonalRecords(for: session, context: context)
    }

    static func cancelSession(_ session: WorkoutSession) {
        session.endTime = Date()
        session.status = .cancelled
    }

    static func recommendedVariant(for movement: Movement, context: ModelContext) -> MovementVariant? {
        let variants = movement.sortedVariants
        guard !variants.isEmpty else { return nil }

        // Recommendation logic: choose the least-recently-used variant for this movement.
        var bestVariant: MovementVariant?
        var oldestDate = Date.distantFuture
        for variant in variants {
            let lastUsed = lastUsedDate(for: variant, context: context) ?? .distantPast
            if lastUsed < oldestDate {
                oldestDate = lastUsed
                bestVariant = variant
            }
        }
        return bestVariant ?? variants.first
    }

    private static func buildSessionMovement(
        movement: Movement,
        targetSets: Int,
        orderingIndex: Int,
        selectedVariant: MovementVariant? = nil,
        context: ModelContext
    ) -> SessionMovement {
        let variant = selectedVariant ?? recommendedVariant(for: movement, context: context)
        let sessionMovement = SessionMovement(
            movement: movement,
            selectedVariant: variant,
            orderingIndex: orderingIndex,
            targetSetCount: max(targetSets, 1)
        )
        context.insert(sessionMovement)
        sessionMovement.performedSets = buildSets(
            count: sessionMovement.targetSetCount,
            movement: sessionMovement,
            context: context
        )
        return sessionMovement
    }

    private static func buildSets(
        count: Int,
        movement: SessionMovement,
        context: ModelContext
    ) -> [PerformedSet] {
        (1...count).map { index in
            let set = PerformedSet(sessionMovement: movement, setIndex: index, reps: 0, weight: 0)
            context.insert(set)
            return set
        }
    }

    private static func lastUsedDate(for variant: MovementVariant, context: ModelContext) -> Date? {
        let descriptor = FetchDescriptor<SessionMovement>()
        let movements = (try? context.fetch(descriptor)) ?? []
        let completedMovements = movements.filter {
            $0.selectedVariant?.id == variant.id && $0.session?.status == .completed
        }
        return completedMovements.compactMap { $0.session?.endTime ?? $0.session?.startTime }.max()
    }

    private static func updatePersonalRecords(for session: WorkoutSession, context: ModelContext) {
        let descriptor = FetchDescriptor<PerformedSet>()
        let historySets = (try? context.fetch(descriptor)) ?? []
        let filteredHistory = historySets.filter {
            $0.sessionMovement?.session?.status == .completed && $0.sessionMovement?.session?.id != session.id
        }

        var bestByVariant: [PersistentIdentifier: Double] = [:]
        for set in filteredHistory {
            guard let variant = set.sessionMovement?.selectedVariant else { continue }
            let currentBest = bestByVariant[variant.persistentModelID] ?? 0
            if set.weight > currentBest {
                bestByVariant[variant.persistentModelID] = set.weight
            }
        }

        for sessionMovement in session.sessionItems {
            for set in sessionMovement.performedSets {
                guard let variant = sessionMovement.selectedVariant, set.reps > 0 else {
                    set.isPR = false
                    continue
                }
                let previousBest = bestByVariant[variant.persistentModelID] ?? 0
                if set.weight > previousBest {
                    set.isPR = true
                    bestByVariant[variant.persistentModelID] = set.weight
                } else {
                    set.isPR = false
                }
            }
        }
    }
}
