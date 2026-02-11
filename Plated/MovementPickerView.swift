import SwiftUI
import SwiftData

struct MovementPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Movement.name) private var movements: [Movement]
    @State private var searchText = ""

    var onSelect: (Movement) -> Void

    private var filteredMovements: [Movement] {
        guard !searchText.isEmpty else { return movements }
        return movements.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredMovements) { movement in
                Button(movement.name) {
                    onSelect(movement)
                    dismiss()
                }
            }
            .navigationTitle("Add Movement")
            .searchable(text: $searchText)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
