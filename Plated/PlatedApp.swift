//
//  PlatedApp.swift
//  Plated
//
//  Created by Remington Steele on 2/10/26.
//

import SwiftUI
import CoreData

@main
struct PlatedApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
