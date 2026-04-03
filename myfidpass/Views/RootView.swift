//
//  RootView.swift
//  myfidpass
//
//  Racine de l’app : affiche le flux auth/onboarding ou l’app principale selon l’état de connexion.
//

import SwiftUI
import CoreData

/// Établissement sélectionné → auth buttons. Sinon → recherche établissement.
/// Réactif : se remet à zéro dès que `placeId` est effacé (logout, suppression compte).
private struct WelcomeFlow: View {
    @State private var ready = FirstLaunchOnboarding.readPendingEstablishment().placeId != nil

    var body: some View {
        if ready {
            OnboardingChoiceView()
        } else {
            MyfidpassMerchantOnboardingRootView {
                ready = true
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        Group {
            switch authService.currentScreen {
            case .welcome:
                WelcomeFlow()
            case .authenticated:
                Group {
                    if !authService.merchantSubscriptionEligibilityResolved {
                        ZStack {
                            Color(.systemBackground).ignoresSafeArea()
                            VStack(spacing: 14) {
                                ProgressView()
                                Text("Chargement du compte…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .task {
                            await authService.refreshBusinessesIfNeeded()
                        }
                    } else {
                        ContentView()
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authService.currentScreen)
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSessionInvalidated)) { _ in
            // Reset serveur / compte supprimé : les JWT sont morts mais `isLoggedIn` restait vrai sans cette étape.
            authService.logout()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
