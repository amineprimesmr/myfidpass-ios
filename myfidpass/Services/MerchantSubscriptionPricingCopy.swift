//
//  MerchantSubscriptionPricingCopy.swift
//  myfidpass
//
//  Textes marketing du paywall commerçant (achat in-app App Store — prix affichés par StoreKit).
//

import Foundation

enum MerchantSubscriptionPricingCopy {
    // MARK: Paywall Bevel

    static let paywallBevelTitle = "Combien de commerces avez-vous ?"

    static let paywallContinueCta = "Essayer pour 1€"

    /// Code offre App Store Connect (custom) — secours si la signature serveur est indisponible : menu ⋯ → Code promo Apple.
    static let appleCustomOfferCode = "MYFID1EURO"

    static let paywallAppleOfferCodeFallbackNote =
        "Si l’App Store affiche le plein tarif, ouvrez le menu ⋯ → Code promo Apple et saisissez MYFID1EURO."

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
    static let purchaseCta = "Essayer pour 1€"

    /// Pastille flottante au-dessus du tab bar (Accueil / Notifs / Statistiques).
    static let subscribeFloatingPillCta = "Essayer 1 mois à 1€"

    /// Bouton déverrouillage sections Pro (statistiques commerçant).
    static let statsProUnlockCta = "Débloquer les données du commerce avec Pro"

    /// Bouton déverrouillage flyer de jeu (hub + feuille post-carte).
    static let flyerProUnlockCta = "Débloquer le flyer de jeu avec Pro"
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
