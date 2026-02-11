import SwiftUI

struct SettingsView: View {
    @AppStorage("unitPreference") private var unitPreference: String = "lb"
    @AppStorage("restTimerSeconds") private var restTimerSeconds: Int = 90

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
                Stepper(value: $restTimerSeconds, in: 30...300, step: 15) {
                    Text("Default: \(restTimerSeconds.formattedDuration)")
                }
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
