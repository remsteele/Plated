import SwiftUI

struct SettingsView: View {
    @AppStorage("unitPreference") private var unitPreference: String = "lb"

    var body: some View {
        List {
            Section("Units") {
                Picker("Weight Units", selection: $unitPreference) {
                    Text("lb").tag("lb")
                    Text("kg").tag("kg")
                }
                .pickerStyle(.segmented)
            }

            Section("Rest Timer") {
                Text("Default rest timer coming soon")
                    .foregroundStyle(.secondary)
            }

            Section("Data") {
                Text("Export and backup tools coming soon")
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                Text("Plated v1.0")
            }
        }
        .navigationTitle("Settings")
    }
}
