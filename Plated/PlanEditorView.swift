import SwiftUI
import SwiftData

struct PlanEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @Bindable var plan: WorkoutPlan

    init(plan: WorkoutPlan) {
        self._plan = Bindable(wrappedValue: plan)
    }

    private let weekdays = [
        (1, "Monday"), (2, "Tuesday"), (3, "Wednesday"), (4, "Thursday"),
        (5, "Friday"), (6, "Saturday"), (7, "Sunday")
    ]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(plan.sortedDays) { day in
                    Section(weekdayName(for: day.weekday)) {
                        PlanDayEditorRow(day: day, templates: templates)
                    }
                }
            }
            .navigationTitle("Edit Plan")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func weekdayName(for value: Int) -> String {
        weekdays.first(where: { $0.0 == value })?.1 ?? "Day"
    }
}

private struct PlanDayEditorRow: View {
    @Bindable var day: PlannedWorkoutDay
    let templates: [WorkoutTemplate]

    init(day: PlannedWorkoutDay, templates: [WorkoutTemplate]) {
        self._day = Bindable(wrappedValue: day)
        self.templates = templates
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                PlatedFormatters.timeFormatter.date(from: day.timeOfDay) ?? Date()
            },
            set: { newValue in
                day.timeOfDay = PlatedFormatters.timeFormatter.string(from: newValue)
            }
        )
    }

    var body: some View {
        Toggle("Scheduled", isOn: $day.enabled)

        if day.enabled {
            DatePicker("Time", selection: timeBinding, displayedComponents: .hourAndMinute)
            TemplateMenuView(selectedTemplate: $day.template, templates: templates)
            TextField("Split Label", text: Binding(
                get: { day.splitLabel ?? "" },
                set: { day.splitLabel = $0 }
            ))
        }
    }
}

private struct TemplateMenuView: View {
    @Binding var selectedTemplate: WorkoutTemplate?
    let templates: [WorkoutTemplate]

    var body: some View {
        Menu {
            Button("None") { selectedTemplate = nil }
            ForEach(templates) { template in
                Button(template.name) {
                    selectedTemplate = template
                }
            }
        } label: {
            HStack {
                Text("Template")
                Spacer()
                Text(selectedTemplate?.name ?? "None")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
