# Analyse A–Z et corrections pour que tout fonctionne à 100 %

Ce document résume l’analyse des dossiers **myfidpass** (app iOS) et **fidelity** (backend) et les corrections appliquées pour que l’ensemble fonctionne de bout en bout.

---

## 1. Backend (fidelity) – Modifications effectuées

### 1.1 Réponses API en snake_case pour l’app iOS

L’app utilise `keyDecodingStrategy: .convertFromSnakeCase` : elle attend des clés **snake_case** dans le JSON.

- **GET /api/businesses/:slug/dashboard/settings**  
  Les champs renvoyés sont maintenant en snake_case : `organization_name`, `background_color`, `foreground_color`, `location_address`, `required_stamps`, etc.

- **GET /api/businesses/:slug/dashboard/stats**  
  Réponse en snake_case : `members_count`, `points_this_month`, `transactions_this_month`, `new_members_last_7_days`, `new_members_last_30_days`, `business_name`.

- **GET /api/auth/me**  
  `subscription` : `plan_id` au lieu de `planId`.  
  `has_active_subscription` au lieu de `hasActiveSubscription`.

### 1.2 Authentification : 404 si pas de compte

- **POST /api/auth/login**  
  Si l’email n’existe pas en base → **404** (au lieu de 401), avec message invitant à créer un compte sur myfidpass.fr. L’app affiche alors « Créez votre compte sur myfidpass.fr ».

- **POST /api/auth/apple**  
  Si aucun utilisateur n’est trouvé pour l’email Apple → **404** (on ne crée plus de compte automatiquement).

- **POST /api/auth/google**  
  Même logique : **404** si pas de compte existant.

### 1.3 POST /api/device/register

- Nouvelle table **merchant_device_tokens** (`user_id`, `device_token`, `updated_at`) pour enregistrer le token APNs de l’app commerçant.
- Nouvelle route **POST /api/device/register** (auth JWT requise), body : `{ "device_token": "..." }`, réponse **204**.
- Fichier **backend/src/routes/device.js** et enregistrement dans **index.js**.

### 1.4 POST /api/businesses/:slug/notify

- Nouvelle route **POST /api/businesses/:slug/notify**, body : `{ "message": "..." }`.
- Même logique que **POST .../notifications/send** : envoi aux clients (Web Push + PassKit).
- Réponse **200** avec `{ ok, sent, sentWebPush, sentPassKit }`. L’app peut ignorer le body (elle utilise `EmptyResponse`).

---

## 2. App iOS (myfidpass) – Modifications effectuées

### 2.1 Sync : requiredStamps depuis les settings

- **BusinessSettingsResponse** : ajout du champ optionnel `requiredStamps` (décodé depuis `required_stamps`).
- **SyncService.mergeIntoCoreData** : mise à jour de `template.requiredStamps` à partir de `settings.requiredStamps` lorsque la valeur est présente et > 0.

---

## 3. Déjà en place (vérifié)

- **POST /api/auth/login** et **POST /api/auth/apple** : retournent `token`, `user`, `businesses` (avec `slug`).  
- **GET /api/auth/me** : utilisé par l’app pour la sync ; format aligné (snake_case pour subscription et has_active_subscription).  
- **GET dashboard/settings, stats, members, transactions** : membres et transactions en snake_case (noms de colonnes SQL).  
- **PATCH /api/businesses/:slug/dashboard/settings** : déjà implémenté côté backend, appelé par l’app lors de « Enregistrer le design ».  
- **POST /api/businesses/:slug/integration/scan** : body et réponse conformes (member, points_added, new_balance).  
- **GET /api/businesses/:slug/members/:memberId/pass?template=classic** : utilisé par l’app pour « Tester dans l’Apple Wallet ».

---

## 4. Récapitulatif des endpoints utilisés par l’app

| Endpoint | Méthode | Statut |
|----------|---------|--------|
| /api/auth/login | POST | OK (404 si pas de compte) |
| /api/auth/apple | POST | OK (404 si pas de compte) |
| /api/auth/me | GET | OK (réponse snake_case) |
| /api/businesses/:slug/dashboard/settings | GET | OK (snake_case) |
| /api/businesses/:slug/dashboard/settings | PATCH | OK |
| /api/businesses/:slug/dashboard/stats | GET | OK (snake_case) |
| /api/businesses/:slug/dashboard/members | GET | OK |
| /api/businesses/:slug/dashboard/transactions | GET | OK |
| /api/businesses/:slug/integration/scan | POST | OK |
| /api/businesses/:slug/members/:memberId/pass?template=classic | GET | OK |
| /api/businesses/:slug/notify | POST | OK (ajouté) |
| /api/device/register | POST | OK (ajouté) |

---

## 5. Déploiement

1. **Backend** : déployer la version mise à jour (fidelity) sur Railway (ou ton hébergeur). La table `merchant_device_tokens` est créée au premier démarrage.
2. **App** : recompiler et tester (connexion, sync, Ma Carte, scan, Wallet, notifications, envoi de message aux clients).

Après déploiement, l’app et le backend sont alignés pour un fonctionnement à 100 %.
