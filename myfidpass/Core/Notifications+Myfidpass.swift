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
    /// Déconnexion / suppression de compte : purge caches UI (activité accueil) et ignore les syncs encore en file.
    static let myfidpassLocalSessionDidEnd = Notification.Name("myfidpass.localSessionDidEnd")
    /// HTTP 403 `subscription_required` : rafraîchir l’état abonnement (bandeau freemium / message métier).
    static let myfidpassSubscriptionRequiredByAPI = Notification.Name("myfidpass.subscriptionRequiredByAPI")
    /// Après `POST /api/auth/refresh` : mise à jour optionnelle de `has_active_subscription`.
    static let myfidpassMerchantSubscriptionFromRefresh = Notification.Name("myfidpass.merchantSubscriptionFromRefresh")
    /// Fusion `SyncService` → `viewContext` terminée (membres + transactions importés). Rafraîchit le fil « Dernières transactions » (Core Data) sans passer par `DataService.save()`.
    static let myfidpassMerchantCoreDataDidMergeFromSync = Notification.Name("myfidpass.merchantCoreDataDidMergeFromSync")
    /// Bascule Points ↔ Tampons enregistrée : l’accueil doit vider « Dernières transactions ».
    static let myfidpassProgramModeDidSwitch = Notification.Name("myfidpass.programModeDidSwitch")
    /// Connexion OAuth réseau (Meta / YouTube / TikTok) réussie : le serveur a mis à jour les liens missions — recharger le profil établissement.
    static let myfidpassEngagementOAuthDidComplete = Notification.Name("myfidpass.engagementOAuthDidComplete")
    /// PATCH social-missions enregistré — rafraîchir les @ sur les boutons réseaux (Commerce / stats).
    static let myfidpassSocialMissionsDidSave = Notification.Name("myfidpass.socialMissionsDidSave")
    /// Challenge pronostics activé/désactivé — rafraîchir l’aperçu flyer (bandeau Coupe du monde).
    static let myfidpassMatchPredictionsConfigDidSave = Notification.Name("myfidpass.matchPredictionsConfigDidSave")
    /// Universal Link https://myfidpass.fr/oauth/… relayé en myfidpass:// (object : URL).
    static let myfidpassOAuthUniversalLinkRelay = Notification.Name("myfidpass.oauthUniversalLinkRelay")
    /// Fichier image carte réécrit sous `Documents/CardLogos/…` (même chemin relatif) — recharger les `AsyncLocalFileImage`.
    static let myfidpassCardLocalAssetFileWritten = Notification.Name("myfidpass.cardLocalAssetFileWritten")
    /// Snapshot d’aperçu carte (UserDefaults) mis à jour — rafraîchir l’aperçu Accueil / listes qui lisent `CardPreviewDisplaySnapshotStore`.
    static let myfidpassCardPreviewDisplayDidChange = Notification.Name("myfidpass.cardPreviewDisplayDidChange")
    /// Ouvre la feuille d’abonnement Stripe (pastille essai au-dessus du tab bar).
    static let myfidpassOpenMerchantSubscriptionSheet = Notification.Name("myfidpass.openMerchantSubscriptionSheet")
    /// Rétrocompat : ancienne pastille « essai → Safari Stripe » — ouvre le paywall (Stripe Checkout).
    static let myfidpassOpenMerchantTrialStripePaymentLink = Notification.Name("myfidpass.openMerchantTrialStripePaymentLink")
    /// Bascule sur l’onglet Accueil et ouvre le menu latéral (Compte / Paramètres).
    static let myfidpassOpenGlobalSettingsSheet = Notification.Name("myfidpass.openGlobalSettingsSheet")
    /// Ferme le menu latéral Accueil — utilisé depuis la checklist lancement.
    static let myfidpassCloseGlobalSettingsSheet = Notification.Name("myfidpass.closeGlobalSettingsSheet")
    /// Ouvre « Ma carte » en plein écran depuis l’accueil (même flux que la tuile d’aperçu).
    static let myfidpassOpenHomeMyCardFullScreen = Notification.Name("myfidpass.openHomeMyCardFullScreen")
    /// Checklist lancement (web + iOS) : accusé flyer affiché ou contexte rechargé — rafraîchir pastille essai.
    static let myfidpassMerchantSetupProgressUpdated = Notification.Name("myfidpass.merchantSetupProgressUpdated")
    /// `SyncService` a terminé l’hydratation flyer (GET …/dashboard/flyer ou fallback settings) pour le commerce courant.
    static let myfidpassFlyerCacheDidHydrateFromSync = Notification.Name("myfidpass.flyerCacheDidHydrateFromSync")
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
    /// Transaction App Store synchronisée en arrière-plan (code promo, renouvellement) — rafraîchir le paywall ouvert.
    static let myfidpassAppleStoreTransactionSynced = Notification.Name("myfidpass.appleStoreTransactionSynced")
    /// Demande d'ouverture de la feuille de configuration Google (depuis le hub « non connecté »).
    static let myfidpassOpenGoogleBusinessSetupSheet = Notification.Name("myfidpass.openGoogleBusinessSetupSheet")
    /// Adopter le matchedPlaceId renvoyé par l'OAuth comme placeId configuré du commerce (userInfo["placeId"]: String).
    static let myfidpassAdoptMatchedGooglePlaceId = Notification.Name("myfidpass.adoptMatchedGooglePlaceId")
    /// Admin plateforme : bascule sur l’UI commerçant pour piloter un commerce.
    static let myfidpassAdminPilotDidStart = Notification.Name("myfidpass.adminPilotDidStart")
    /// Ouvre la feuille « Ajouter un commerce » (recherche Google Places → création).
    static let myfidpassOpenAddCommerceSheet = Notification.Name("myfidpass.openAddCommerceSheet")
    /// Ouvre la recherche client globale (top bar Accueil / Notifs / Stats).
    static let myfidpassOpenMemberSearch = Notification.Name("myfidpass.openMemberSearch")
    /// Commerce actif changé (`userInfo["slug"]`) — réinitialiser les écrans liés à la carte / branding.
    static let myfidpassActiveBusinessDidChange = Notification.Name("myfidpass.activeBusinessDidChange")
    /// Campagne notif envoyée ou livraison mise à jour — rafraîchir l’historique Statistiques.
    static let myfidpassMerchantNotificationCampaignSent = Notification.Name("myfidpass.merchantNotificationCampaignSent")
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
    /// Avec `myfidpassOpenMerchantSubscriptionSheet` : forfait cible (1–5 commerces) pour le paywall IAP.
    static let requiredCommerceSlots = "requiredCommerceSlots"
    /// `true` si l’utilisateur tente d’ajouter un commerce (quota plein).
    static let addingAnotherCommerce = "addingAnotherCommerce"
    /// Nom du prochain commerce (recherche Google en cours dans « Ajouter un commerce »).
    static let pendingCommerceName = "pendingCommerceName"
    /// Slug commerce concerné par une campagne notif.
    static let businessSlug = "businessSlug"
    /// `batch_id` serveur (historique stats).
    static let notificationBatchId = "notificationBatchId"
}

extension NotificationCenter {
    /// Ouvre le paywall avec le palier IAP calculé (quota / ajout commerce).
    func postOpenMerchantSubscription(
        usedBusinesses: Int,
        allowedBusinesses: Int,
        addingAnotherCommerce: Bool,
        pendingCommerceName: String? = nil
    ) {
        let n = MerchantAppleSubscriptionProducts.slotsToPurchase(
            usedBusinesses: usedBusinesses,
            allowedBusinesses: allowedBusinesses,
            addingAnotherCommerce: addingAnotherCommerce
        )
        var userInfo: [String: Any] = [
            MyfidpassNotificationUserInfoKey.requiredCommerceSlots: n,
            MyfidpassNotificationUserInfoKey.addingAnotherCommerce: addingAnotherCommerce,
        ]
        if let pendingCommerceName {
            let trimmed = pendingCommerceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                userInfo[MyfidpassNotificationUserInfoKey.pendingCommerceName] = trimmed
            }
        }
        post(
            name: .myfidpassOpenMerchantSubscriptionSheet,
            object: nil,
            userInfo: userInfo
        )
    }

    /// Paywall avec palier déduit du quota actuel (stats, teaser Pro, etc.).
    func postOpenMerchantSubscriptionFromSession(
        usedBusinesses: Int,
        allowedBusinesses: Int,
        hasActiveSubscription: Bool
    ) {
        let adding = hasActiveSubscription && usedBusinesses >= max(1, allowedBusinesses)
        postOpenMerchantSubscription(
            usedBusinesses: usedBusinesses,
            allowedBusinesses: allowedBusinesses,
            addingAnotherCommerce: adding
        )
    }
}
