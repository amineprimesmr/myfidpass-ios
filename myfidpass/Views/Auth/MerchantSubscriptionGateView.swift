//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paiement Stripe (hors IAP). Présenté en feuille depuis le bandeau freemium ou après blocage API.
//

import SwiftUI

/// Feuille « Souscrire » (Stripe) : affichée depuis le bandeau freemium ou après un 403 `subscription_required`.
struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @State private var checkoutURL: URL?
    @State private var showCheckout = false
    @State private var legalSafariURL: URL?
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Abonnement requis")
                        .font(.title2.weight(.bold))

                    Text(
                        "Vous pouvez déjà tout configurer dans l’app. Pour le scan QR, créditer des points, les imports membres et les campagnes clients, une offre MyFidpass active est nécessaire. Une période d’essai peut être proposée sur la page de paiement Stripe."
                    )
                    .font(.body)
                    .foregroundStyle(.secondary)

                    Text(
                        "L’app ne propose pas d’achat intégré (In-App Purchase). Le paiement sécurisé s’effectue sur notre page Stripe : le détail de l’offre (prix, durée) s’affiche avant validation."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    Button {
                        Task { await startCheckout() }
                    } label: {
                        Label("Souscrire ou réactiver (paiement Stripe)", systemImage: "creditcard.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)

                    Button {
                        Task { await refreshAfterPayment() }
                    } label: {
                        Label("J’ai finalisé le paiement — actualiser", systemImage: "arrow.clockwise.circle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .disabled(busy)

                    Button("Se déconnecter", role: .cancel) {
                        authService.logout()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        Button("Conditions d’utilisation") { legalSafariURL = LegalURLs.termsOfUse }
                        Button("Politique de confidentialité") { legalSafariURL = LegalURLs.privacyPolicy }
                    }
                    .font(.subheadline)
                }
                .padding(24)
            }
            .navigationTitle("MyFidpass Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
            .onChange(of: authService.hasActiveMerchantSubscription) { _, active in
                if active { dismiss() }
            }
            .overlay {
                if busy {
                    ProgressView()
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .sheet(isPresented: $showCheckout) {
                if let checkoutURL {
                    InAppSafariView(url: checkoutURL)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: Binding(
                get: { legalSafariURL != nil },
                set: { if !$0 { legalSafariURL = nil } }
            )) {
                if let url = legalSafariURL {
                    InAppSafariView(url: url)
                        .ignoresSafeArea()
                }
            }
            .alert("Information", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                if let message { Text(message) }
            }
        }
    }

    private func startCheckout() async {
        busy = true
        defer { busy = false }
        do {
            let r = try await APIClient.shared.request(.paymentCheckout(planId: "starter")) as CheckoutSessionResponse
            if let u = r.url, let url = URL(string: u) {
                checkoutURL = url
                showCheckout = true
            } else {
                message = "Paiement indisponible (Stripe non configuré)."
            }
        } catch {
            message = (error as? APIError)?.errorDescription ?? "Impossible d’ouvrir le paiement."
        }
    }

    private func refreshAfterPayment() async {
        busy = true
        defer { busy = false }
        await authService.refreshBusinessesIfNeeded()
        if authService.hasActiveMerchantSubscription {
            message = nil
        } else {
            message = "Aucun abonnement actif détecté. Si vous venez de payer, attendez quelques secondes puis réessayez."
        }
    }
}

#Preview {
    MerchantSubscriptionGateView()
        .environmentObject(AuthService())
}
