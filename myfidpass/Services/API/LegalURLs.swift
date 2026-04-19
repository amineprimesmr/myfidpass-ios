//
//  LegalURLs.swift
//  myfidpass
//
//  Liens juridiques (site vitrine). À aligner sur les pages réelles de myfidpass.fr.
//

import Foundation

enum LegalURLs {
    /// Site vitrine (création de compte, marketing).
    static let website = URL(string: "https://myfidpass.fr")!

    /// Conditions d’utilisation (obligatoire pour la revue Apple si abonnement / compte).
    static let termsOfUse = URL(string: "https://myfidpass.fr/cgu")!

    /// Politique de confidentialité.
    static let privacyPolicy = URL(string: "https://myfidpass.fr/confidentialite")!

    /// Aide / FAQ (site vitrine).
    static let helpCenter = URL(string: "https://myfidpass.fr")!

    /// Contact support commerçants (ouvre le client mail).
    static let supportMail = URL(string: "mailto:contact@myfidpass.fr?subject=Support%20MyFidpass%20%28app%20commer%C3%A7ant%29")!

    /// Connexion au tableau de bord web (gestion abonnement, facturation).
    static let dashboardLogin = URL(string: "https://myfidpass.fr")!

    /// Page web d’abonnement (essai → paiement Stripe). Même origine que la redirection canonique Vercel (www) pour le localStorage WKWebView.
    static let merchantSubscriptionCheckout = URL(string: "https://www.myfidpass.fr/abonnement")!

    /// Payment Link abonnement avec code promo **MYFID1EURO** (1er mois à 1 €). Pastille essai dans l’app.
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
    static let merchantCreationCredits = URL(string: "https://myfidpass.fr/app?acheter_credits_flyer=1")!

    /// Carte Google Maps (recherche d’un lieu).
    static let googleMaps = URL(string: "https://www.google.com/maps")!

    /// Outil officiel Google pour afficher le Place ID d’un point sur la carte (documentation Maps).
    static let googlePlaceIdFinder = URL(
        string: "https://developers.google.com/maps/documentation/javascript/examples/places-placeid-finder"
    )!

    /// Page publique où le client ajoute la carte (même URL que le SaaS « Lien et QR code »).
    static func fidelityCardPage(slug: String) -> URL? {
        let s = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return nil }
        return URL(string: "https://myfidpass.fr/fidelity/\(s)")
    }
}
