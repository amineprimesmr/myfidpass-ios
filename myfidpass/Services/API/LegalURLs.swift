//
//  LegalURLs.swift
//  myfidpass
//
//  Liens juridiques (site vitrine). URLs canoniques **www** (HTTP 200) — requis App Store Connect 3.1.2.
//

import Foundation

enum LegalURLs {
    /// Site vitrine (création de compte, marketing).
    static let website = URL(string: "https://www.myfidpass.fr")!

    /// Conditions d’utilisation / EULA (Guideline 3.1.2 — métadonnées + binaire).
    static let termsOfUse = URL(string: "https://www.myfidpass.fr/cgu")!

    /// Politique de confidentialité (champ dédié App Store Connect).
    static let privacyPolicy = URL(string: "https://www.myfidpass.fr/politique-confidentialite")!

    /// EULA standard Apple (si vous choisissez « Contrat de licence standard » dans Connect).
    static let appleStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// Chaînes pour affichage sur le paywall (revue Apple).
    static let termsOfUseDisplayString = "https://www.myfidpass.fr/cgu"
    static let privacyPolicyDisplayString = "https://www.myfidpass.fr/politique-confidentialite"

    /// Suppression de compte (page vitrine / App Store).
    static let deleteAccountInfo = URL(string: "https://www.myfidpass.fr/supprimer-compte")!

    /// Aide / FAQ (site vitrine).
    static let helpCenter = URL(string: "https://www.myfidpass.fr")!

    /// Contact support commerçants (ouvre le client mail).
    static let supportMail = URL(string: "mailto:contact@myfidpass.fr?subject=Support%20MyFidpass%20%28app%20commer%C3%A7ant%29")!

    /// Connexion au tableau de bord web (gestion abonnement, facturation).
    static let dashboardLogin = URL(string: "https://www.myfidpass.fr")!

    /// Page web d’abonnement (essai → paiement Stripe). Même origine que la redirection canonique Vercel (www).
    static let merchantSubscriptionCheckout = URL(string: "https://www.myfidpass.fr/abonnement")!

    /// Payment Link Stripe (1er mois 1 €, code MYFID1EURO) — ouverture externe / fallback.
    static func merchantSaasProPaymentPage(prefilledEmail: String? = nil) -> URL {
        merchantStripeSubscriptionPaymentLinkWithPromo(prefilledEmail: prefilledEmail)
    }

    /// Checkout intégré myfidpass.fr (`app_embed=1`) — 1 € 1er mois via coupons Stripe (tous comptes, hors limite Apple).
    static func merchantEmbeddedSaasPaymentPage(
        prefilledEmail: String? = nil,
        planAnnual: Bool = false,
        commerceSlots: Int = 1
    ) -> URL {
        var components = URLComponents(string: "https://www.myfidpass.fr/paiement")!
        let slots = min(5, max(1, commerceSlots))
        var items: [URLQueryItem] = [
            URLQueryItem(name: "app_embed", value: "1"),
            URLQueryItem(name: "plan", value: planAnnual ? "annual" : "monthly"),
            URLQueryItem(name: "commerce_slots", value: String(slots)),
        ]
        let e = prefilledEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !e.isEmpty {
            items.append(URLQueryItem(name: "prefilled_email", value: e))
        }
        components.queryItems = items
        return components.url ?? URL(string: "https://www.myfidpass.fr/paiement?app_embed=1")!
    }

    /// Payment Link abonnement (fallback) — code **MYFID1EURO** aligné 1er mois à 1 € sur le mensuel.
    static func merchantStripeSubscriptionPaymentLinkWithPromo(prefilledEmail: String?) -> URL {
        var components = URLComponents(string: "https://buy.stripe.com/7sYcN53Z72N88et4Cr8Zq01")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "prefilled_promo_code", value: "MYFID1EURO"),
        ]
        let e = prefilledEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !e.isEmpty {
            items.append(URLQueryItem(name: "prefilled_email", value: e))
        }
        components.queryItems = items
        return components.url
            ?? URL(string: "https://buy.stripe.com/7sYcN53Z72N88et4Cr8Zq01?prefilled_promo_code=MYFID1EURO")!
    }

    /// Espace web : ouvre le paiement Stripe du pack créations flyer (connecté, 1er commerce).
    static let merchantCreationCredits = URL(string: "https://www.myfidpass.fr/app?acheter_credits_flyer=1")!

    /// Carte Google Maps (recherche d’un lieu).
    static let googleMaps = URL(string: "https://www.google.com/maps")!

    /// Outil officiel Google pour afficher le Place ID d’un point sur la carte.
    static let googlePlaceIdFinder = URL(
        string: "https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder"
    )!

    /// Page publique où le client ajoute la carte (même URL que le SaaS « Lien et QR code »).
    static func fidelityCardPage(slug: String) -> URL? {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }
        return URL(string: "https://www.myfidpass.fr/fidelity/\(s)?qr=1")
    }
}
