//
//  RootView.swift
//  myfidpass
//
//  Racine : onboarding / auth (Process) ou app connectée.
//

import SwiftUI
import CoreData

/// Accueil : welcome intégrée au parcours commerçant → connexion ou app authentifiée.
private struct WelcomeFlow: View {
    @EnvironmentObject private var authService: AuthService

    @State private var stage: WelcomeStage = .onboarding
    @State private var signInPrefillIdentifier: String?
    @State private var signInAccountAlreadyVerified = false

    private enum WelcomeStage {
        case onboarding
        case signInFlow
        case signUpChoice
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea()

            stageContent
        }
        .id("welcome-flow-\(authService.firstLaunchOnboardingRestartEpoch)")
        .onChange(of: authService.firstLaunchOnboardingRestartEpoch) { _, _ in
            resetSignInFlowState()
            stage = .onboarding
        }
    }

    @ViewBuilder
    private var stageContent: some View {
        switch stage {
        case .onboarding:
            FirstLaunchOnboardingView(
                onComplete: handleMerchantPremisesComplete,
                onSignIn: { transition(to: .signInFlow) },
                onAlreadyHaveAccount: handleMerchantPremisesAlreadyHaveAccount,
                onExistingAccountEmail: handleExistingAccountEmailDuringOnboarding
            )
            .environmentObject(authService)
        case .signInFlow:
            AuthSignInEmailFlowView(
                initialIdentifier: signInPrefillIdentifier,
                accountAlreadyVerified: signInAccountAlreadyVerified,
                onBack: { transition(to: .onboarding) }
            )
            .environmentObject(authService)
        case .signUpChoice:
            AuthSignUpOtpFlowView(onBack: { transition(to: .onboarding) })
                .environmentObject(authService)
        }
    }

    private func transition(to newStage: WelcomeStage) {
        if newStage == .signInFlow {
            FirstLaunchOnboarding.markRelaxPlaceRequirementForExistingAccountFlow()
            signInPrefillIdentifier = FirstLaunchOnboarding.readSignupEmail()
            signInAccountAlreadyVerified = false
        } else if newStage == .onboarding {
            resetSignInFlowState()
        }

        withAnimation(.onboardingTransition) {
            stage = newStage
        }
    }

    private func resetSignInFlowState() {
        signInPrefillIdentifier = nil
        signInAccountAlreadyVerified = false
    }

    private func handleMerchantPremisesComplete() {
        guard authService.currentScreen != .authenticated else { return }
        transition(to: .signUpChoice)
    }

    private func handleMerchantPremisesAlreadyHaveAccount() {
        FirstLaunchOnboarding.markRelaxPlaceRequirementForExistingAccountFlow()
        signInPrefillIdentifier = FirstLaunchOnboarding.readSignupEmail()
        transition(to: .signInFlow)
    }

    private func handleExistingAccountEmailDuringOnboarding(_ email: String) {
        FirstLaunchOnboarding.persistSignupEmail(email)
        signInPrefillIdentifier = email
        signInAccountAlreadyVerified = true
        withAnimation(.onboardingTransition) {
            stage = .signInFlow
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage(AuthStorage.Key.isLoggedIn) private var isLoggedIn = false

    private var shouldShowAuthenticatedApp: Bool {
        authService.currentScreen == .authenticated
            && isLoggedIn
            && !authService.isCompletingSignupCardSetup
            && !authService.isCompletingSignupPaywallPhase
    }

    var body: some View {
        ZStack {
            if shouldShowAuthenticatedApp {
                Group {
                    if authService.isPlatformAdmin && !authService.adminShowsMerchantWorkspace {
                        PlatformAdminRootView()
                    } else {
                        ContentView()
                    }
                }
                .animation(nil, value: authService.isPlatformAdmin)
                .animation(nil, value: authService.adminShowsMerchantWorkspace)
                .environment(\.managedObjectContext, viewContext)
                .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
                .task(id: isLoggedIn) {
                    guard isLoggedIn, authService.currentScreen == .authenticated else { return }
                    await authService.bootstrapAuthenticatedSessionIfNeeded(force: false)
                }
            } else {
                WelcomeFlow()
                    .environmentObject(authService)
            }
        }
        .animation(shouldShowAuthenticatedApp ? .onboardingTransition : nil, value: shouldShowAuthenticatedApp)
        .appVersionUpdateCheck()
        .merchantProUnlockFlow()
    }
}
