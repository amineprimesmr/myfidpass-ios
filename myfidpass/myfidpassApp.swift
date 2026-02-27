//
//  myfidpassApp.swift
//  myfidpass
//
//  Created by Amine Ennasri on 27/02/2026.
//

import SwiftUI
import CoreData

@main
struct myfidpassApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
