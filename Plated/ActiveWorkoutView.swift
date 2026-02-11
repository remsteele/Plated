import SwiftUI
import SwiftData
import Combine

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitPreference") private var unitPreference: String = "lb"

    @Bindable var session: WorkoutSession

    @State private var now = Date()
    @State private var showingFinishAlert = false
    @State private var showingCancelAlert = false
    @State private var showingSummary = false
    @State private var showingMovementPicker = false

    private var elapsedSeconds: Int {
        Int((session.endTime ?? now).timeIntervalSince(session.startTime))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(session.orderedMovements) { movement in
                        SessionMovementCardView(
                            sessionMovement: movement,
                            unitPreference: unitPreference,
                            onRemoveSet: { set in
                                removeSet(set, from: movement)
                            }
                        )
                    }

                    Button {
                        showingMovementPicker = true
                    } label: {
                        Label("Add Movement", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle(session.displayTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showingCancelAlert = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { showingFinishAlert = true }
                }
            }
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(elapsedSeconds.formattedDuration)
                        .font(.headline)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                now = Date()
            }
            .alert("Finish Workout?", isPresented: $showingFinishAlert) {
                Button("Finish", role: .destructive) {
                    WorkoutSessionService.finishSession(session, context: modelContext)
                    showingSummary = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will complete the workout and save your sets.")
            }
            .alert("Cancel Workout?", isPresented: $showingCancelAlert) {
                Button("Cancel Workout", role: .destructive) {
                    WorkoutSessionService.cancelSession(session)
                    dismiss()
                }
                Button("Keep Going", role: .cancel) {}
            } message: {
                Text("Progress will be saved as cancelled.")
            }
            .sheet(isPresented: $showingMovementPicker) {
                MovementPickerView { movement in
                    _ = WorkoutSessionService.addMovement(to: session, movement: movement, context: modelContext)
                }
            }
            .sheet(isPresented: $showingSummary) {
                WorkoutSummaryView(session: session) {
                    dismiss()
                }
            }
        }
    }

    private func removeSet(_ set: PerformedSet, from movement: SessionMovement) {
        if let index = movement.performedSets.firstIndex(where: { $0.id == set.id }) {
            movement.performedSets.remove(at: index)
            modelContext.delete(set)
            for (idx, item) in movement.orderedSets.enumerated() {
                item.setIndex = idx + 1
            }
        }
    }
}

private struct SessionMovementCardView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var sessionMovement: SessionMovement
    let unitPreference: String
    var onRemoveSet: (PerformedSet) -> Void

    private var movementName: String {
        sessionMovement.movement?.name ?? "Movement"
    }

    private var variantOptions: [MovementVariant] {
        sessionMovement.movement?.sortedVariants ?? []
    }

    private var resistanceLabel: String {
        sessionMovement.selectedVariant?.resistanceType.weightLabel ?? "Weight"
    }

    init(
        sessionMovement: SessionMovement,
        unitPreference: String,
        onRemoveSet: @escaping (PerformedSet) -> Void
    ) {
        self._sessionMovement = Bindable(wrappedValue: sessionMovement)
        self.unitPreference = unitPreference
        self.onRemoveSet = onRemoveSet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(movementName)
                    .font(.headline)
                Spacer()
                if let selected = sessionMovement.selectedVariant {
                    Text(selected.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Menu {
                ForEach(variantOptions) { variant in
                    Button(variant.name) {
                        sessionMovement.selectedVariant = variant
                    }
                }
            } label: {
                HStack {
                    Text("Variant")
                    Spacer()
                    Text(sessionMovement.selectedVariant?.name ?? "Select")
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                ForEach(sessionMovement.orderedSets) { set in
                    SetRowView(
                        set: set,
                        resistanceLabel: resistanceLabel,
                        unit: sessionMovement.selectedVariant?.unit ?? unitPreference,
                        isBodyweight: sessionMovement.selectedVariant?.resistanceType == .bodyweight
                    )
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            onRemoveSet(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }

            Button {
                addSet()
            } label: {
                Label("Add set", systemImage: "plus")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            if sessionMovement.selectedVariant == nil, let movement = sessionMovement.movement {
                sessionMovement.selectedVariant = WorkoutSessionService.recommendedVariant(
                    for: movement,
                    context: modelContext
                )
            }
        }
    }

    private func addSet() {
        let nextIndex = (sessionMovement.performedSets.map { $0.setIndex }.max() ?? 0) + 1
        let newSet = PerformedSet(sessionMovement: sessionMovement, setIndex: nextIndex)
        modelContext.insert(newSet)
        sessionMovement.performedSets.append(newSet)
    }
}

private struct SetRowView: View {
    @Bindable var set: PerformedSet
    let resistanceLabel: String
    let unit: String
    let isBodyweight: Bool

    init(set: PerformedSet, resistanceLabel: String, unit: String, isBodyweight: Bool) {
        self._set = Bindable(wrappedValue: set)
        self.resistanceLabel = resistanceLabel
        self.unit = unit
        self.isBodyweight = isBodyweight
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("Set \(set.setIndex)")
                .font(.caption)
                .frame(width: 52, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(resistanceLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack {
                    if isBodyweight {
                        Text("BW")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        TextField("0", value: $set.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Reps")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }

            Spacer()

            Toggle("Done", isOn: $set.isCompleted)
                .labelsHidden()
        }
    }
}

private struct WorkoutSummaryView: View {
    let session: WorkoutSession
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Workout Complete")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Duration: \(session.durationSeconds.formattedDuration)")
                    .foregroundStyle(.secondary)
                Text("PRs hit: \(session.personalRecordCount)")
                    .foregroundStyle(.secondary)
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Summary")
        }
    }
}
