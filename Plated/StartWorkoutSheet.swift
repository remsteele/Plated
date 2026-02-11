import SwiftUI
import SwiftData

struct StartWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var selectedTemplate: WorkoutTemplate?

    var onStart: (WorkoutTemplate?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedTemplate = nil
                    } label: {
                        HStack {
                            Text("Empty Workout")
                            Spacer()
                            if selectedTemplate == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }

                Section("Templates") {
                    ForEach(templates) { template in
                        Button {
                            selectedTemplate = template
                        } label: {
                            HStack {
                                Text(template.name)
                                Spacer()
                                if selectedTemplate == template {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Start Workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        onStart(selectedTemplate)
                        dismiss()
                    }
                }
            }
        }
    }
}
