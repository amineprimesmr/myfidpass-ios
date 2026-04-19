# RevenueCat + paywall App Store (MyFidpass)

Ce document complète le code : après avoir ouvert le projet dans **Xcode**, suis les étapes dans l’ordre.

## 1. Déjà fait dans le code

- Package Swift **RevenueCat** + **RevenueCatUI** (`purchases-ios-spm`).
- `Purchases.configure` au lancement (`RevenueCatBootstrap` / `myfidpassApp`).
- Identifiant RevenueCat utilisateur = `AuthStorage.userId` (API) sinon email.
- Entitlement attendu : **`myfidpass_premium`** (constant `RevenueCatConfig.premiumEntitlementId`).
- Feuille **`MerchantSubscriptionGateView`** : `PaywallView()` + lien secondaire Stripe.
- Déblocage UI : abonnement Stripe (API) **ou** entitlement RevenueCat.

## 2. À faire dans Xcode (obligatoire)

1. Ouvre **`myfidpass.xcodeproj`**.
2. Cible **myfidpass** → **Signing & Capabilities** → **+ Capability** → **In-App Purchase**.
3. **File → Packages** : vérifie que le package `https://github.com/RevenueCat/purchases-ios-spm.git` est résolu (premier build télécharge les binaires).
4. Configuration **Release** : dans `RevenueCatConfig.swift`, remplace `REPLACE_WITH_APPL_PUBLIC_KEY` par la clé publique **`appl_…`** (RevenueCat → **API keys** → app iOS).

## 3. App Store Connect

1. Crée un **abonnement auto-renouvelable** (ex. mensuel) pour l’app `com.myfidpass`.
2. Renseigne prix, localisations, review note.
3. Soumet les métadonnées IAP avec une version d’app (même binaire ou build suivant).

## 4. RevenueCat (dashboard)

1. **Project** : même bundle id que l’app (`com.myfidpass`).
2. **API keys** : colle la clé **test** (déjà en DEBUG) ou **public** `appl_` en prod.
3. **Apps** → lier l’app iOS + App Store Connect (clé API App Store Connect ou clé P8 selon flux RC).
4. **Products** : ajoute le produit StoreKit (même identifiant qu’App Store Connect).
5. **Entitlements** : crée un entitlement nommé exactement **`myfidpass_premium`** et attache-lui le produit d’abonnement.
6. **Offerings** : crée une offering **default** (ou marque « default ») contenant le package mensuel.
7. **Paywalls** : crée un paywall (éditeur RC) et associe-le à l’offering **default** — `PaywallView()` l’affiche sans code supplémentaire.

## 5. Tests

- **Simulateur** : **StoreKit Configuration** (fichier `.storekit`) optionnel pour achats fictifs.
- **Sandbox** : compte testeur App Store (Réglages → App Store → Compte sandbox).
- Après achat, vérifie dans RC **Customers** que l’utilisateur a l’entitlement actif.

## 6. Backend / API (important)

L’app débloque l’interface si **Stripe** (comme avant) **ou** si **RevenueCat** voit `myfidpass_premium` actif.

Les routes API qui renvoient `subscription_required` (403) ne savent pas encore lire RevenueCat. Pour un alignement total serveur + app, il faudra plus tard :

- un **webhook RevenueCat** vers ton backend pour recréer / synchroniser l’état d’abonnement, **ou**
- une vérification serveur des reçus Apple via RevenueCat REST API.

En attendant, un commerçant peut payer **en IAP** et utiliser l’app (UI), mais certaines actions strictement serveur peuvent encore exiger l’abo Stripe selon ta logique métier.

## 7. Fichiers utiles

| Fichier | Rôle |
|--------|------|
| `Services/RevenueCat/RevenueCatConfig.swift` | Clés API + id entitlement |
| `Services/RevenueCat/RevenueCatBootstrap.swift` | Configure une seule fois |
| `Services/RevenueCat/RevenueCatSubscriptionState.swift` | Delegate, `logIn`, entitlement |
| `Views/Auth/MerchantSubscriptionGateView.swift` | Paywall + lien Stripe |
