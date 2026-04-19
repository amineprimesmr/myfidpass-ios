//
//  Notifications+Myfidpass.swift
//  myfidpass
//

import Foundation

extension Notification.Name {
    /// Ouvre le scanner QR sur l’accueil (Dynamic Island / URL myfidpass://scan).
    static let myfidpassOpenHomeScanner = Notification.Name("myfidpass.openHomeScanner")
    /// JWT renouvelé (refresh) — renvoyer le device token au backend.
    static let myfidpassAuthTokensUpdated = Notification.Name("myfidpass.authTokensUpdated")
    /// Jetons invalides (session expirée, compte supprimé côté serveur / reset admin) : déconnexion complète locale.
    static let myfidpassSessionInvalidated = Notification.Name("myfidpass.sessionInvalidated")
    /// HTTP 403 `subscription_required` : rafraîchir l’état abonnement (bandeau freemium / message métier).
    static let myfidpassSubscriptionRequiredByAPI = Notification.Name("myfidpass.subscriptionRequiredByAPI")
    /// Après `POST /api/auth/refresh` : mise à jour optionnelle de `has_active_subscription`.
    static let myfidpassMerchantSubscriptionFromRefresh = Notification.Name("myfidpass.merchantSubscriptionFromRefresh")
    /// Accusé campagne : basculer sur l’onglet Campagnes.
    static let myfidpassOpenCampaignsTab = Notification.Name("myfidpass.openCampaignsTab")
    /// Sync API terminée (merge Core Data) : rafraîchir les listes qui dépendent de `DataService.updateTrigger`.
    static let myfidpassRemoteSyncDidMerge = Notification.Name("myfidpass.remoteSyncDidMerge")
    /// Connexion OAuth réseau (Meta / YouTube / TikTok) réussie : le serveur a mis à jour les liens missions — recharger le profil établissement.
    static let myfidpassEngagementOAuthDidComplete = Notification.Name("myfidpass.engagementOAuthDidComplete")
    /// Universal Link https://myfidpass.fr/oauth/… relayé en myfidpass:// (object : URL).
    static let myfidpassOAuthUniversalLinkRelay = Notification.Name("myfidpass.oauthUniversalLinkRelay")
    /// Fichier image carte réécrit sous `Documents/CardLogos/…` (même chemin relatif) — recharger les `AsyncLocalFileImage`.
    static let myfidpassCardLocalAssetFileWritten = Notification.Name("myfidpass.cardLocalAssetFileWritten")
    /// Snapshot d’aperçu carte (UserDefaults) mis à jour — rafraîchir l’aperçu Accueil / listes qui lisent `CardPreviewDisplaySnapshotStore`.
    static let myfidpassCardPreviewDisplayDidChange = Notification.Name("myfidpass.cardPreviewDisplayDidChange")
    /// Pousser « Ma carte » dans le hub programme (Flyer) lorsque la vue est montée ; le parcours principal passe par Commerce → navigation.
    static let myfidpassOpenProgramMyCard = Notification.Name("myfidpass.openProgramMyCard")
    /// Ouvre la feuille d’abonnement Stripe (pastille essai au-dessus du tab bar).
    static let myfidpassOpenMerchantSubscriptionSheet = Notification.Name("myfidpass.openMerchantSubscriptionSheet")
    /// Ouvre le lien de paiement Stripe promo 1 € (Safari intégré) — ex. depuis la pastille dans l’onglet Commerce.
    static let myfidpassOpenMerchantTrialStripePaymentLink = Notification.Name("myfidpass.openMerchantTrialStripePaymentLink")
    /// Ferme les réglages (sheet) et pousse l’écran Statistiques sur la navigation Commerce (pas une feuille).
    static let myfidpassOpenMerchantStatistics = Notification.Name("myfidpass.openMerchantStatistics")
    /// Paiement abonnement finalisé dans la WebView (`myfidpass://subscription-paid`) : fermer la feuille et resynchroniser.
    static let myfidpassSubscriptionPaymentCompleted = Notification.Name("myfidpass.subscriptionPaymentCompleted")
    /// Ouverture du hub Google Business (push nouvel avis).
    static let myfidpassOpenGoogleBusinessHub = Notification.Name("myfidpass.openGoogleBusinessHub")
    /// Demande d'ouverture de la feuille de configuration Google (depuis le hub « non connecté »).
    static let myfidpassOpenGoogleBusinessSetupSheet = Notification.Name("myfidpass.openGoogleBusinessSetupSheet")
}
