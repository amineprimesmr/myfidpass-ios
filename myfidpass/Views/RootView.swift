//
//  RootView.swift
//  myfidpass
//
//  Racine de l’app : affiche le flux auth/onboarding ou l’app principale selon l’état de connexion.
//

import SwiftUI
import CoreData

/// Accueil : renseigner l'établissement si la phase `merchantPremises` n'est pas terminée
/// (premier lancement explicite ou après suppression de compte), sinon écran connexion / inscription.
private struct WelcomeFlow: View {
    @EnvironmentObject private var authService: AuthService

    /// Snapshot au montage (et à chaque incrément de `firstLaunchOnboardingRestartEpoch` via `.id`).
    @State private var needsMerchantPremises: Bool = !FirstLaunchOnboarding.hasCompleted

    var body: some View {
        Group {
            if needsMerchantPremises {
                FirstLaunchOnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        needsMerchantPremises = false
                    }
                })
            } else {
                OnboardingChoiceView()
            }
        }
        .id("welcome-flow-\(authService.firstLaunchOnboardingRestartEpoch)")
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext
    /// Même clé que `MainTabView` / `OneTimeOnBoarding` : tant que le tutoriel n’est pas fini, on n’affiche pas
    /// l’écran « Chargement du compte… » (sinon icône de chargement par-dessus le parcours tutoriel).
    @AppStorage("myfidpass.homeTutorial.v1") private var homeTutorialCompleted = false

    /// Blocage plein écran uniquement pour les comptes qui ont **déjà** terminé le tutoriel (retour app, cold start).
    private var shouldBlockAuthenticatedUIForBootstrap: Bool {
        !authService.merchantSubscriptionEligibilityResolved && homeTutorialCompleted
    }

    var body: some View {
        Group {
            switch authService.currentScreen {
            case .welcome:
                WelcomeFlow()
            case .authenticated:
                Group {
                    if shouldBlockAuthenticatedUIForBootstrap {
                        ZStack {
                            Color(.systemBackground).ignoresSafeArea()
                            VStack(spacing: 14) {
                                ProgressView()
                                Text("Chargement du compte…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Group {
                            if authService.isPlatformAdmin && !authService.adminShowsMerchantWorkspace {
                                PlatformAdminRootView()
                            } else {
                                ContentView()
                            }
                        }
                        .environment(\.managedObjectContext, viewContext)
                    }
                }
                .task {
                    if !authService.merchantSubscriptionEligibilityResolved {
                        await authService.refreshBusinessesIfNeeded()
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
        .environmentObject(RevenueCatSubscriptionState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .onAppear {
            RevenueCatBootstrap.configureIfNeeded()
        }
}
