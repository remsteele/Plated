//
//  ContentView.swift
//  GymFlow
//
//  Created by Remington Steele on 2/10/26.
//

import SwiftUI
import SwiftData

// Root entry view for Plated. Provides TabView + persistent Start Workout button.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        RootTabsView()
            .task { await SeedDataService.seedIfNeeded(context: modelContext) }
    }
}

#Preview {
    ContentView()
}
