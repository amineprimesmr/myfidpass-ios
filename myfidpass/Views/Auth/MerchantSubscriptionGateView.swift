//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paywall natif RevenueCat (StoreKit) + lien optionnel Stripe (promo existante).
//

import SwiftUI
import RevenueCatUI

struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState

    @State private var showStripeFallback = false

    var body: some View {
        ZStack(alignment: .bottom) {
            PaywallView()

            stripeFallbackBar
        }
        .background(Color(.systemBackground))
        .task {
            await revenueCatSubscriptionState.refreshCustomerInfo()
        }
        .onChange(of: revenueCatSubscriptionState.hasPremiumEntitlement) { _, _ in
            if shouldDismissGateAsSubscribed { dismiss() }
        }
        .onChange(of: authService.merchantSubscription?.status) { _, _ in
            if shouldDismissGateAsSubscribed { dismiss() }
        }
        .onChange(of: authService.isPlatformAdmin) { _, _ in
            if shouldDismissGateAsSubscribed { dismiss() }
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

    @MainActor
    private func afterPurchaseOrRestore() async {
        await revenueCatSubscriptionState.refreshCustomerInfo()
        await authService.reconcileStripeSubscriptionFromServer(force: true)
        await authService.refreshBusinessesIfNeeded()
        syncService.invalidateSyncThrottle()
        await syncService.syncAfterServerMutation()
        if shouldDismissGateAsSubscribed {
            dismiss()
        }
    }
}

#Preview {
    Text("Paywall — ouvrir depuis ContentView après connexion")
        .padding()
}
