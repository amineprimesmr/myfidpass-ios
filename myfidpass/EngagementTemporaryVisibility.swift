//
//  EngagementTemporaryVisibility.swift
//  myfidpass
//
//  Masquage temporaire UI « Avis & réseaux » — repasser `hideSecondaryReviewNetworks` à `false` pour tout réafficher.
//

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

}
