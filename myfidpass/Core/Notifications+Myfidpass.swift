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
    /// Dernière synchro en erreur (hors annulation) : `userInfo["message"]` = texte localisé.
    static let myfidpassRemoteSyncDidFail = Notification.Name("myfidpass.remoteSyncDidFail")
    /// Fusion `SyncService` → `viewContext` terminée (membres + transactions importés). Rafraîchit le fil « Dernières transactions » (Core Data) sans passer par `DataService.save()`.
    static let myfidpassMerchantCoreDataDidMergeFromSync = Notification.Name("myfidpass.merchantCoreDataDidMergeFromSync")
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
    /// Rétrocompat : ancienne pastille « essai → Safari Stripe » — ouvre le paywall (Stripe Checkout).
    static let myfidpassOpenMerchantTrialStripePaymentLink = Notification.Name("myfidpass.openMerchantTrialStripePaymentLink")
    /// Ouvre directement la feuille Réglages globale (sans passer par l’onglet Commerce).
    static let myfidpassOpenGlobalSettingsSheet = Notification.Name("myfidpass.openGlobalSettingsSheet")
    /// Ferme la feuille globale (Compte / anciennement Réglages) — utilisé depuis la checklist lancement.
    static let myfidpassCloseGlobalSettingsSheet = Notification.Name("myfidpass.closeGlobalSettingsSheet")
    /// Ouvre « Ma carte » en plein écran depuis l’accueil (même flux que la tuile d’aperçu).
    static let myfidpassOpenHomeMyCardFullScreen = Notification.Name("myfidpass.openHomeMyCardFullScreen")
    /// Checklist lancement (web + iOS) : accusé flyer affiché ou contexte rechargé — rafraîchir pastille essai.
    static let myfidpassMerchantSetupProgressUpdated = Notification.Name("myfidpass.merchantSetupProgressUpdated")
    /// Bascule l’onglet principal sur **Accueil** (commerçant) — utilisé avant d’ouvrir le hub flyer depuis Réglages.
    static let myfidpassSelectMerchantHomeTab = Notification.Name("myfidpass.selectMerchantHomeTab")
    /// Ouvre l’éditeur / hub « Flyer & programme » (plein écran), écouté par `DashboardView`.
    /// `userInfo` optionnel : [`MyfidpassNotificationUserInfoKey.flyerHubStartCreateAssistant`: true] pour forcer l’assistant création (checklist étape 3).
    static let myfidpassOpenMerchantFlyerHub = Notification.Name("myfidpass.openMerchantFlyerHub")
    /// Ferme les réglages (sheet) et pousse l’écran Statistiques sur la navigation Commerce (pas une feuille).
    static let myfidpassOpenMerchantStatistics = Notification.Name("myfidpass.openMerchantStatistics")
    /// Onglet Commerce (statistiques) sélectionné dans le `TabView` — même idée que le rappel icône sur Campagnes.
    static let myfidpassCommerceStatsTabDidBecomeSelected = Notification.Name("myfidpass.commerceStatsTabDidBecomeSelected")
    /// Paiement abonnement finalisé dans la WebView (`myfidpass://subscription-paid`) : fermer la feuille et resynchroniser.
    static let myfidpassSubscriptionPaymentCompleted = Notification.Name("myfidpass.subscriptionPaymentCompleted")
    /// Demande d'ouverture de la feuille de configuration Google (depuis le hub « non connecté »).
    static let myfidpassOpenGoogleBusinessSetupSheet = Notification.Name("myfidpass.openGoogleBusinessSetupSheet")
    /// Adopter le matchedPlaceId renvoyé par l'OAuth comme placeId configuré du commerce (userInfo["placeId"]: String).
    static let myfidpassAdoptMatchedGooglePlaceId = Notification.Name("myfidpass.adoptMatchedGooglePlaceId")
    /// Relance le tutoriel depuis zéro (debug / tests uniquement).
    static let myfidpassResetTutorial = Notification.Name("myfidpass.resetTutorial")
    /// Ouvre la feuille « Ajouter un commerce » (recherche Google Places → création).
    static let myfidpassOpenAddCommerceSheet = Notification.Name("myfidpass.openAddCommerceSheet")
}

extension NotificationCenter {
    /// Poste la demande d'adoption avec le Place ID résolu par Google Business OAuth.
    func postAdoptMatchedGooglePlaceId(_ placeId: String) {
        post(name: .myfidpassAdoptMatchedGooglePlaceId, object: nil, userInfo: ["placeId": placeId])
    }
}

/// Clés `userInfo` pour les notifications internes.
enum MyfidpassNotificationUserInfoKey {
    /// Avec `myfidpassOpenMerchantFlyerHub` : `true` ouvre l’assistant **Créer le flyer** plutôt que l’aperçu « Votre flyer » (brouillon disque).
    static let flyerHubStartCreateAssistant = "flyerHubStartCreateAssistant"
}
