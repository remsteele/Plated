import SwiftUI
import SwiftData
import Combine

struct ActiveWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitPreference") private var unitPreference: String = "lb"
    @AppStorage("restTimerSeconds") private var restTimerSeconds: Int = 90

    @Bindable var session: WorkoutSession

    @State private var now = Date()
    @State private var showingFinishAlert = false
    @State private var showingCancelAlert = false
    @State private var showingSummary = false
    @State private var showingMovementPicker = false
    @State private var restEndDate: Date?

    private var elapsedSeconds: Int {
        Int((session.endTime ?? now).timeIntervalSince(session.startTime))
    }

    private var restRemaining: Int {
        guard let restEndDate else { return 0 }
        return max(0, Int(restEndDate.timeIntervalSince(now)))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(session.orderedMovements) { movement in
                    Section {
                        ForEach(movement.orderedSets) { set in
                            SetRowView(
                                set: set,
                                resistanceLabel: movement.selectedVariant?.resistanceType.weightLabel ?? "Weight",
                                unit: unitPreference,
                                isBodyweight: movement.selectedVariant?.resistanceType == .bodyweight
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    removeSet(set, from: movement)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                        Button {
                            addSet(to: movement)
                        } label: {
                            Label("Add set", systemImage: "plus")
                                .font(.subheadline)
                        }
                    } header: {
                        SessionMovementHeaderView(sessionMovement: movement)
                    }
                }

                Section {
                    Button {
                        showingMovementPicker = true
                    } label: {
                        Label("Add Movement", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .listStyle(.insetGrouped)
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
                    Button {
                        startRestTimer()
                    } label: {
                        Text(restRemaining > 0 ? "Rest \(restRemaining.formattedDuration)" : "Start Rest")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                now = Date()
                if restRemaining == 0 {
                    restEndDate = nil
                }
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

    private func addSet(to movement: SessionMovement) {
        let nextIndex = (movement.performedSets.map { $0.setIndex }.max() ?? 0) + 1
        let newSet = PerformedSet(sessionMovement: movement, setIndex: nextIndex)
        modelContext.insert(newSet)
        movement.performedSets.append(newSet)
    }

    private func startRestTimer() {
        restEndDate = Date().addingTimeInterval(Double(restTimerSeconds))
    }
}

private struct SessionMovementHeaderView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var sessionMovement: SessionMovement

    private var movementName: String {
        sessionMovement.movement?.name ?? "Movement"
    }

    private var variantOptions: [MovementVariant] {
        sessionMovement.movement?.sortedVariants ?? []
    }

    init(sessionMovement: SessionMovement) {
        self._sessionMovement = Bindable(wrappedValue: sessionMovement)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(movementName)
                .font(.headline)
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
        }
        .textCase(nil)
        .onAppear {
            if sessionMovement.selectedVariant == nil, let movement = sessionMovement.movement {
                sessionMovement.selectedVariant = WorkoutSessionService.recommendedVariant(
                    for: movement,
                    context: modelContext
                )
            }
        }
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
        let weightBinding = Binding<Double>(
            get: { UnitConverter.displayWeight(from: set.weight, unit: unit) },
            set: { set.weight = UnitConverter.storedWeight(from: $0, unit: unit) }
        )

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
                        TextField("0", value: weightBinding, format: .number)
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
