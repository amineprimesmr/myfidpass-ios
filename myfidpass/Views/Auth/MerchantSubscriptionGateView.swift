//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paywall natif RevenueCat (StoreKit) + lien optionnel Stripe (promo existante).
//

import SwiftUI

struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState

    @State private var showStripeFallback = false

    var body: some View {
        ZStack(alignment: .bottom) {
            CustomMerchantProPaywallView(onCloseRequested: finishMerchantSubscriptionGate)

            stripeFallbackBar
        }
        .background(Color.black)
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
        .sheet(isPresented: $showStripeFallback) {
            InAppSafariView(url: stripeCheckoutURL)
                .ignoresSafeArea()
        }
    }

    private var stripeCheckoutURL: URL {
        let email = authService.currentUserEmail ?? AuthStorage.userEmail
        return LegalURLs.merchantStripeSubscriptionPaymentLinkWithPromo(prefilledEmail: email)
    }

    private var stripeFallbackBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                showStripeFallback = true
            } label: {
                Text("Préférer le paiement sur le web (Stripe, promo 1 €)")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        }
        .background(.ultraThinMaterial)
    }

    private var shouldDismissGateAsSubscribed: Bool {
        authService.isPlatformAdmin
            || authService.hasPaidStripeSubscription
            || revenueCatSubscriptionState.hasPremiumEntitlement
    }

    /// Ferme la feuille / consomme le flag post-inscription pour laisser place à l’app.
    @MainActor
    private func finishMerchantSubscriptionGate() {
        AuthStorage.pendingOpenMerchantSubscriptionSheetAfterSignup = false
        dismiss()
    }
}

#Preview {
    Text("Paywall — ouvrir depuis ContentView après connexion")
        .padding()
}
