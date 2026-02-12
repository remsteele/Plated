import SwiftUI
import SwiftData

struct TemplatesView: View {
    enum Segment: String, CaseIterable {
        case templates = "Templates"
        case movements = "Movements"
    }

    enum DeleteTarget: Identifiable {
        case template(WorkoutTemplate)
        case movement(Movement)

        var id: String {
            switch self {
            case .template(let template):
                return String(describing: template.persistentModelID)
            case .movement(let movement):
                return String(describing: movement.persistentModelID)
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(sort: \Movement.name) private var movements: [Movement]

    @State private var selection: Segment = .templates
    @State private var searchText = ""
    @State private var templateEditor: WorkoutTemplate?
    @State private var templateIsNew = false
    @State private var movementEditor: Movement?
    @State private var movementIsNew = false
    @State private var deleteTarget: DeleteTarget?

    var body: some View {
        VStack {
            Picker("View", selection: $selection) {
                ForEach(Segment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            List {
                switch selection {
                case .templates:
                    templatesSection
                case .movements:
                    movementsSection
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Templates")
        .searchable(text: $searchText)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if selection == .templates {
                        let template = WorkoutTemplate(name: "")
                        modelContext.insert(template)
                        templateIsNew = true
                        templateEditor = template
                    } else {
                        let movement = Movement(name: "", category: "")
                        modelContext.insert(movement)
                        movementIsNew = true
                        movementEditor = movement
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $templateEditor) { template in
            TemplateEditorView(template: template, isNew: templateIsNew)
        }
        .sheet(item: $movementEditor) { movement in
            MovementEditorView(movement: movement, isNew: movementIsNew)
        }
        .alert(item: $deleteTarget) { target in
            Alert(
                title: Text("Delete item?"),
                message: Text("This cannot be undone."),
                primaryButton: .destructive(Text("Delete"), action: {
                    switch target {
                    case .template(let template):
                        modelContext.delete(template)
                    case .movement(let movement):
                        modelContext.delete(movement)
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }

    private var templatesSection: some View {
        Group {
            if filteredTemplates.isEmpty {
                ContentUnavailableView("Create your first template", systemImage: "list.bullet.rectangle")
            } else {
                ForEach(filteredTemplates) { template in
                    Button {
                        templateIsNew = false
                        templateEditor = template
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(template.name)
                                    .font(.headline)
                                Text("\(template.templateItems.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
            }
        }
    }

    private var movementsSection: some View {
        Group {
            if filteredMovements.isEmpty {
                ContentUnavailableView("Create a movement like ‘Lateral Raise’", systemImage: "figure.strengthtraining.traditional")
            } else {
                ForEach(filteredMovements) { movement in
                    Button {
                        movementIsNew = false
                        movementEditor = movement
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(movement.name)
                                    .font(.headline)
                                Text("\(movement.category)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(movement.variants.count) variants")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteMovements)
            }
        }
    }

    private var filteredTemplates: [WorkoutTemplate] {
        guard !searchText.isEmpty else { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredMovements: [Movement] {
        guard !searchText.isEmpty else { return movements }
        return movements.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private func deleteTemplates(offsets: IndexSet) {
        if let index = offsets.first {
            deleteTarget = .template(filteredTemplates[index])
        }
    }

    private func deleteMovements(offsets: IndexSet) {
        if let index = offsets.first {
            deleteTarget = .movement(filteredMovements[index])
        }
    }
}

private struct TemplateEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Movement.name) private var movements: [Movement]

    @Bindable var template: WorkoutTemplate
    let isNew: Bool

    @State private var showingItemEditor = false
    @State private var itemToEdit: TemplateItem?

    init(template: WorkoutTemplate, isNew: Bool) {
        self._template = Bindable(wrappedValue: template)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Template") {
                    TextField("Name", text: $template.name)
                }

                Section("Items") {
                    ForEach(template.sortedItems) { item in
                        Button {
                            itemToEdit = item
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.movement?.name ?? "Movement")
                                Text("Quantity: \(item.quantity) | Sets: \(item.targetSets ?? item.movement?.defaultSetCount ?? 3)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                    .onMove(perform: moveItems)

                    Button {
                        showingItemEditor = true
                    } label: {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isNew ? "New Template" : "Edit Template")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew {
                            modelContext.delete(template)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                        .disabled(template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingItemEditor) {
                TemplateItemEditorView(template: template, movements: movements)
            }
            .sheet(item: $itemToEdit) { item in
                TemplateItemEditorView(template: template, movements: movements, item: item)
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(template.sortedItems[index])
        }
        resetOrdering()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = template.sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.orderingIndex = index
        }
    }

    private func resetOrdering() {
        for (index, item) in template.sortedItems.enumerated() {
            item.orderingIndex = index
        }
    }
}

private struct TemplateItemEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let template: WorkoutTemplate
    let movements: [Movement]
    var item: TemplateItem?

    @State private var selectedMovement: Movement?
    @State private var quantity: Int = 1
    @State private var targetSets: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    Menu {
                        ForEach(movements) { movement in
                            Button(movement.name) {
                                selectedMovement = movement
                            }
                        }
                    } label: {
                        HStack {
                            Text("Movement")
                            Spacer()
                            Text(selectedMovement?.name ?? "Select")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Volume") {
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...5)
                    TextField("Target Sets (optional)", text: $targetSets)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(item == nil ? "Add Item" : "Edit Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveItem() }
                        .disabled(selectedMovement == nil)
                }
            }
            .onAppear {
                if let item {
                    selectedMovement = item.movement
                    quantity = item.quantity
                    targetSets = item.targetSets.map(String.init) ?? ""
                } else {
                    selectedMovement = movements.first
                }
            }
        }
    }

    private func saveItem() {
        guard let movement = selectedMovement else { return }
        let setsValue = Int(targetSets)

        if let item {
            item.movement = movement
            item.quantity = quantity
            item.targetSets = setsValue
        } else {
            let newItem = TemplateItem(
                template: template,
                movement: movement,
                quantity: quantity,
                targetSets: setsValue,
                orderingIndex: template.templateItems.count
            )
            template.templateItems.append(newItem)
        }
        dismiss()
    }
}

private struct MovementEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Movement.name) private var movements: [Movement]

    @Bindable var movement: Movement
    let isNew: Bool

    @State private var showDuplicateAlert = false

    private let baseCategories = [
        "Chest",
        "Shoulders",
        "Back",
        "Legs",
        "Arms",
        "Core",
        "Full Body",
        "Cardio"
    ]

    init(movement: Movement, isNew: Bool) {
        self._movement = Bindable(wrappedValue: movement)
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Movement") {
                    TextField("Name", text: $movement.name)
                    Menu {
                        ForEach(categoryOptions, id: \.self) { category in
                            Button(category) {
                                movement.category = category
                            }
                        }
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(movement.category.isEmpty ? "Select" : movement.category)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Stepper("Default Sets: \(movement.defaultSetCount)", value: $movement.defaultSetCount, in: 1...10)
                    TextField("Notes", text: Binding(
                        get: { movement.notes ?? "" },
                        set: { movement.notes = $0 }
                    ))
                }

                Section("Variants") {
                    ForEach(movement.sortedVariants) { variant in
                        VariantRowView(variant: variant, movementName: movement.name)
                    }
                    .onDelete(perform: deleteVariants)

                    Button {
                        addVariant()
                    } label: {
                        Label("Add Variant", systemImage: "plus")
                    }
                }
            }
            .navigationTitle(isNew ? "New Movement" : "Edit Movement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { modelContext.delete(movement) }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMovement() }
                }
            }
            .alert("Movement name must be unique", isPresented: $showDuplicateAlert) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private func deleteVariants(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(movement.sortedVariants[index])
        }
    }

    private func saveMovement() {
        let trimmed = movement.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let lower = trimmed.lowercased()
        let duplicates = movements.filter { $0.id != movement.id && $0.name.lowercased() == lower }
        if !duplicates.isEmpty {
            showDuplicateAlert = true
            return
        }
        movement.name = trimmed
        dismiss()
    }

    private func addVariant() {
        let preset = variantPresets.first ?? VariantPreset(title: "Custom • Total Weight", name: "Custom", resistanceType: .totalWeight)
        let newVariant = MovementVariant(
            movement: movement,
            name: preset.name,
            resistanceType: preset.resistanceType
        )
        movement.variants.append(newVariant)
    }

    private var categoryOptions: [String] {
        let current = movement.category.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { return baseCategories }
        if baseCategories.contains(where: { $0.lowercased() == current.lowercased() }) {
            return baseCategories
        }
        return [current] + baseCategories
    }
}

private struct VariantRowView: View {
    @Bindable var variant: MovementVariant
    let movementName: String

    @State private var showCustomName = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(combinedName)
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(variantPresets) { preset in
                        Button(preset.title) {
                            variant.name = preset.name
                            variant.resistanceType = preset.resistanceType
                            showCustomName = false
                        }
                    }
                    Button("Custom name…") {
                        showCustomName = true
                    }
                } label: {
                    Text(variant.name.isEmpty ? "Select" : variant.name)
                        .foregroundStyle(.secondary)
                }
            }

            if showCustomName || !matchesPreset {
                TextField("Custom name", text: $variant.name)
            }
        }
        .onAppear {
            showCustomName = !matchesPreset
        }
    }

    private var matchesPreset: Bool {
        variantPresets.contains { preset in
            preset.name.lowercased() == variant.name.lowercased() && preset.resistanceType == variant.resistanceType
        }
    }

    private var combinedName: String {
        let trimmed = variant.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return movementName
        }
        return "\(trimmed) \(movementName)"
    }
}

private let variantPresets: [VariantPreset] = [
    VariantPreset(title: "Dumbbell • Per Dumbbell", name: "Dumbbell", resistanceType: .perDumbbell),
    VariantPreset(title: "Barbell • Total Weight", name: "Barbell", resistanceType: .totalWeight),
    VariantPreset(title: "Machine • Total Weight", name: "Machine", resistanceType: .totalWeight),
    VariantPreset(title: "Cable • Stack Weight", name: "Cable", resistanceType: .cableStack),
    VariantPreset(title: "Bodyweight", name: "Bodyweight", resistanceType: .bodyweight),
    VariantPreset(title: "Assisted", name: "Assisted", resistanceType: .assisted)
]

private struct VariantPreset: Identifiable {
    let id = UUID()
    let title: String
    let name: String
    let resistanceType: ResistanceType
}
