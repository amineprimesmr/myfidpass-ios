//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paywall natif RevenueCat (StoreKit) — seul chemin de souscription dans l’app (Stripe retiré de l’UI).
//

import SwiftUI

struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState

    /// `true` : écran racine après connexion sans abonnement — pas de fermeture sans achat (déconnexion proposée).
    /// `false` : feuille modale (sheet) — pas de croix ; fermeture par glissement de la feuille ou après achat.
    var isMandatory: Bool = false

    /// Pendant l’essai gratuit, on autorise la fermeture du paywall obligatoire (croix + action).
    private var canCloseMandatoryGateDuringTrial: Bool {
        isMandatory && authService.isMerchantTrialPeriodActive
    }

    /// Croix uniquement sur le paywall **obligatoire** pendant l’essai — jamais sur la sheet (`!isMandatory`).
    private var showsPaywallCloseButton: Bool {
        canCloseMandatoryGateDuringTrial
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            CustomMerchantProPaywallView(
                allowsCloseButton: showsPaywallCloseButton,
                onCloseRequested: showsPaywallCloseButton ? { finishMerchantSubscriptionGate() } : nil,
                headerExtraTopPadding: isMandatory ? 4 : 28
            )

            if isMandatory && !canCloseMandatoryGateDuringTrial {
                VStack(spacing: 0) {
                    Button {
                        authService.logout()
                    } label: {
                        Text("Se déconnecter")
                            .font(AppTheme.Fonts.subheadline().weight(.medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 100)
                    .allowsHitTesting(false)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await revenueCatSubscriptionState.refreshCustomerInfo()
        }
        .onChange(of: revenueCatSubscriptionState.hasPremiumEntitlement) { _, _ in
            if shouldDismissGateAsSubscribed { finishMerchantSubscriptionGate() }
        }
        .onChange(of: authService.merchantSubscription?.status) { _, _ in
            if shouldDismissGateAsSubscribed { finishMerchantSubscriptionGate() }
        }
        .onChange(of: authService.isPlatformAdmin) { _, _ in
            if shouldDismissGateAsSubscribed { finishMerchantSubscriptionGate() }
        }
        .onChange(of: authService.hasActiveMerchantSubscription) { _, _ in
            if shouldDismissGateAsSubscribed { finishMerchantSubscriptionGate() }
        }
    }

    private var shouldDismissGateAsSubscribed: Bool {
        authService.isPlatformAdmin
            || authService.hasPaidStripeSubscription
            || revenueCatSubscriptionState.hasPremiumEntitlement
    }

    /// Ferme la feuille modale ; le flag post-inscription est nettoyé pour compatibilité.
    @MainActor
    private func finishMerchantSubscriptionGate() {
        authService.clearMandatoryPaywallAfterSignupPending()
        if !isMandatory {
            dismiss()
        }
    }
}

#Preview {
    Text("Paywall")
        .padding()
}
