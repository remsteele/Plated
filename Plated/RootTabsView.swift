import SwiftUI
import SwiftData

struct RootTabsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var selectedTab = 0
    @State private var showingStartSheet = false
    @State private var activeSession: WorkoutSession?

    private var inProgressSessions: [WorkoutSession] {
        sessions.filter { $0.status == .inProgress }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                NavigationStack {
                    ProfileView()
                }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(0)

                NavigationStack {
                    HistoryView()
                }
                .tabItem { Label("History", systemImage: "clock") }
                .tag(1)

                NavigationStack {
                    TemplatesView()
                }
                .tabItem { Label("Templates", systemImage: "list.bullet.rectangle") }
                .tag(2)

                NavigationStack {
                    SettingsView()
                }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(3)
            }
            StartWorkoutButton {
                if let current = inProgressSessions.first {
                    activeSession = current
                } else {
                    showingStartSheet = true
                }
            }
        }
        .sheet(isPresented: $showingStartSheet) {
            StartWorkoutSheet { template in
                let session = WorkoutSessionService.createSession(template: template, context: modelContext)
                activeSession = session
            }
        }
        .sheet(item: $activeSession) { session in
            ActiveWorkoutView(session: session)
        }
    }
}

private struct StartWorkoutButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                Text("Start Workout")
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.primary)
            .foregroundColor(Color(UIColor.systemBackground))
            .clipShape(Capsule())
            .shadow(radius: 8)
        }
        .padding(.bottom, 24)
    }
}
