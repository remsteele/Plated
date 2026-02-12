import SwiftUI
import SwiftData
import Combine

struct RootTabsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \WorkoutSession.startTime,
        order: .reverse
    ) private var sessions: [WorkoutSession]

    @State private var selectedTab = 0
    @State private var showingStartSheet = false
    @State private var activeSession: WorkoutSession?
    @StateObject private var startWorkoutCoordinator = StartWorkoutCoordinator()
    @State private var now = Date()

    private var inProgressSessions: [WorkoutSession] {
        sessions.filter { $0.status == .inProgress }
    }

    var body: some View {
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
        .environmentObject(startWorkoutCoordinator)
        .overlay(alignment: .bottom) {
            StartWorkoutBar(title: barTitle, subtitle: barSubtitle, systemImage: barIcon) {
                if let current = inProgressSession {
                    activeSession = current
                } else if let duplicate = startWorkoutCoordinator.duplicateSession {
                    let session = WorkoutSessionService.duplicateSession(from: duplicate, context: modelContext)
                    activeSession = session
                    startWorkoutCoordinator.reset()
                } else {
                    showingStartSheet = true
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 58)
            .animation(.easeInOut(duration: 0.2), value: barTitle)
            .animation(.easeInOut(duration: 0.2), value: barSubtitle)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != 1 {
                startWorkoutCoordinator.reset()
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

    private var barTitle: String {
        if inProgressSession != nil {
            return "Continue Workout"
        }
        return startWorkoutCoordinator.duplicateSession == nil ? "Start Workout" : "Repeat Workout"
    }

    private var barIcon: String {
        if inProgressSession != nil {
            return "play.fill"
        }
        return startWorkoutCoordinator.duplicateSession == nil ? "bolt.fill" : "doc.on.doc"
    }

    private var barSubtitle: String? {
        guard let session = inProgressSession else { return nil }
        let elapsed = Int(now.timeIntervalSince(session.startTime))
        return elapsed.formattedDuration
    }

    private var inProgressSession: WorkoutSession? {
        inProgressSessions.first
    }
}

private struct StartWorkoutBar: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(title)
                    .fontWeight(.semibold)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(radius: 6)
        .animation(.easeInOut(duration: 0.2), value: title)
    }
}
