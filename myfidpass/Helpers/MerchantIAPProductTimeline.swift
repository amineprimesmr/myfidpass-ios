//
//  MerchantIAPProductTimeline.swift
//  myfidpass
//
//  Texte du paywall dérivé de StoreKit (essai, intro « pay as you go », tarif de base) —
//  les durées / montants doivent correspondre à App Store Connect + RevenueCat.
//

import Foundation
import RevenueCat

/// Données affichées dans la frise d’abonnement pour **un** `StoreProduct` (mensuel ou annuel).
enum MerchantIAPProductTimeline {
    // MARK: - Titre marketing (bannière)

    static func mainHeadlineEmphasis(uppercased: Bool, product: StoreProduct) -> String {
        guard let d = product.introductoryDiscount else {
            return uppercased ? "ABONNEMENT" : "Abonnement"
        }
        switch d.paymentMode {
        case .freeTrial:
            let s = freeTrialEmphasis(period: d.subscriptionPeriod)
            return uppercased ? s : s
        case .payAsYouGo, .payUpFront:
            let base = d.localizedPriceString + (uppercased ? " · 1ʳᵉ PÉRIODE" : " · 1ʳᵉ période")
            return uppercased ? base.uppercased() : base
        default:
            return uppercased ? "ABONNEMENT" : "Abonnement"
        }
    }

    private static func freeTrialEmphasis(period: SubscriptionPeriod) -> String {
        if period.unit == .month, period.value == 1 { return "1 MOIS OFFERT" }
        switch (period.unit, period.value) {
        case (.day, 7): return "7 JOURS OFFERTS"
        case (.day, 3): return "3 JOURS OFFERTS"
        case (.day, 14): return "14 JOURS OFFERTS"
        case (.week, 1): return "1 SEMAINE OFFERTE"
        case (.day, 1): return "1 JOUR OFFERT"
        case (.day, let d) where d > 1: return "\(d) JOURS OFFERTS"
        default:
            return "ESSAI · \(frenchPeriodPhrase(period).uppercased())"
        }
    }

    // MARK: - Frise (étape 1)

    static func step1Title(product: StoreProduct) -> String {
        if let d = product.introductoryDiscount, d.paymentMode == .freeTrial {
            return "Aujourd’hui – Essai gratuit de \(frenchPeriodPhrase(d.subscriptionPeriod))"
        }
        if let d = product.introductoryDiscount, d.paymentMode == .payAsYouGo {
            return "Aujourd’hui – \(payAsYouGoFirstPeriodPhrase(d))"
        }
        if let d = product.introductoryDiscount, d.paymentMode == .payUpFront {
            return "Aujourd’hui – \(d.localizedPriceString) (offre d’accès)"
        }
        return "Aujourd’hui – Accès PRO immédiat"
    }

    static let step1SubtitleDefault = "Explorez toutes les fonctionnalités immédiatement."

    // MARK: - Helpers (format)

    private static func payAsYouGoFirstPeriodPhrase(_ d: StoreProductDiscount) -> String {
        if d.subscriptionPeriod.unit == .month, d.numberOfPeriods == 1 {
            return "Premier mois à \(d.localizedPriceString)"
        }
        if d.subscriptionPeriod.unit == .year, d.numberOfPeriods == 1 {
            return "Première année à \(d.localizedPriceString)"
        }
        return "\(d.localizedPriceString) / \(frenchShortPeriod(d.subscriptionPeriod)) · \(d.numberOfPeriods) période(s) au tarif introductif"
    }

    private static func frenchShortPeriod(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .day: return period.value == 1 ? "jour" : "\(period.value) jours"
        case .week: return period.value == 1 ? "semaine" : "\(period.value) semaines"
        case .month: return period.value == 1 ? "mois" : "\(period.value) mois"
        case .year: return period.value == 1 ? "an" : "\(period.value) ans"
        @unknown default: return "période"
        }
    }

    static func frenchPeriodPhrase(_ period: SubscriptionPeriod) -> String {
        switch period.unit {
        case .day:
            return period.value == 1 ? "1 jour" : "\(period.value) jours"
        case .week:
            return period.value == 1 ? "1 semaine" : "\(period.value) semaines"
        case .month:
            return period.value == 1 ? "1 mois" : "\(period.value) mois"
        case .year:
            return period.value == 1 ? "1 an" : "\(period.value) ans"
        @unknown default:
            return "1 mois"
        }
    }

    // MARK: - Paywall (CustomMerchantPro) : texte = StoreKit, pas seulement la copie fixe
    //
    // Rappel App Store Connect (bloquant si mal placé) :
    // - « 1,00 € le 1er mois » pour un **nouvel** abonné sur la feuille d’achat standard = **Offres d’introduction** (intro offer), pas l’onglet **Offres promotionnelles** (ID type `premois` → autre flux, souvent : signature côté serveur / cible abonnés existants, pas le panier StoreKit de base de `purchase(package:)`).

    /// Ligne 2 du titre (après l’accès 3 j) : s’appuie sur l’`introductoryDiscount` tel que StoreKit l’expose pour le mensuel.
    static func paywallSecondHeadlineLine(monthly: StoreProduct?, annual: StoreProduct?) -> String {
        let annualStr = annual?.localizedPriceString ?? "399,00 € / an"
        if let m = monthly,
           let d = m.introductoryDiscount,
           isPayAsYouGoFirstMonth(discount: d) {
            return "Puis, à la souscription : \(d.localizedPriceString) le 1er mois, ou \(annualStr) (annuel) — le même enchaînement que sur la feuille Apple, si l’abonnement et le compte y sont éligibles."
        }
        if let monthly, monthly.introductoryDiscount == nil {
            return "Puis, à la souscription : forfait selon l’App Store. Si 1,00 € n’y apparaît pas, StoreKit n’expose pas d’offre introductive sur l’identifiant mensuel (détail à l’étape 2), ou le compte de test n’y a pas accès (Sandbox)."
        }
        if monthly == nil {
            return "Puis, à la souscription : forfait affiché sur l’App Store."
        }
        return "Puis, à la souscription : mensuel ou annuel, selon la feuille de commande (montant fixé par l’App Store, pas par l’appli seule)."
    }

    static func paywallStep2Title(monthly: StoreProduct?, annual: StoreProduct?, selectedIsAnnual: Bool) -> String {
        if selectedIsAnnual {
            guard let p = annual else { return "À l’abonnement – 399,00 € / an (≈ 33,25 €/mois) — payé en une fois" }
            if let d = p.introductoryDiscount, d.paymentMode == .payAsYouGo, d.subscriptionPeriod.unit == .year, d.numberOfPeriods == 1 {
                return "À l’abonnement – \(d.localizedPriceString) la 1ʳᵉ année, puis le tarif en vigueur (App Store)"
            }
            return "À l’abonnement – \(p.localizedPriceString) / an (annuel, selon la feuille Apple)"
        }
        guard let p = monthly else { return "À l’abonnement – 1,00 € le 1er mois, puis 49,99 €/mois (sans engagement)" }
        if let d = p.introductoryDiscount, isPayAsYouGoFirstMonth(discount: d) {
            return "À l’abonnement – \(d.localizedPriceString) le 1er mois, puis \(p.localizedPriceString)/mois (sans engagement)"
        }
        return "À l’abonnement – \(p.localizedPriceString)/mois (sans engagement)"
    }

    static func paywallStep2Detail(monthly: StoreProduct?, annual: StoreProduct?, selectedIsAnnual: Bool) -> String? {
        if selectedIsAnnual {
            return "Le débit annuel s’aligne sur la feuille système au moment de la commande (montant, devise, prélèvement d’un coup selon l’abonnement)."
        }
        guard let m = monthly else { return "La feuille d’achat Apple a priorité sur l’appli. Si le prix diffère, vérifier App Store Connect, RevenueCat et l’abonné simulé." }
        if m.introductoryDiscount == nil {
            return "Aucun tarif intro côté Store sur ce product ID. Dans App Store Connect, ajoute une offre d’abonnement introductif (1er mois, paiement au fil, 1,00 €) sur l’abonnement mensuel — mêmes pays et même identifiant que l’abonnement exposé par RevenueCat. L’offre d’« introduction » (pas seulement une offre promotionnelle isolée) alimente la feuille d’achat standard."
        }
        return "Si l’appli indique 1,00 €, mais 49,99 € seuls sur la feuille : compte de test (Sandbox) souvent déjà abonné à ce groupe, ou intro déjà consommée. Essaie un compte de test neuf. Aucun appel purchase() n’impose seul le 1,00 € : c’est l’éligibilité côté Apple. Si 49,99 partout, c’est qu’il n’y a pas d’offre reconnue pour ce compte."
    }

    private static func isPayAsYouGoFirstMonth(discount: StoreProductDiscount) -> Bool {
        guard discount.paymentMode == .payAsYouGo else { return false }
        return discount.subscriptionPeriod.unit == .month && discount.subscriptionPeriod.value == 1 && discount.numberOfPeriods == 1
    }
}
