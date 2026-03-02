//
//  RootView.swift
//  myfidpass
//
//  Racine de l’app : affiche le flux auth/onboarding ou l’app principale selon l’état de connexion.
//

import SwiftUI
import CoreData

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            switch authService.currentScreen {
            case .welcome:
                OnboardingChoiceView()
            case .login:
                NavigationStack {
                    LoginView()
                }
            case .authenticated:
                ContentView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.currentScreen)
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
