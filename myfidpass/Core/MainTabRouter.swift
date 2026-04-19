//
//  MainTabRouter.swift
//  myfidpass
//
//  Onglets : 0 Accueil, 1 Campagnes (Notifs), 2 Commerce.
//

import Combine
import SwiftUI
import UIKit

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    /// L’utilisateur voit l’écran Flyer (hub) dans Commerce : masquer la pastille d’essai au-dessus de la tab bar.
    @Published var isMerchantFlyerHubPresented: Bool = false
    /// Onglet Accueil : aucune navigation poussée (membres, Ma carte, etc.).
    @Published var isDashboardAtRoot: Bool = true
    /// Écran « Ma carte » visible (Accueil ou hub programme) : masquer la pastille d’essai au-dessus de la tab bar.
    @Published var isMyCardScreenPresented: Bool = false

    /// Anciennement : bloquait la sortie de l’onglet Commerce sans flyer enregistré — désactivé (navigation libre).
    @Published var merchantFlyerCreationRequired: Bool = false
    /// Incrémenté quand l’utilisateur tente de quitter Commerce sans flyer — secousse du CTA « Créer mon flyer de jeu ».
    @Published private(set) var flyerPrimaryCTAShakeToken: Int = 0

    /// Slug commerce courant (pour lecture cache).
    private static func currentSlug() -> String? {
        let s = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    /// Conservé pour compat ; ne force plus aucun onglet ni blocage flyer.
    func applyInitialCommerceTabIfFlyerMissing() {
        merchantFlyerCreationRequired = false
    }

    /// Conservé pour compat ; le commerce n’est plus verrouillé tant que le flyer n’existe pas.
    func syncFlyerOnboardingRequirement(flyerRegistered: Bool, hasBusinessSlug: Bool) {
        _ = flyerRegistered
        _ = hasBusinessSlug
        merchantFlyerCreationRequired = false
    }

    func triggerFlyerPrimaryCTAShake() {
        flyerPrimaryCTAShakeToken += 1
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
    }

    /// Secousse d’attention automatique (toutes les 5 s sur l’onglet Commerce sans flyer) — sans haptique
    /// pour ne pas être intrusive.
    func triggerFlyerPrimaryCTAAutoShake() {
        flyerPrimaryCTAShakeToken += 1
    }
}
