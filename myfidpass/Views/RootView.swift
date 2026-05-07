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
    @State private var stage: WelcomeStage = .entry
    @State private var authEntryPath: AuthEntryPath = .signUp

    private enum WelcomeStage {
        case entry
        case merchantPremises
        case authChoice
    }

    private enum AuthEntryPath {
        case signUp
        case signIn
    }

    var body: some View {
        Group {
            switch stage {
            case .entry:
                AuthLaunchEntryView(
                    onCreateAccount: {
                        authEntryPath = .signUp
                        FirstLaunchOnboarding.rewindToMerchantPremisesSelectionForFreshCommercePick()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            needsMerchantPremises = true
                            stage = .merchantPremises
                        }
                    },
                    onSignIn: {
                        authEntryPath = .signIn
                        FirstLaunchOnboarding.markRelaxPlaceRequirementForExistingAccountFlow()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            needsMerchantPremises = false
                            stage = .authChoice
                        }
                    }
                )
            case .merchantPremises:
                FirstLaunchOnboardingView(onComplete: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        needsMerchantPremises = false
                        stage = .authChoice
                    }
                }, onAlreadyHaveAccount: {
                    // Retour explicite depuis "Quel est votre commerce ?":
                    // revenir à l'écran d'entrée sans basculer dans la création de compte.
                    FirstLaunchOnboarding.rewindToMerchantPremisesSelectionForFreshCommercePick()
                    withAnimation(.easeInOut(duration: 0.25)) {
                        needsMerchantPremises = true
                        authEntryPath = .signUp
                        stage = .entry
                    }
                })
            case .authChoice:
                Group {
                    if authEntryPath == .signIn {
                        AuthSignInView(onBack: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                stage = .entry
                            }
                        })
                    } else {
                        AuthSignUpView(onBack: {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                stage = .entry
                            }
                        })
                    }
                }
            }
        }
        .id("welcome-flow-\(authService.firstLaunchOnboardingRestartEpoch)")
        .onChange(of: authService.firstLaunchOnboardingRestartEpoch) { _, _ in
            needsMerchantPremises = !FirstLaunchOnboarding.hasCompleted
            authEntryPath = .signUp
            stage = .entry
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage(AuthStorage.Key.isLoggedIn) private var isLoggedIn = false

    private var shouldShowAuthenticatedApp: Bool {
        authService.currentScreen == .authenticated && isLoggedIn
    }

    var body: some View {
        ZStack {
            if !shouldShowAuthenticatedApp {
                WelcomeFlow()
                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.985)), removal: .opacity))
            } else {
                Group {
                    if authService.isPlatformAdmin && !authService.adminShowsMerchantWorkspace {
                        PlatformAdminRootView()
                    } else {
                        ContentView()
                    }
                }
                .environment(\.managedObjectContext, viewContext)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.32), value: shouldShowAuthenticatedApp)
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
