//
//  MainTabRouter.swift
//  myfidpass
//
//  Onglets : 0 Accueil, 1 Campagnes (Notifs), 2 Commerce.
//

import Combine
import SwiftUI

@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    /// Tutoriel : vrai pendant le pré-chargement des onglets + 1ʳᵉ capture — masque l'app et coupe animations / haptiques.
    @Published var isTutorialTabPriming: Bool = false
    /// Onglet Accueil : aucune navigation poussée (membres, Ma carte, etc.).
    @Published var isDashboardAtRoot: Bool = true
    /// Accueil en mode configuration initiale : masque certains CTA globaux (ex. pastille essai 1 €).
    @Published var isDashboardSetupMode: Bool = false
    /// Vrai une fois que l'écran Accueil a explicitement publié son mode setup/non-setup.
    @Published var hasResolvedDashboardSetupMode: Bool = false
}
