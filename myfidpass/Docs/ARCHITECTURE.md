# Architecture MyFidPass – App commerçant

Organisation du projet, flux de données et bonnes pratiques pour la production.

---

## Structure des dossiers

```
myfidpass/
├── Core/                 # État global, configuration
│   └── AppState.swift    # Erreurs globales, bannière
├── Services/
│   ├── API/              # Réseau
│   │   ├── APIClient.swift
│   │   ├── APIConfig.swift
│   │   ├── APIEndpoint.swift
│   │   ├── APIDTOs.swift
│   │   └── APIError.swift
│   ├── Auth/
│   │   ├── AuthService.swift
│   │   └── AuthStorage.swift
│   ├── Notifications/
│   │   └── NotificationsService.swift  # Push, token APNs
│   ├── DataService.swift               # Core Data (CRUD)
│   └── SyncService.swift               # Sync API → Core Data
├── Views/
│   ├── Auth/             # Onboarding, login, signup redirect
│   ├── Dashboard/        # Tableau de bord, stats, membres
│   ├── Profile/          # Profil commerçant
│   ├── Scanner/          # Scan QR, enregistrement passage
│   ├── MyCard/           # Aperçu / personnalisation carte
│   ├── RootView.swift
│   └── MainTabView.swift
├── Theme/
│   └── AppTheme.swift
├── Docs/
│   ├── ARCHITECTURE.md
│   ├── CONTRAT_API_LOGICIEL.md
│   ├── ETAT_DES_LIEUX_ET_PLAN.md
│   └── SYNC_ET_AUTH.md
├── AppDelegate.swift     # Push notifications (token, delegate)
├── myfidpassApp.swift    # Point d’entrée, injection env
└── ContentView.swift     # Contenu principal (tabs)
```

---

## Flux de données

1. **Authentification**  
   `AuthService` appelle l’API (login / Apple / Google). Succès → token + slug business stockés dans `AuthStorage`, écran `.authenticated`.

2. **Synchronisation**  
   `SyncService.syncIfNeeded()` : `GET /api/auth/me` puis pour le business courant `settings`, `stats`, `members`, `transactions`. Fusion dans Core Data via `mergeIntoCoreData`. Les vues lisent Core Data via `DataService`.

3. **Scan**  
   `ScannerView` envoie le code QR à `POST /api/businesses/:slug/integration/scan`. Succès → overlay, puis `syncIfNeeded()` pour rafraîchir membres et stats.

4. **Notifications**  
   Après connexion, `NotificationsService.requestPermissionAndRegister()`. Le token APNs est envoyé à `POST /api/device/register`. L’app affiche les notifications (foreground/background) via `AppDelegate` + `UNUserNotificationCenterDelegate`.

5. **Erreurs**  
   `AppState.showError(_:)` affiche une bannière en haut. Les vues peuvent aussi utiliser des alertes locales (ex. code non reconnu au scan).

---

## Rôles des services

| Service | Rôle |
|--------|------|
| **AppState** | Erreur globale (bannière), état partagé |
| **AuthService** | Login, Apple, Google, écrans auth, logout |
| **AuthStorage** | UserDefaults : token, email, slug, provider |
| **APIClient** | Requêtes HTTP, Bearer, décodage, gestion 401/404 |
| **SyncService** | Pull API → Core Data, `isSyncing`, `lastError` |
| **DataService** | CRUD Core Data (Business, CardTemplate, ClientCard, Stamp) |
| **NotificationsService** | Permission, enregistrement push, envoi token au backend |

---

## Bonnes pratiques

- **Environment** : `authService`, `syncService`, `appState`, `managedObjectContext` injectés au niveau `myfidpassApp` / `RootView`.
- **Refresh** : Dashboard et Profil utilisent `.refreshable { await syncService.syncIfNeeded() }`.
- **Chargement** : Indicateurs (ProgressView) pendant sync et pendant la requête de scan.
- **Production** : `APIConfig.baseURL` = `https://api.myfidpass.fr` ; en DEBUG, override possible via `MYFIDPASS_API_URL`. Création de compte uniquement sur myfidpass.fr ; login uniquement si le compte existe côté backend.
- **Push notifications** : Dans Xcode, activer la capacité **Push Notifications** (Signing & Capabilities). Le fichier `myfidpass.entitlements` contient déjà `aps-environment` (development ; passer à `production` pour la release App Store).
