# RevenueCat + paywall App Store (MyFidpass)

Ce document complète le code : après avoir ouvert le projet dans **Xcode**, suis les étapes dans l’ordre.

## 1. Déjà fait dans le code

- Package Swift **RevenueCat** + **RevenueCatUI** (`purchases-ios-spm`).
- `Purchases.configure` au lancement (`RevenueCatBootstrap` / `myfidpassApp`).
- Identifiant RevenueCat utilisateur = `AuthStorage.userId` (API) sinon email.
- Entitlement attendu : **`myfidpass_premium`** (constant `RevenueCatConfig.premiumEntitlementId`).
- Feuille **`MerchantSubscriptionGateView`** : `CustomMerchantProPaywallView` (StoreKit) + abonnement Stripe côté site si besoin.
- Déblocage UI : abonnement Stripe (API) **ou** entitlement RevenueCat.
- Synchronisation API : `POST /api/auth/revenuecat-sync` (après achat) + voir [APP_STORE_IAP_TARIFICATION.md](APP_STORE_IAP_TARIFICATION.md).

## 2. À faire dans Xcode (obligatoire)

1. Ouvre **`myfidpass.xcodeproj`**.
2. Cible **myfidpass** → **Signing & Capabilities** → **+ Capability** → **In-App Purchase**.
3. **File → Packages** : vérifie que le package `https://github.com/RevenueCat/purchases-ios-spm.git` est résolu (premier build télécharge les binaires).
4. Configuration **Release** : dans `RevenueCatConfig.swift`, remplace `REPLACE_WITH_APPL_PUBLIC_KEY` par la clé publique **`appl_…`** (RevenueCat → **API keys** → app iOS).

## 3. App Store Connect (tarification cible)

Configure les **prix** et **offres intro** sur les abonnements (France / EUR : **49,99 €/mois**, **399,00 €/an** ; **3 j d’essai** sur les deux ; 1,00 € 1ʳ mois côté **mensuel** si ta fiche l’autorise). Voir **[APP_STORE_IAP_TARIFICATION.md](APP_STORE_IAP_TARIFICATION.md)**.

## 4. RevenueCat (dashboard)

1. **Project** : même bundle id que l’app (`com.myfidpass`).
2. **API keys** : colle la clé **test** (déjà en DEBUG) ou **public** `appl_` en prod.
3. **Apps** → lier l’app iOS + App Store Connect (clé API App Store Connect ou clé P8 selon flux RC).
4. **Products** : ajoute le produit StoreKit (même identifiant qu’App Store Connect).
5. **Entitlements** : crée un entitlement nommé exactement **`myfidpass_premium`** et attache-lui le produit d’abonnement.
6. **Offerings** : offering **default** avec **deux** packages : `monthly` + `annual` (prix affichés par l’app).
7. L’app utilise le paywall **maison** `CustomMerchantProPaywallView` (texte = StoreKit), pas l’éditeur RC obligatoire.

## 5. Tests

- **Simulateur** : **StoreKit Configuration** (fichier `.storekit`) optionnel pour achats fictifs.
- **Sandbox** : compte testeur App Store (Réglages → App Store → Compte sandbox).
- Après achat, vérifie dans RC **Customers** que l’utilisateur a l’entitlement actif.

## 6. Backend / API (fidelity)

- **RevenueCat REST** (clé `sk_` sur Railway) : `GET /v1/subscribers/{app_user_id}` pour lire l’entitlement.
- **Webhook** `POST /api/webhooks/revenuecat` (Authorization = `REVENUECAT_WEBHOOK_AUTHORIZATION` sur Railway) : met à jour la table `subscriptions` avec le sentinel `revenuecat_iap` (sans remplacer un vrai abonnement Stripe `sub_…`).
- L’app appelle en plus `POST /api/auth/revenuecat-sync` juste après achat / restauration pour que `GET /api/auth/me` reflète tout de suite l’IAP côté API (403 en phase post-achat en moins d’attente).

## 7. Fichiers utiles

| Fichier | Rôle |
|--------|------|
| `Services/RevenueCat/RevenueCatConfig.swift` | Clés API + id entitlement |
| `Services/RevenueCat/RevenueCatBootstrap.swift` | Configure une seule fois |
| `Services/RevenueCat/RevenueCatSubscriptionState.swift` | Delegate, `logIn`, entitlement |
| `Views/Auth/MerchantSubscriptionGateView.swift` | Paywall + lien Stripe |
