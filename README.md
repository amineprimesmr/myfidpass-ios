# MyFidpass — monorepo mobile

Applications natives **iOS** (SwiftUI) et **Android** (Jetpack Compose) pour commerçants MyFidpass.

| Dossier | Rôle |
|---------|------|
| `myfidpass/` | App iOS + extensions (Live Activity, push) |
| `android/` | App Android |
| `Docs/` | Contrat API, OpenAPI core, parité |
| `scripts/` | Build store, split DTOs, setup prod Android |
| `PlayStoreMetadata/` / `AppStoreMetadata/` | Fiches stores |

## Backend (hors ce dépôt)

API et web client : **`~/Desktop/fidelity`** → `api.myfidpass.fr` + `myfidpass.fr`.

- Commerçant : **apps iOS/Android uniquement** (dashboard web `/app` gelé côté SaaS).
- Client final : `myfidpass.fr/fidelity/{slug}`.

## Lancer

**iOS** : ouvrir `myfidpass.xcodeproj` dans Xcode → Run.

**Android** :
```bash
cd android && ./gradlew :app:installDebug
```

**Tests Android** :
```bash
cd android && ./gradlew :app:testDebugUnitTest
```

## Architecture mobile (état actuel)

- **iOS** : SwiftUI + services (`Services/`) + Core Data offline partiel.
- **Android** : `data/` + `domain/` (use cases) + `ui/` Compose ; Room cache ; DI via `AppContainer` (migration Hilt prévue).
- **Contrat API** : `myfidpass/Docs/CONTRAT_API_LOGICIEL.md` + `Docs/openapi/myfidpass-core.yaml`.

## Release Android

```bash
cd android && ./gradlew :app:bundleRelease
# → app/build/outputs/bundle/release/app-release.aab
```

Keystore : `scripts/setup-android-prod.sh`
