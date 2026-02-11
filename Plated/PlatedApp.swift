//
//  PlatedApp.swift
//  Plated
//
//  Created by Remington Steele on 2/10/26.
//

import SwiftUI
import SwiftData

@main
struct PlatedApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(AppModelContainer.shared)
    }
}
