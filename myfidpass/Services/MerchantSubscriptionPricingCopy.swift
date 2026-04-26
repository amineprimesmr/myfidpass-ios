//
//  MerchantSubscriptionPricingCopy.swift
//  myfidpass
//
//  Texte marketing des forfaits commerçant — aligné site (Stripe) + App Store / RevenueCat.
//  L’exécution des montants côté App Store = App Store Connect (une offre intro par produit : voir Docs).
//

import Foundation

enum MerchantSubscriptionPricingCopy {
    // MARK: Frise & paywall (coordonné avec myfidpass.fr /abonnement)
    //
    // Les « 3 j » = accès Pro géré sur le compte (API), **sans** essai d’abonnement Apple.
    // Le prélèvement App Store n’intervient qu’à la souscription (1,00 € 1er mois ou 399,00 € / an selon le forfait).

    /// Ligne 1 + ligne 2 marketing par défaut (l’écran `CustomMerchantProPaywallView` remplace la ligne 2 par `MerchantIAPProductTimeline.paywallSecondHeadlineLine` dès que StoreKit a chargé l’abonnement).
    static let paywallTitle = "3 j d’utilisation de l’app en accès Pro, sans abonnement.\nPuis, à la souscription : 1,00 € le 1er mois ou 399,00 € / an."

    static let paywallTitleLine1 = "3 j d’utilisation de l’app en accès Pro, sans abonnement."

    static let appAccessStepTitle = "Dès l’inscription – 3 j d’accès Pro (hors abonnement App Store)"

    static let appAccessStepDetail = "C’est géré sur ton compte : pas de prélèvement Apple pendant ces 3 j."

    static let monthlyAfterTrialTitle = "À l’abonnement – 1,00 € le 1er mois, puis 49,99 €/mois (sans engagement)"

    static let annualAfterTrialTitle = "À l’abonnement – 399,00 € / an (≈ 33,25 €/mois) — payé en une fois"

    static let monthlySubscriptionStepDetail = "C’est ici qu’intervient l’App Store dès la validation (1,00 € le 1er mois si offre appliquée, puis 49,99 €/mois)."

    static let annualSubscriptionStepDetail = "C’est ici qu’intervient l’App Store dès la validation (montant annuel d’un coup, selon la feuille de commande)."

    static let purchaseCta = "S’abonner"
}
