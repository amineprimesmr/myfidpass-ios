//
//  MerchantSubscriptionPricingCopy.swift
//  myfidpass
//
//  Textes marketing du paywall commerçant (achat in-app App Store — prix affichés par StoreKit).
//

import Foundation

enum MerchantSubscriptionPricingCopy {
    // MARK: Paywall Bevel

    static let paywallBevelTitle = "Prenez le contrôle de votre fidélité avec MyFidpass"

    static let paywallContinueCta = "Continuer"

    /// Au-dessus des cartes Mensuel / Annuel.
    static let paywallPricingIntroLine = "Premier mois à 1€, puis…"

    /// Sous le CTA quand le 1 € passe par Stripe (compte Apple déjà éligible à l’intro IAP ou forfait sans intro StoreKit).
    static let paywallStripeFirstMonthNote =
        "Premier mois à 1 € via paiement sécurisé Stripe (carte ou Apple Pay), puis le tarif choisi."

    /// Sous le bouton Continuer (mis en avant).
    static let paywallNoCommitmentHighlight = "Sans engagement"

    static let paywallMonthlyFallbackPrice = "49,99 €"
    static let paywallAnnualFallbackPrice = "399 €"

    // MARK: Legacy (autres écrans)

    static let paywallTitle = "MyFidpass Pro"
    static let paywallTitleLine1 = "COMMENCEZ À FIDÉLISER"
    static let paywallTitleLine2 = "POUR 1 €"
    static let paywallUnderTitleLine = ""
    static let appAccessStepTitle = "Pilotez votre commerce"
    static let appAccessStepDetail = "Carte fidélité, campagnes et statistiques depuis l’app."
    static let monthlyAfterTrialTitle = "Abonnement mensuel"
    static let annualAfterTrialTitle = "Abonnement annuel"
    static let monthlySubscriptionStepDetail = "Renouvellement mensuel via l’App Store."
    static let annualSubscriptionStepDetail = "Renouvellement annuel via l’App Store."
    static let purchaseCta = "Commencer pour 1 €"

    /// Pastille flottante au-dessus du tab bar (Accueil / Notifs / Statistiques).
    static let subscribeFloatingPillCta = "Essayer 1 mois à 1€"
    static let paywallNoCommitmentLine = "Sans engagement, annulable à tout moment"
    static let paywallAnnualUpsellCta = "Annuel −33 %"
    static let paywallMonthlySwitchBackCta = "Mensuel"
    static let paywallTimelineCompletedTitle = "Inscription terminée"
    static let paywallTimelineCompletedDetail = "Votre compte commerçant est prêt."
    static let paywallTimelineTodayStepTitle = "Aujourd’hui : Payez 1 €"
    static let paywallTimelineReminderTitle = "Boostez votre commerce"
    static let paywallTimelineReminderDetail = "Récompenses et notifications illimitées pour fidéliser vos clients."
    static let paywallTimelineEndTitle = "Sans engagement"
}
