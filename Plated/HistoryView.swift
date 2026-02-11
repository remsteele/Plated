import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var activeSession: WorkoutSession?

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.status == .completed }
    }

    var body: some View {
        List {
            if completedSessions.isEmpty {
                ContentUnavailableView("Start your first workout", systemImage: "bolt")
            } else {
                ForEach(completedSessions) { session in
                    NavigationLink {
                        WorkoutDetailView(session: session) {
                            let newSession = WorkoutSessionService.duplicateSession(from: session, context: modelContext)
                            activeSession = newSession
                        }
                    } label: {
                        WorkoutHistoryRow(session: session)
                    }
                }
            }
        }
        .navigationTitle("History")
        .sheet(item: $activeSession) { session in
            ActiveWorkoutView(session: session)
        }
    }
}

private struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.displayTitle)
                    .font(.headline)
                Spacer()
                Text(session.durationSeconds.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(PlatedFormatters.shortDateTime.string(from: session.startTime))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("PRs hit: \(session.personalRecordCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(sessionMovementSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var sessionMovementSummary: String {
        let names = session.orderedMovements.compactMap { $0.movement?.name }
        let counts = Dictionary(grouping: names, by: { $0 })
            .mapValues { $0.count }
        let sorted = names.reduce(into: [String]()) { result, name in
            if !result.contains(name) {
                result.append(name)
            }
        }
        let formatted = sorted.map { name in
            let count = counts[name, default: 1]
            return count > 1 ? "\(name) x\(count)" : name
        }
        return formatted.prefix(4).joined(separator: ", ") + (formatted.count > 4 ? "…" : "")
    }
}

private struct WorkoutDetailView: View {
    let session: WorkoutSession
    var onDuplicate: () -> Void

    @AppStorage("unitPreference") private var unitPreference: String = "lb"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.displayTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(PlatedFormatters.shortDateTime.string(from: session.startTime))
                        .foregroundStyle(.secondary)
                    Text("Duration: \(session.durationSeconds.formattedDuration)")
                        .foregroundStyle(.secondary)
                }

                ForEach(session.orderedMovements) { movement in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(movement.movement?.name ?? "Movement")
                                .font(.headline)
                            Spacer()
                            if let variant = movement.selectedVariant {
                                Text(variant.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(movement.orderedSets) { set in
                            HStack {
                                Text("Set \(set.setIndex)")
                                Spacer()
                                Text("\(UnitConverter.formattedWeight(set.weight, unit: unitPreference)) x \(set.reps)")
                            }
                            .font(set.id == movement.bestSet?.id ? .headline : .subheadline)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button("Duplicate as New Workout") {
                    onDuplicate()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Workout Detail")
    }
}
