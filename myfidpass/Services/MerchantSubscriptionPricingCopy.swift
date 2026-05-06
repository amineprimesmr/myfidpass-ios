//
//  MerchantSubscriptionPricingCopy.swift
//  myfidpass
//
//  Textes marketing du paywall commerçant — **même discours que pour un seul commerce** (un seul tarif affiché,
//  pas de paliers 2 / 3+ dans la frise). Les montants définitifs sont sur Stripe Checkout.
//

import Foundation

enum MerchantSubscriptionPricingCopy {
    // MARK: En-tête paywall (`CustomMerchantProPaywallView`)

    static let paywallTitle = "MyFidpass Pro"

    static let paywallTitleLine1 = "COMMENCEZ À FIDÉLISER POUR 1 €"

    /// Vide = pas de sous-titre sous le titre du paywall.
    static let paywallUnderTitleLine = ""

    // MARK: Anciennes clés (non utilisées par le paywall actuel ; conservées pour recherche / cohérence éventuelle)

    static let appAccessStepTitle = "Pilotez votre commerce"

    static let appAccessStepDetail = "Carte fidélité, campagnes et statistiques depuis l’app."

    static let monthlyAfterTrialTitle = "Abonnement mensuel"

    static let annualAfterTrialTitle = "Abonnement annuel"

    static let monthlySubscriptionStepDetail = "Renouvellement mensuel sur l’App Store."

    static let annualSubscriptionStepDetail = "Renouvellement annuel sur l’App Store."

    static let purchaseCta = "Commencer pour 1 €"

    // MARK: - Frise verticale (paywall, ton « 1 commerce »)

    static let paywallTimelineCompletedTitle = "Inscription terminée"
    static let paywallTimelineCompletedDetail = "Votre compte commerçant est prêt."

    /// Titre unique de l’étape 2 (frise) : contexte + montant sur une seule ligne. Sous-titre + date : `CustomMerchantProPaywallView`.
    static let paywallTimelineTodayStepTitle = "Aujourd’hui : Payez 1 €"

    static let paywallTimelineReminderTitle = "Boostez votre commerce"
    /// Sous-titre étape 3 de la frise (1 phrase).
    static let paywallTimelineReminderDetail = "Récompenses et notifications illimitées pour fidéliser vos clients."

    static let paywallTimelineEndTitle = "Toujours sans engagement"
    /// Repli si aucun prix StoreKit n’est encore résolu (`CustomMerchantProPaywallView` préfère une ligne dynamique).
    static let paywallTimelineEndDetailFallback = "Sans engagement, annulable à tout moment depuis Réglages ou l’App Store."
}
