import Foundation
import SwiftData
import Combine

final class StartWorkoutCoordinator: ObservableObject {
    @Published var duplicateSession: WorkoutSession?

    func setDuplicate(session: WorkoutSession) {
        duplicateSession = session
    }

    func reset() {
        duplicateSession = nil
    }
}
