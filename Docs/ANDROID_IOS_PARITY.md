# Parité Android ↔ iOS MyFidpass (comparaison)

Document de référence pour aligner l’app **Android** sur l’app **iOS** (SwiftUI + Core Data + même API `fidelity`).

## 1. Navigation racine

| iOS | Android | Écart |
|-----|---------|--------|
| `RootView` : welcome / auth / chargement abo / `ContentView` ou `PlatformAdminRootView` | `MainActivity` + flux auth / paywall / `MainTabsScreen` | Android : pas d’équivalent **admin plateforme** en racine séparée comme iOS (`PlatformAdminRootView`) ; admin partiel via écran dans Commerce. |
| `MainTabView` : **Accueil**, **Notifs**, **Commerce** | `MainTabsScreen` : mêmes 3 onglets | OK (noms alignés). |

## 2. Onglet Accueil (tab 0)

| iOS `DashboardView` | Android `HomeTabNavHost` | Écart majeur |
|---------------------|--------------------------|--------------|
| Fond type **fintech** (`DashboardRevolutPalette`), scroll masqué, **pull to refresh** sync | Fond Material par défaut ; pas de sync Core Data | **Design** : iOS = carte glass + section transactions ; Android = liste stats + boutons. |
| **Aperçu carte** (`fintechHomeTopAndCard`) + stats intégrées | Stats en `StatCard` simples ; peu d’**aperçu carte** jusqu’ici | Android peut utiliser `WalletCardPreviewAndroid` + couleurs `BusinessSettingsResponse`. |
| **Dernières transactions** (flux Core Data, filtres `membersActivity`) | Pas de flux d’activité local | **Fonctionnel** : iOS lit le cache offline ; Android est surtout **API**. À rapprocher avec endpoint activité / historique ou message « à venir ». |
| Scanner QR → sheets **ajout points** / tampons / reçu | **Scan** → lookup → fiche membre | Parcours simplifié ; pas toutes les sheets iOS (montants, tampons, reçu). |
| **Notification rapide** bas + menu catégories (`CustomMenuView`) | Non présent sur l’accueil Android | iOS envoie notif depuis le dashboard ; Android = onglet **Notifs**. |
| Navigation : `membersActivity`, `myCard`, `memberDetail` | `MEMBERS`, `MYCARD`, `MEMBER_DETAIL`, `SCAN` | Couverture OK, profondeur d’écran différente. |

## 3. Onglet Notifs (tab 1)

| iOS `CampaignNotificationsView` | Android `CampaignsTabScreen` | Écart |
|-------------------------------|------------------------------|--------|
| Très gros écran : cartes, **carte Apple** preview, automation, segments, stats, cartes réseau, etc. | Formulaire envoi + stats/segments structurés + PassKit test | **Fonctionnel** : une partie des features iOS (multi-cartes, automation UI, règles) n’est pas encore portée. |
| Données `GET` segments + stats + settings | Idem via `DashboardRepository` | Données alignées ; **UI** a été rapprochée (libellés FR, blocs repliables). |

## 4. Onglet Commerce (tab 2)

| iOS `ProfileView` | Android `CommerceHubScreen` + `CommerceTabNavHost` | Écart majeur |
|-------------------|---------------------------------------------------|--------------|
| **Header noir** + avatar + nom + **QR page fidélité** + **réglages** | Était une liste simple | **Refonte** : structure proche (header + surface arrondie + « Votre commerce »). |
| Checklist **Flyer** (miniature, création, `MerchantProgramHubView`) | Hub **Programme & outils** + écrans partiels | iOS : WebView flyer, IA, flux complets ; Android : écrans utilitaires + **WebView** à renforcer. |
| Bloc **Avis Google** + `MerchantEstablishmentForm` | Pas de formulaire Google inline | **À faire** : lien SaaS ou écran dédié aligné API. |
| `SettingsView` sheet | `MerchantSettingsScreen` | À comparer champ par champ. |
| Stats | `StatsTransactionsScreen` | Vérifier parité avec `CommerceStatisticsDashboardView` iOS. |

## 5. Design system

| iOS | Android | Écart |
|-----|-----------|--------|
| `AppTheme` (couleurs, espacements, typo) | `MyfidpassTheme` + `Color.kt` / `Type.kt` | Primaire **bleu** aligné ; iOS utilise beaucoup **rounded design**, **glass**, **gradients**. |
| Cartes arrondies 22pt, `TopRoundedShape` | **Material 3** par défaut | **À rapprocher** : rayons 16–22dp, surfaces `surfaceVariant` cohérentes avec iOS. |

## 6. Données & offline

| iOS | Android |
|-----|-----------|
| **Core Data** + `SyncService` | **API + SessionStore** (pas de cache offline riche) |
| Activité / membres en local | Rechargement réseau |

Parité **100 %** impliquera soit **Room** + sync, soit **réduction du scope** « offline » sur Android.

## 7. Backlog priorisé (ordre suggéré)

1. **Accueil** : fond + **aperçu carte** + ligne « activité » (même vide / placeholder) + actions.
2. **Commerce** : header + checklist + navigation (fait en partie).
3. **Scan** : parité **flows** iOS (points, montant, tampon, reçu) selon API.
4. **Ma carte** : aligner `MyCardView` / éditeur couleurs.
5. **Notifs** : automation UI, prévisualisation Apple, segments sélectionnables à l’envoi.
6. **Onboarding** : `ProcessOnboarding` / premier lancement (gros chantier).
7. **Admin plateforme** : racine dédiée comme iOS si besoin produit.

---

*Dernière mise à jour : analyse repo `myfidpass` + `android`.*
