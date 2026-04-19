# Refonte structurelle — production & synchronisation SaaS

Ce document fixe la **vision**, le **plan par phases** et les **garde-fous** pour une base iOS + API **maintenable** et **alignée** sur le SaaS (dossier `fidelity` sur le Bureau). Il complète `SYNC_ET_AUTH.md`, `FEATURES_APP_SAAS.md` et `CONTRAT_API_LOGICIEL.md`.

---

## 1. Principes (non négociables)

| Principe | Implémentation actuelle / cible |
|----------|----------------------------------|
| **Source de vérité métier** | API Railway (`api.myfidpass.fr`) — pas Core Data seul. |
| **SaaS ↔ app** | Pas de temps réel WebSocket : **pull** après actions + **retour au premier plan** + **refresh** manuel. |
| **Après mutation** | Toujours enchaîner : `PATCH`/`POST` réussi → **re-sync** (`syncAfterServerMutation()` ou `syncIfNeeded(force: true)`). |
| **Conflits visuels (logos)** | Règles `lastLogoUploadAt` / merge documentées dans `SyncService` — ne pas les casser sans test PassKit. |
| **Périmètre produit** | Tout le SaaS n’a pas d’équivalent in-app (flyer canvas complet, jeux avancés, etc.) : **documenter** plutôt que « simuler » la synchro. |

---

## 2. Livré dans le code (fondations sync)

- **`SyncService.invalidateSyncThrottle()`** — permet d’autoriser un pull immédiat sans attendre 15 s (usage optionnel).
- **`SyncService.syncAfterServerMutation()`** — alias clair : full sync forcée après enregistrement serveur.
- **`ContentView`** — au passage de l’app en **`.active`**, sync forcée **debounced (~6 s)** pour rapprocher l’état du SaaS sans spammer l’API.
- **`MyCardView` / `EstablishmentEditorView`** — après `PATCH` réussi + rechargement local, appel à **`syncAfterServerMutation()`** pour mettre à jour membres / transactions / Core Data.

---

## 3. Phases de refonte (roadmap)

### Phase A — Cohérence API (terminée en partie, à maintenir)

- Vérifier que **chaque** `APIEndpoint` utilisé correspond à une route **réelle** dans `fidelity/backend` (ex. `/notifications/*` **sans** `dashboard` au milieu).
- Tests manuels : modifier sur le web → rouvrir l’app → **≤ 1 s** après retour premier plan (hors charge réseau).

### Phase B — Une seule politique « après sauvegarde » (en cours)

- **Fait** : après mutations, utiliser `syncAfterServerMutation()` sur accueil (scan, notify), scanner, fiche membre (catégories), catégories, liste membres (pull), campagnes (après envoi), périmètre (après save + chargement sans slug).
- **Déjà en place** : Ma carte, fiche commerce, périmètre (équivalent), SaaS hub import.
- **Optionnel** : modifier SwiftUI `onServerWrite { }` pour les futurs écrans.

### Phase C — Réduction des surprises UX

- **Indicateur global** : `syncService.isSyncing` déjà publié — envisager un **banner discret** ou pull-to-refresh systématique sur les listes critiques (membres, activité).
- **Throttle 15 s** : conservé pour les appels *passifs* ; les chemins **utilisateur** (sauvegarde, foreground) passent en **force** ou invalident le throttle.

### Phase D — Nettoyage code mort (prudent)

- **Ne pas supprimer** des dossiers de démo **référencés** par le `.xcodeproj` sans retirer les références.
- Inventorier les `case` d’`APIEndpoint` **jamais appelés** : soit les **brancher** (jeux, tickets…) si produit, soit les **retirer** dans une PR dédiée avec tests.

### Phase E — Fidelity (SaaS) en parallèle

- Même contrat **snake_case** sur `GET/PATCH .../dashboard/settings`.
- Éviter les champs **web-only** non documentés pour l’app ; ajouter au contrat dans `CONTRAT_API_LOGICIEL.md` si besoin.

### Phase F — Qualité production

- Suite de tests UI **manuelle** par rôle (commerçant) : auth → carte → scan → membre → campagne → retour web → retour app.
- Monitoring : erreurs 401 (session), 5xx, temps de sync (logs Xcode / App Store Connect).

---

## 4. Ce qu’on ne fait pas dans cette refonte (hors scope)

- Réécriture complète UI « from scratch » sans besoin métier.
- Synchronisation **temps réel** type WebSocket (coût / complexité) — à valider produit plus tard.
- Suppression agressive de fonctionnalités sans validation utilisateur.

---

## 5. Prochaine action recommandée

1. Parcourir les vues listées dans `grep patchDashboardSettings|updateLocationSettings|createCategory` et cocher **sync post-mutation**.
2. Mettre à jour **`FEATURES_APP_SAAS.md`** avec une colonne « Web only » pour les écrans non couverts par l’app.
3. CI : au minimum **build** Xcode sur branche principale avant release.

---

## Android (`/android` dans le dépôt)

- **Chemin** : `…/myfidpass/android` (même repo que l’app iOS).
- **Rafraîchissement SaaS → app** : `MainTabsScreen` appelle `dashboardRepository.refreshAll(slug)` au **ON_RESUME** (debounce 6 s), comme le retour au premier plan iOS.
- **Après sauvegarde carte** : `MyCardScreen` enchaîne `refreshAll` après `updateSettings` réussi.
- **Après points membre** : `MemberDetailScreen` appelle `refreshAll` (pas seulement `loadMembers`).

**Campagnes Android** : `ApiService` + `NotificationDtos` + `DashboardRepository` + onglet **Campagnes** (`CampaignsScreen`), alignés sur `GET/POST .../notifications/*` (même base que l’iOS).

---

*Dernière mise à jour : indicateur sync iOS, harmonisation `syncAfterServerMutation`, alignement Android (resume + refresh).*
