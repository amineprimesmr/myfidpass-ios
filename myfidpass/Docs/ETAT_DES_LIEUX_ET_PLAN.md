# MyFidPass – État des lieux & plan (le boss)

**Projet sur le Bureau :** `myfidpass` (c’est le projet Fidelity / MyFidPass).  
Il n’y a pas de dossier séparé « fidelity » ; tout est dans **myfidpass**.

---

## Ce qu’on fait (résumé)

**MyFidPass** = solution pour que les **commerces** proposent des **cartes de fidélité digitales** dans le wallet des clients.  
Tu as (ou auras) un **logiciel** (web/desktop) pour les commerçants. L’**app mobile** qu’on a construite est l’interface commerçant : connexion, dashboard, scan des cartes clients, personnalisation de la carte, profil.

---

## Ce qui est fait (déjà en place)

### 1. App mobile commerçant (iOS)

| Élément | Statut |
|--------|--------|
| **Onboarding / Auth** | Écran « Déjà client ? » → Se connecter / Créer un compte (ouvre myfidpass.fr) |
| **Connexion** | Email + mot de passe, Sign in with Apple. Vérification « compte existant dans le logiciel » (stub : refuse tout sauf `test@myfidpass.fr` en DEBUG) |
| **Création de compte** | Pas in-app : bouton ouvre **myfidpass.fr** |
| **Google** | Bouton présent, message « Bientôt disponible » (SDK non intégré) |
| **Dashboard** | Stats (cartes actives, scans du jour), activité récente |
| **Scanner** | Scan QR des cartes fidélité clients, ajout de tampon |
| **Ma Carte** | Aperçu + personnalisation (nom, nombre de tampons, couleurs) |
| **Profil** | Infos commerce (nom, email, tél) + déconnexion |
| **Design** | Thème (AppTheme), couleurs, espacements |

### 2. Données (Core Data)

- **Business** : commerce (nom, email, téléphone, logo).
- **CardTemplate** : modèle de carte (nom, tampons requis, couleurs).
- **ClientCard** : carte d’un client (lien template, QR, nombre de tampons).
- **Stamp** : un tampon (date, note).
- Relations avec inverses OK.

### 3. Services (prêts à brancher)

- **AuthService** : login / Apple / (Google stub), vérification « compte dans le logiciel », déconnexion.
- **AuthStorage** : persistance session (UserDefaults).
- **DataService** : CRUD Business, CardTemplate, ClientCard, Stamp + stats.
- **SyncService** : stub pour sync future avec le logiciel (TODOs).

---

## Production & sync (fait)

- **APIConfig** : URL de base `https://api.myfidpass.fr` (modifiable dans `APIConfig.swift` ou via variable d’env `MYFIDPASS_API_URL` en DEBUG).
- **APIClient** : appels HTTP avec Bearer token, gestion 401/404/5xx, décodage JSON (dates ISO8601).
- **Auth** : `login` et `loginWithApple` appellent l’API ; token stocké ; bypass uniquement en DEBUG pour `test@myfidpass.fr` si réseau en erreur.
- **SyncService** : `syncIfNeeded()` (GET /merchant/sync → merge en Core Data), `pushLocalChanges()` (POST des nouveaux tampons). Sync au lancement (ContentView), push après chaque scan.
- **Contrat API** : `Docs/CONTRAT_API_LOGICIEL.md` décrit les endpoints attendus par l’app (auth + sync).

Il reste à déployer le backend du logiciel selon ce contrat pour que tout soit opérationnel en production.

---

## Ce qu’on doit faire (plan d’action)

### Priorité 1 – Backend & même compte partout

1. **Backend commun** (API) pour le logiciel web/desktop et l’app.
2. **Vérification « compte existant »** : dans `AuthService.verifyAccountExistsInLogiciel`, appeler ton API (ex. `POST /auth/verify` ou `GET /auth/me` avec token). Si le compte existe → `true`, sinon → `false` (l’app affiche déjà « Aucun compte associé » + lien myfidpass.fr).
3. **Sign in with Apple côté serveur** : backend reçoit l’identifiant Apple (ou le JWT), vérifie qu’il est lié à un commerçant, renvoie succès/échec. Même logique pour Google plus tard.

Sans ça : l’app reste en mode « démo » (connexion possible seulement avec `test@myfidpass.fr` en DEBUG).

### Priorité 2 – Synchronisation données

4. **SyncService** : implémenter `syncIfNeeded()` (récupérer business, cartes, clients, tampons depuis l’API) et `pushLocalChanges()` (envoyer les modifications). Appeler la sync au lancement et après actions importantes (scan, modification carte, etc.).
5. **Identifiants partagés** : que les mêmes Business / CardTemplate / ClientCard soient reconnus entre le logiciel et l’app (IDs serveur, pas seulement locaux).

### Priorité 3 – Connexion Google

6. **Intégrer le SDK** (Firebase Auth ou Google Sign-In).
7. **Config** : Google Cloud / Firebase (OAuth iOS, URL scheme dans Xcode).
8. **Dans l’app** : après succès Google, appeler la même vérification « compte dans le logiciel » que pour Apple, puis connecter si OK.

### Priorité 4 – Finitions & expérience

9. **Site myfidpass.fr** : page inscription/connexion commerçant, et possibilité de lier Apple / Google au compte (pour que la vérification côté app fonctionne).
10. **Gestion erreurs** : messages clairs (réseau, compte inexistant, token expiré).
11. **Tests** : sur device réel (caméra, Sign in with Apple).

---

## Où c’est dans le code

| Besoin | Fichier / endroit |
|--------|--------------------|
| URL création de compte | `AuthService.swift` → `AppWebURL.createAccount` |
| Vérification « compte dans le logiciel » | `AuthService.swift` → `verifyAccountExistsInLogiciel` |
| Sync avec le logiciel | `SyncService.swift` → `syncIfNeeded`, `pushLocalChanges` |
| Login Apple / Google | `AuthService.swift` → `loginWithApple`, `loginWithGoogle` |
| Règles auth & sync | `Docs/SYNC_ET_AUTH.md` |

---

## En une phrase

**On a** : une app commerçant complète (auth, dashboard, scan, carte, profil) et un modèle de données prêt.  
**Il manque** : le backend et les appels API pour que « compte » et « données » soient les mêmes entre le logiciel et l’app ; puis Google Sign-In si tu veux l’activer.

**Prochaine étape logique** : définir (ou réutiliser) l’API du logiciel, puis brancher `verifyAccountExistsInLogiciel` et la sync dans l’app.
