//
//  EngagementTemporaryVisibility.swift
//  myfidpass
//
//  Masquage temporaire UI « Avis & réseaux » — repasser `hideSecondaryReviewNetworks` à `false` pour tout réafficher.
//

import Foundation

enum EngagementTemporaryVisibility {
    /// Masquage temporaire global de toute UI « Avis Google » en attente d'autorisation Google.
    static let hideGoogleReviewsUI = true

    static let hideSecondaryReviewNetworks = true

    static let hiddenSocialMetricChannelIds: Set<String> = [
        "twitter_follow", "snapchat_follow", "linkedin_follow",
        "trustpilot_review", "tripadvisor_review",
    ]

    /// Onglet Commerce : uniquement mission Google via **Place ID public** (pas Instagram, TikTok, YouTube, etc.).
    static let commerceEngagementGoogleOnly = true

    /// Feuille « Avis Google » : connexion OAuth **Google Business** (aperçu avis API).
    /// Réactivée le 2026-04-17 après approbation Google (brand verification, projet myfidpass 298717960459).
    /// Remettre à `true` uniquement si Google suspend à nouveau le scope `business.manage`.
    static let hideGoogleBusinessOAuthInReviewsSheet = false
}
