//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paywall souscription : Stripe Checkout (API SaaS), avec réconciliation après retour dans l’app.
//

import SwiftUI
import UIKit

struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    /// `true` : écran racine après connexion sans abonnement.
    /// `false` : feuille modale (sheet) — fermeture par glissement uniquement.
    var isMandatory: Bool = false

    /// Croix affichée sur le paywall **obligatoire** (post-inscription) — jamais sur la sheet.
    private var showsPaywallCloseButton: Bool {
        isMandatory
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MerchantSaasPaymentWebView(
                allowsCloseButton: showsPaywallCloseButton,
                onCloseRequested: showsPaywallCloseButton ? { finishMerchantSubscriptionGate() } : nil,
                headerExtraTopPadding: isMandatory ? 4 : 28,
                closeButtonRevealDelay: (isMandatory && showsPaywallCloseButton) ? 0 : 5,
                webContentExtraTopInset: isMandatory ? 10 : 22
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await authService.reconcileStripeSubscriptionFromServer(force: true)
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
