# Application Android MyFidpass

**Emplacement :** `myfidpass/android` à la racine du dépôt.

## Stratégie

Parité fonctionnelle avec l’app iOS, même API (`https://api.myfidpass.fr`). Pas de backend dans ce dossier.

- **Techno** : Kotlin 2.x, Jetpack Compose, Material 3
- **Architecture réelle** (2026) :
  - `data/` — Retrofit, DTOs, repositories, Room + DataStore
  - `domain/` — use cases légers (`RefreshSessionUseCase`, `SyncDashboardUseCase`)
  - `ui/` — écrans Compose, ViewModels (partiels), navigation
  - `di/AppContainer` — service locator (migration Hilt en cours)
  - `services/` — sync, FCM, version check

> La couche `domain/` est **minimale** (pas de Clean Architecture complète). Voir `IosParityChecklist.kt` pour la parité produit.

## Offline

- **Room** (`myfidpass.db`) : membres + transactions + meta sync — **sans** `fallbackToDestructiveMigration` (via `DatabaseProvider`).
- **Session** : `SessionStore` chiffré.

## Lancer

1. Android Studio → Open → dossier `android`
2. Sync Gradle, émulateur API 26+
3. Run ▶️ ou `./gradlew :app:installDebug`

Package debug : `fr.myfidpass.debug` · release : `fr.myfidpass`.

## Tests

```bash
cd android && ./gradlew :app:testDebugUnitTest
```

Cibles : `JwtAccessExpiryTest`, `RefreshTokenCoordinatorTest` (+ extension progressive).

## Release Play Store

```bash
./scripts/setup-android-prod.sh   # keystore + SHA Firebase
cd android && ./gradlew :app:bundleRelease
```

Incrémenter `versionCode` / `versionName` dans `app/build.gradle.kts` à chaque upload.

## Parité iOS

Source de vérité checklist : `android/.../ui/navigation/IosParityChecklist.kt`  
Doc historique : `Docs/ANDROID_IOS_PARITY.md`
