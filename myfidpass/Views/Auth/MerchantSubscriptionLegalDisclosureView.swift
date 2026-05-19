//
//  MerchantSubscriptionLegalDisclosureView.swift
//  myfidpass
//
//  Informations obligatoires pour abonnements auto-renouvelables (Guideline 3.1.2).
//  Affiché sur le paywall natif (WKWebView) en complément de myfidpass.fr/paiement.
//

import SwiftUI

/// Texte d’abonnement aligné sur la page Stripe `/paiement` (mensuel / annuel).
struct MerchantSubscriptionLegalDisclosureView: View {
    /// `nil` = afficher les deux forfaits (paywall WebView).
    var isAnnualPlan: Bool? = nil
    var compact: Bool = false

    @State private var safariURL: URL?

    private var subscriptionTitle: String {
        MerchantSubscriptionPricingCopy.paywallTitle
    }

    private var subscriptionLength: String {
        switch isAnnualPlan {
        case .some(true):
            return "Abonnement annuel (renouvellement automatique chaque année)"
        case .some(false):
            return "Abonnement mensuel (renouvellement automatique chaque mois)"
        case .none:
            return "Abonnement mensuel ou annuel (renouvellement automatique selon le forfait choisi)"
        }
    }

    private var subscriptionPriceLine: String {
        switch isAnnualPlan {
        case .some(true):
            return "1 € le premier mois, puis 399 € / an (soit 34 € / mois en moyenne). Sans engagement."
        case .some(false):
            return "1 € le premier mois, puis 49,99 € / mois. Sans engagement."
        case .none:
            return "Mensuel : 1 € le 1er mois, puis 49,99 € / mois. Annuel : 1 € le 1er mois, puis 399 € / an. Sans engagement."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(subscriptionTitle)
                .font(.system(size: compact ? 11 : 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
            Text(subscriptionLength)
                .font(.system(size: compact ? 10 : 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
            Text(subscriptionPriceLine)
                .font(.system(size: compact ? 10 : 11))
                .foregroundStyle(.white.opacity(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Text("Le paiement est traité de façon sécurisée via Stripe. L’abonnement se renouvelle automatiquement jusqu’à résiliation depuis l’app (Réglages) ou sur myfidpass.fr.")
                .font(.system(size: compact ? 9 : 10))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
            legalLinks
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 12 : 16)
        .padding(.vertical, compact ? 10 : 12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Button("Politique de confidentialité") {
                safariURL = LegalURLs.privacyPolicy
            }
            Text("|")
                .foregroundStyle(.white.opacity(0.35))
            Button("Conditions d’utilisation (CGU)") {
                safariURL = LegalURLs.termsOfUse
            }
        }
        .font(.system(size: compact ? 10 : 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
        .tint(.white.opacity(0.85))
    }
}
