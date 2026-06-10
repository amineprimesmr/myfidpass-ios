//
//  MerchantSubscriptionLegalDisclosureView.swift
//  myfidpass
//
//  Informations obligatoires pour abonnements auto-renouvelables (Guideline 3.1.2).
//

import SwiftUI

/// Informations obligatoires abonnement auto-renouvelable (Guideline 3.1.2) — App Store.
struct MerchantSubscriptionLegalDisclosureView: View {
    /// `nil` = afficher les deux forfaits (paywall WebView).
    var isAnnualPlan: Bool? = nil
    var compact: Bool = false
    /// Prix affiché par StoreKit (optionnel) — sinon texte indicatif aligné Connect.
    var storeKitPriceLine: String? = nil

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
            return "Abonnement mensuel (renouvellement automatique chaque mois)"
        }
    }

    private var subscriptionPriceLine: String {
        if let storeKitPriceLine, !storeKitPriceLine.isEmpty {
            switch isAnnualPlan {
            case .some(true):
                return "1 € le premier mois, puis \(storeKitPriceLine) / an via l’App Store. Sans engagement."
            case .some(false):
                return "1 € le premier mois, puis \(storeKitPriceLine) / mois via l’App Store. Sans engagement."
            case .none:
                return "1 € le premier mois, puis tarif mensuel affiché par l’App Store selon le nombre de commerces. Sans engagement."
            }
        }
        switch isAnnualPlan {
        case .some(true):
            return "1 € le premier mois, puis 399 € / an (soit 34 € / mois en moyenne). Sans engagement."
        case .some(false):
            return "1 € le premier mois, puis 49,99 € / mois. Sans engagement."
        case .none:
            return "1 € le premier mois, puis 49,99 € / mois (1 commerce) ou tarif affiché selon le palier multi-commerces. Sans engagement."
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
            Text("Le paiement est traité par Apple (achat in-app). L’abonnement se renouvelle automatiquement jusqu’à résiliation dans Réglages → identifiant Apple → Abonnements.")
                .font(.system(size: compact ? 9 : 10))
                .foregroundStyle(.white.opacity(0.45))
                .fixedSize(horizontal: false, vertical: true)
            legalLinks
            functionalURLRows
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
            Button("Conditions d’utilisation (EULA)") {
                safariURL = LegalURLs.termsOfUse
            }
        }
        .font(.system(size: compact ? 10 : 11, weight: .medium))
        .foregroundStyle(.white.opacity(0.72))
        .tint(.white.opacity(0.85))
    }

    /// Liens URL explicites (Guideline 3.1.2 — fonctionnels pour la revue).
    private var functionalURLRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            legalURLButton(
                title: "Privacy Policy",
                url: LegalURLs.privacyPolicy,
                display: LegalURLs.privacyPolicyDisplayString
            )
            legalURLButton(
                title: "Terms of Use (EULA)",
                url: LegalURLs.termsOfUse,
                display: LegalURLs.termsOfUseDisplayString
            )
        }
        .padding(.top, 2)
    }

    private func legalURLButton(title: String, url: URL, display: String) -> some View {
        Button {
            safariURL = url
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: compact ? 9 : 10, weight: .semibold))
                Text(display)
                    .font(.system(size: compact ? 8 : 9))
                    .underline()
            }
            .foregroundStyle(.white.opacity(0.55))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
