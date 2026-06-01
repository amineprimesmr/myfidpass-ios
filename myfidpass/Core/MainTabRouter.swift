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
    /// Onglet Accueil : aucune navigation poussée (membres, Ma carte, etc.).
    @Published var isDashboardAtRoot: Bool = true
    /// Menu latéral Accueil ouvert (réglages, flyer, etc.).
    @Published var isHomeSidebarExpanded: Bool = false
    /// Onglet Statistiques : écran principal sans sheet / sous-page.
    @Published var isCommerceStatsAtRoot: Bool = true
    /// Accueil en mode configuration initiale : masque certains CTA globaux (ex. pastille essai 1 €).
    @Published var isDashboardSetupMode: Bool = false
    /// Vrai une fois que l'écran Accueil a explicitement publié son mode setup/non-setup.
    @Published var hasResolvedDashboardSetupMode: Bool = false
    /// Demande d’ouverture du menu latéral Accueil depuis un autre onglet.
    @Published var pendingHomeSidebarOpen = false
}
