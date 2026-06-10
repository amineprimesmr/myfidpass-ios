//
//  MerchantSubscriptionGateView.swift
//  myfidpass
//
//  Paywall souscription : achats in-app App Store (StoreKit 2).
//

import SwiftUI
import UIKit

struct MerchantSubscriptionGateView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    /// `true` : paywall plein écran bloquant (fin d’inscription).
    /// `false` : feuille modale (sheet) — fermeture par glissement.
    var isMandatory: Bool = false
    /// Forfait IAP cible (1–5 commerces). `nil` = déduit du quota / nombre de commerces.
    var requiredCommerceSlots: Int? = nil
    /// Nom du commerce affiché sous le titre (post-inscription).
    var signupCommerceDisplayName: String? = nil
    /// Ouverture depuis « Ajouter un commerce » (quota plein).
    var addingAnotherCommerce: Bool = false
    /// Nom du futur commerce (établissement sélectionné avant paywall).
    var pendingCommerceName: String? = nil

    /// Croix affichée sur le paywall **obligatoire** (post-inscription) — jamais sur la sheet.
    private var showsPaywallCloseButton: Bool {
        isMandatory
    }

    var body: some View {
        CustomMerchantProPaywallView(
                allowsCloseButton: showsPaywallCloseButton,
                onCloseRequested: showsPaywallCloseButton ? { finishMerchantSubscriptionGate() } : nil,
                isSheetPresentation: !isMandatory,
                headerExtraTopPadding: isMandatory ? 10 : 4,
                closeButtonRevealDelay: (isMandatory && showsPaywallCloseButton) ? 0 : 5,
                requiredCommerceSlots: requiredCommerceSlots,
                signupCommerceDisplayName: signupCommerceDisplayName,
                addingAnotherCommerce: addingAnotherCommerce,
                pendingCommerceName: pendingCommerceName
            )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await APIClient.shared.ensureValidAccessToken()
            // Jamais de restore / reconcile Apple à l’ouverture : faux positif « déjà payé » + fermeture auto.
            await authService.refreshBusinessesIfNeeded(force: false)
        }
    }

    /// Ferme la feuille modale ou le paywall plein écran post-inscription.
    @MainActor
    private func finishMerchantSubscriptionGate() {
        if isMandatory {
            // Croix = quitter sans payer : jamais l’écran « Merci » (même si un abo Apple existe sur l’appareil).
            authService.finishSignupPaywallPhase(honorPaidThankYou: false)
            return
        }
        authService.clearMandatoryPaywallAfterSignupPending()
        dismiss()
    }
}

#Preview {
    Text("Paywall")
        .padding()
}
