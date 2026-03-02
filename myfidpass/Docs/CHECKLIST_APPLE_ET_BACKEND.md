# Checklist complète : Apple Developer + Backend — pour que tout fonctionne

Ce document liste **tout** ce qu’il faut avoir créé / configuré côté **Apple Developer** et côté **backend** pour que l’app fonctionne à 100 % (connexion, tableau de bord, scan, Wallet, notifications). Rien n’est simulé dans l’app : si un maillon manque, la fonction concernée ne marchera pas.

---

## 1. Côté Apple Developer (developer.apple.com)

### 1.1 App ID et capacités pour l’app mobile

| Élément | Où le faire | À quoi ça sert |
|--------|-------------|----------------|
| **App ID** (ex. `fr.myfidpass.app`) | Certificates, Identifiers & Profiles → Identifiers | Identifiant unique de l’app. |
| **Sign in with Apple** | Sur l’App ID → Capabilities → Sign in with Apple → Enable | Connexion « Continuer avec Apple » dans l’app. |
| **Push Notifications** | Sur l’App ID → Capabilities → Push Notifications → Enable | Recevoir les notifications sur l’appareil du commerçant (et enregistrer le device token via `POST /api/device/register`). |

Sans ces deux capacités activées sur l’App ID, Sign in with Apple et les notifications push ne fonctionneront pas correctement (erreurs à l’exécution ou pas de token).

### 1.2 Provisioning Profile

- Utiliser un **provisioning profile** (Development ou Distribution) qui inclut **cet App ID** avec les capacités ci‑dessus.
- Dans Xcode : **Signing & Capabilities** → choisir ton **Team** et le bon **Bundle Identifier** (celui de l’App ID). Xcode gère le profil à condition que l’App ID soit bien configuré côté Apple.

### 1.3 Apple Wallet (pass .pkpass) — côté **backend**, pas l’app

La génération du **fichier .pkpass** (carte de fidélité dans le Wallet) se fait **sur ton serveur**, pas dans l’app. L’app ne fait qu’appeler `GET /api/businesses/:slug/wallet-pass` et afficher le fichier reçu avec `PKAddPassesViewController`.

Pour que le backend puisse **signer** un pass Wallet, il faut côté **Apple Developer** :

| Élément | Où le faire | À quoi ça sert |
|--------|-------------|----------------|
| **Pass Type ID** | Certificates, Identifiers & Profiles → Identifiers → Pass Type IDs | Identifiant du type de pass (carte de fidélité). |
| **Certificat pour Pass Type ID** | Certificates → créer un certificat associé au Pass Type ID | Le backend utilise ce certificat pour signer le .pkpass. Sans lui, le pass ne s’ajoute pas au Wallet. |

L’app mobile **n’a pas besoin** de Pass Type ID ni de ce certificat : elle affiche uniquement le .pkpass que le backend lui envoie.

---

## 2. Côté Xcode (projet myfidpass)

| Vérification | Où | Statut actuel dans le projet |
|--------------|-----|------------------------------|
| **Signing** | Signing & Capabilities | Team + Bundle ID doivent correspondre à l’App ID Apple. |
| **Sign in with Apple** | Signing & Capabilities | Capability ajoutée. `myfidpass.entitlements` contient `com.apple.developer.applesignin` = Default. |
| **Push Notifications** | Signing & Capabilities | Capability à **activer** dans l’onglet (bouton +). `myfidpass.entitlements` contient déjà `aps-environment` = `development`. Pour la release App Store, passer à `production`. |

À faire dans Xcode :  
1. Ouvrir le projet → cible **myfidpass** → onglet **Signing & Capabilities**.  
2. Vérifier que **Push Notifications** apparaît (si non, cliquer sur **+ Capability** et ajouter **Push Notifications**).  
3. Vérifier que **Sign in with Apple** est bien présente.

---

## 3. Côté backend (api.myfidpass.fr)

L’app appelle **uniquement** cette API. Base URL : `https://api.myfidpass.fr` (configurable en DEBUG via `MYFIDPASS_API_URL`).

Si le backend n’existe pas, ne répond pas ou renvoie des erreurs (401, 404, 500), **aucune fonction réelle ne marche** : pas de connexion, pas de données, pas de scan, pas de pass Wallet, pas d’envoi de notifications.

### 3.1 Endpoints obligatoires (à implémenter dans l’ordre)

| # | Endpoint | Méthode | Rôle |
|---|----------|---------|------|
| 1 | `/api/auth/login` | POST | Connexion email/mot de passe. Body : `email`, `password`. Réponse 200 : `token`, `user`, `businesses` (array avec au moins un objet contenant `slug`). 404 = pas de compte → message myfidpass.fr. |
| 2 | `GET /api/auth/me` | GET | Donne `user` + `businesses` (avec `slug`). Utilisé à chaque sync. |
| 3 | `GET /api/businesses/:slug/dashboard/settings` | GET | Nom, couleurs, adresse du commerce. |
| 4 | `GET /api/businesses/:slug/dashboard/stats` | GET | Stats (membres, points, transactions). |
| 5 | `GET /api/businesses/:slug/dashboard/members` | GET | Liste des membres (id, name, email, points, dates). |
| 6 | `GET /api/businesses/:slug/dashboard/transactions` | GET | Liste des transactions (scans). |
| 7 | `POST /api/businesses/:slug/integration/scan` | POST | Enregistre un scan (body : `barcode`, `visit`, etc.). Réponse : `member`, `points_added`, `new_balance`. 404 si code inconnu. |

Sans ces 7 endpoints avec les **formats exacts** (snake_case, structure JSON) décrits dans **`CONTRAT_API_LOGICIEL.md`**, au moins une des fonctions de base (connexion, tableau de bord, scan) ne fonctionnera pas.

### 3.2 Endpoints pour le reste des fonctionnalités

| Endpoint | Rôle |
|----------|------|
| `POST /api/auth/apple` | Connexion Sign in with Apple. Body : `id_token`, `name`, `email`. Même format de réponse que login. |
| `POST /api/device/register` | Enregistrer le token APNs du commerçant (body : `device_token`). |
| `GET /api/businesses/:slug/wallet-pass` | Retourner le fichier **.pkpass** (binaire, Content-Type `application/vnd.apple.pkpass`). 404 si pass non configuré → l’app affiche « Configurez le pass depuis votre espace en ligne ». |
| `POST /api/businesses/:slug/notify` | Envoyer un message aux clients (body : `message`). Backend envoie les push / met à jour le pass (changeMessage). |

Pour que le bouton **« Tester dans l’Apple Wallet »** fonctionne : le backend doit implémenter **GET /api/businesses/:slug/wallet-pass** et retourner un fichier .pkpass **signé** (avec le certificat Pass Type ID). Sinon l’app reçoit 404 ou une erreur et affiche le message de configuration.

---

## 4. Pourquoi « rien n’est fonctionnel » ?

En pratique, si **rien** ne marche dans l’app, les causes les plus fréquentes sont :

1. **Backend pas déployé ou pas joignable**  
   L’app appelle `https://api.myfidpass.fr`. Si le serveur ne répond pas (DNS, firewall, crash), toutes les requêtes échouent (connexion, sync, scan, wallet, notify).

2. **Endpoints absents ou chemins différents**  
   L’app utilise **exactement** les chemins listés ci‑dessus (avec le préfixe `/api/`). Si le backend expose par exemple `/auth/login` au lieu de `/api/auth/login`, ou ne renvoie pas `businesses` dans la réponse de login, l’app ne pourra pas ouvrir la session ou récupérer le `slug`.

3. **Réponse login/auth/me sans commerce**  
   L’app utilise `businesses[0].slug` pour tous les appels suivants (dashboard, scan, wallet, notify). Si `businesses` est vide ou absent, le slug sera nil et tout le reste échouera.

4. **Wallet : pass non configuré côté backend**  
   Le message que tu vois (« Votre carte n'est pas encore disponible dans l’Apple Wallet » ou l’ancien message « Mode démo… ») signifie que l’app a bien appelé **GET /api/businesses/:slug/wallet-pass** et a reçu une **404** (ou une erreur). Donc soit l’endpoint n’existe pas, soit le backend renvoie 404 pour ce commerce. Il faut implémenter l’endpoint et générer/signer le .pkpass (Pass Type ID + certificat Apple).

5. **Apple Developer : capacités manquantes**  
   Si Sign in with Apple ou Push Notifications ne sont pas activés sur l’App ID (et dans Xcode), Apple bloquera ou limitera ces fonctionnalités.

---

## 5. Ordre des actions recommandé

1. **Backend**  
   - Mettre en ligne (ou en local pour les tests) l’API avec les **7 endpoints obligatoires** et les formats du **CONTRAT_API_LOGICIEL.md**.  
   - Tester avec un outil (Postman, curl) : login → récupérer token et slug → appeler dashboard/settings, stats, members, transactions → appeler integration/scan avec un code test.

2. **Apple Developer**  
   - App ID avec **Sign in with Apple** et **Push Notifications**.  
   - Pour le Wallet : **Pass Type ID** + **certificat** pour que le backend puisse signer le .pkpass.

3. **Xcode**  
   - **Signing & Capabilities** : Team, Bundle ID, **Push Notifications** et **Sign in with Apple** activés.  
   - Rebuild et lancer l’app sur un appareil réel (recommandé pour Sign in with Apple et push).

4. **Wallet**  
   - Implémenter **GET /api/businesses/:slug/wallet-pass** : générer le .pkpass (structure pass + signature avec le certificat Pass Type ID), renvoyer le binaire avec le bon Content-Type.  
   - Après ça, le bouton « Tester dans l’Apple Wallet » dans l’app fonctionnera.

5. **Notifications**  
   - Backend : **POST /api/device/register** pour stocker le device token.  
   - Backend : **POST /api/businesses/:slug/notify** pour envoyer les messages aux clients (APNs / changeMessage).

---

## 6. Récap : ce qui est « connecté » dans l’app

| Fonctionnalité | Côté app | Côté Apple / Backend |
|----------------|----------|----------------------|
| Connexion email / Apple | ✅ Appels `POST /api/auth/login`, `POST /api/auth/apple` | Backend doit répondre 200 + token + businesses. Apple : App ID avec Sign in with Apple. |
| Sync (tableau de bord) | ✅ `GET /api/auth/me` puis 4× `GET .../dashboard/*` | Backend doit exposer ces 5 endpoints avec les bons JSON. |
| Scan carte | ✅ `POST /api/businesses/:slug/integration/scan` | Backend doit accepter le barcode et renvoyer member + points. |
| Tester dans l’Apple Wallet | ✅ `GET /api/businesses/:slug/wallet-pass` + `PKAddPassesViewController` | Backend doit renvoyer un .pkpass signé. Apple : Pass Type ID + certificat. |
| Notifications (commerçant) | ✅ Permission + `registerForRemoteNotifications` + `POST /api/device/register` | Backend enregistre le token. Apple : App ID avec Push Notifications. |
| Notifier les clients | ✅ `POST /api/businesses/:slug/notify` | Backend envoie les push / met à jour le pass. |

Aucun mode démo ni donnée en dur : tout dépend de l’API et de la configuration Apple. Dès que le backend et Apple sont alignés avec cette checklist, tout peut fonctionner réellement.
