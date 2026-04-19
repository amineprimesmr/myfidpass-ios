# Application Android MyFidpass

**Emplacement du projet :** `myfidpass/android` à la racine du dépôt (ex. `~/Desktop/myfidpass/android`). Il n’a pas été supprimé.

## Stratégie

L’application Android reprend **les mêmes fonctionnalités** que l’app iOS (tableau de bord, scanner, Ma Carte, profil) en s’appuyant sur **la même API** (api.myfidpass.fr). Aucun changement backend nécessaire : auth, membres, scan, paramètres carte, etc. sont déjà exposés en REST.

- **Techno** : Kotlin + Jetpack Compose (UI moderne, recommandée par Google).
- **Architecture** : Clean Architecture en 3 couches (data / domain / ui) pour un code maintenable et testable.
- **Différence principale** : sur iOS le pass est au format **Apple Wallet** (.pkpass). Sur Android on affiche la **carte dans l’app** (aperçu + QR code) et, si tu le souhaites plus tard, on pourra ajouter **Google Wallet** (API dédiée, à intégrer côté backend).

---

## Architecture (structure du projet)

```
app/
├── src/main/java/fr/myfidpass/
│   ├── data/              # Données (API, préférences)
│   │   ├── api/           # Retrofit, DTOs, endpoints
│   │   ├── repository/    # AuthRepository, DashboardRepository, etc.
│   │   └── local/         # Token, préférences (DataStore ou SharedPreferences)
│   ├── domain/            # Logique métier (optionnel au début)
│   │   └── model/         # Modèles métier
│   └── ui/                # Écrans et navigation
│       ├── theme/         # Couleurs, typo, thème Material 3
│       ├── navigation/    # Routes, NavHost
│       ├── screens/       # Écrans Compose (Login, Dashboard, Scanner, MaCarte, Profile)
│       └── components/    # Composants réutilisables
├── build.gradle.kts
└── AndroidManifest.xml
```

- **data** : appels HTTP (Retrofit), stockage token (DataStore), DTOs alignés sur l’API.
- **domain** : modèles et règles métier (on peut commencer simple et enrichir).
- **ui** : Compose (Material 3), ViewModels, navigation par onglets (comme l’iOS).

---

## Parité fonctionnelle avec l’iOS

| Fonctionnalité        | iOS | Android |
|-----------------------|-----|--------|
| Connexion (email)     | ✅  | ✅     |
| Connexion Google      | ✅  | ✅     |
| Connexion Apple       | ✅  | — (optionnel) |
| Tableau de bord       | ✅  | ✅     |
| Liste membres         | ✅  | ✅     |
| Scanner QR / ajout pts| ✅  | ✅     |
| Ma Carte (design, aperçu) | ✅ | ✅ |
| Carte dans Wallet     | Apple Wallet | App + QR (Google Wallet possible plus tard) |
| Profil / paramètres   | ✅  | ✅     |
| Campagnes (segments, envoi) | ✅  | ✅ (onglet dédié) |
| Notifications push    | ✅  | ✅ (FCM) |

---

## Performances et bonnes pratiques

- **Compilation** : Kotlin 2.x, AGP 8.x, minSdk 26, targetSdk 34.
- **Réseau** : Retrofit + OkHttp (timeouts, logging en debug).
- **Async** : Coroutines + Flow (pas de callbacks).
- **UI** : Compose uniquement (pas de XML pour les écrans), Material 3, thème clair/sombre.
- **Sécurité** : token en DataStore (chiffré si besoin), pas de clés en clair dans le code.
- **Play Store** : respect des politiques (permissions justifiées, politique de confidentialité, etc.).

---

## Comment lancer le projet

1. Ouvrir le dossier **android** dans Android Studio (Hedgehog ou plus récent) via **File → Open** (choisir le dossier `android`).
2. Laisser Android Studio **synchroniser Gradle** (téléchargement du wrapper et des dépendances au besoin).
3. Brancher un appareil ou lancer un émulateur (API 26+).
4. Lancer l’app avec **Run** ▶️. En ligne de commande : `cd android && ./gradlew installDebug` (après une première sync dans Android Studio pour générer le wrapper).

La **base URL API** est configurée dans `BuildConfig` / `ApiConfig` (par défaut `https://api.myfidpass.fr`). En debug tu peux la surcharger si besoin.

---

## Suite du développement

Une fois la base en place (auth, navigation, appels API) :

1. **Écrans** : compléter chaque onglet (Dashboard, Scanner, Ma Carte, Profil) en reprenant les écrans iOS.
2. **Google Wallet** : si tu veux la carte dans Google Wallet, il faudra intégrer l’API Google Wallet et, côté backend, générer les passes au format Google (en plus du .pkpass Apple).
3. **Notifications** : Firebase Cloud Messaging (FCM) pour les push, comme côté serveur déjà prévu.
4. **Publication** : compte Play Console, signature de l’app, fiche store (texte, captures), politique de confidentialité.

Ce document sera tenu à jour au fur et à mesure de l’avancement du projet Android.
