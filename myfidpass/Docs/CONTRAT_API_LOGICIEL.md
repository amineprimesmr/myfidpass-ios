# Contrat API – App mobile ↔ Backend (logiciel)

L’app appelle **uniquement** les endpoints ci‑dessous sur **https://api.myfidpass.fr**.  
Tous les chemins commencent par `/api/`. Les body JSON sont en **snake_case** (l’app encode avec `keyEncodingStrategy: .convertToSnakeCase`).

**Headers communs** (sauf pour login/apple/google) :  
`Authorization: Bearer <token>`  
`Content-Type: application/json`  
`Accept: application/json`

---

## 1. Authentification

### POST /api/auth/login

Connexion email / mot de passe.

**Body** : `{ "email": "string", "password": "string" }`

**Réponse 200** (obligatoire pour que l’app ouvre la session) :
```json
{
  "token": "string",
  "user": { "id": "string?", "email": "string?", "name": "string?" },
  "businesses": [
    { "id": "string", "name": "string", "slug": "string", "organization_name": "string?", "created_at": "string?", "dashboard_token": "string?" }
  ]
}
```
- L’app stocke `token` et utilise `businesses[0].slug` comme commerce courant. **Il faut au moins un commerce** dans `businesses`.

**Réponse 401** : identifiants incorrects.  
**Réponse 404** : aucun compte associé à cet email → l’app affiche « Créez votre compte sur myfidpass.fr ».

---

### POST /api/auth/apple

Connexion / liaison avec Sign in with Apple. L’app envoie le JWT `identityToken` fourni par Apple.

**Body** (snake_case) : `{ "id_token": "string", "name": "string?", "email": "string?" }`

**Réponse 200** : même format que login (token + user + businesses).  
**Réponse 404** : aucun compte lié à cet identifiant Apple → « Créez votre compte sur myfidpass.fr ».

---

### POST /api/auth/google (optionnel pour l’instant)

Même idée que Apple : body avec `id_token`, réponse 200 = token + user + businesses, 404 = pas de compte.

---

### GET /api/auth/me

Récupère l’utilisateur connecté et la liste des commerces. Appelé à chaque sync (ouverture de l’app, pull-to-refresh).

**Headers** : `Authorization: Bearer <token>`

**Réponse 200** :
```json
{
  "user": { "id": "string?", "email": "string?", "name": "string?" },
  "businesses": [
    { "id": "string", "name": "string", "slug": "string", "organization_name": "string?", "created_at": "string?", "dashboard_token": "string?" }
  ],
  "subscription": { "status": "string?", "plan_id": "string?" },
  "has_active_subscription": true
}
```
- L’app prend `businesses[0].slug` pour les appels suivants (dashboard, scan, wallet, notify). **Il faut au moins un commerce.**

**Réponse 401** : token invalide/expiré → l’app efface le token et redemande une connexion.

---

## 2. Données du commerce (sync)

Après `GET /api/auth/me`, l’app appelle **en parallèle** les 4 endpoints suivants avec le **slug** du commerce (ex. `my-shop`).  
Base : `GET /api/businesses/{slug}/dashboard/...`

### GET /api/businesses/:slug/dashboard/settings

**Réponse 200** :
```json
{
  "organization_name": "string?",
  "background_color": "string?",
  "foreground_color": "string?",
  "label_color": "string?",
  "back_terms": "string?",
  "back_contact": "string?",
  "location_lat": 0.0,
  "location_lng": 0.0,
  "location_address": "string?",
  "required_stamps": 10,
  "logo_url": "string?"
}
```
- Les couleurs en hex (avec ou sans `#`). L’app les utilise pour le nom du commerce, la carte (Ma Carte) et l’adresse (Profil / relevant locations PassKit).
- `logo_url` : URL complète pour récupérer le logo (GET avec Bearer) si le commerce a un logo. L’app l’affiche dans l’aperçu Ma Carte.

### PATCH /api/businesses/:slug/dashboard/settings (Ma Carte → SaaS)

Quand le commerçant enregistre le design de sa carte dans l’app (« Enregistrer le design »), l’app envoie ces champs au backend pour que le SaaS soit à jour.

**Méthode** : `PATCH`
**Body** (snake_case) :
```json
{
  "organization_name": "string",
  "background_color": "string",
  "foreground_color": "string",
  "required_stamps": 10,
  "logo_base64": "string?",
  "logo_url": "string?",
  "location_address": "string?"
}
```
- `location_address` : adresse du commerce (Profil app). Utilisée pour les Relevant locations du pass Wallet.
- `organization_name` = nom affiché sur la carte.
- `background_color` / `foreground_color` = hex sans `#` (ex. `2563EB`, `F59E0B`).
- `required_stamps` = nombre de tampons pour une récompense.
- `logo_base64` : image en base64 (ex. `data:image/png;base64,...`) ou chaîne vide / null pour supprimer le logo. Max 4 Mo.
- `logo_url` : URL publique d’une image (http/https) ; le backend récupère l’image et la stocke comme logo. Ignoré si c’est l’URL du logo de l’API elle‑même.

**Réponse** : **200** ou **204** (sans body). Le backend met à jour les paramètres du commerce (carte fidélité) côté SaaS.

---

### GET /api/businesses/:slug/dashboard/stats

**Réponse 200** :
```json
{
  "members_count": 0,
  "points_this_month": 0,
  "transactions_this_month": 0,
  "new_members_last_7_days": 0,
  "new_members_last_30_days": 0,
  "business_name": "string?"
}
```

---

### GET /api/businesses/:slug/dashboard/members?limit=500&offset=0

**Réponse 200** :
```json
{
  "members": [
    {
      "id": "string",
      "name": "string?",
      "email": "string?",
      "points": 0,
      "created_at": "string?",
      "last_visit_at": "string?"
    }
  ],
  "total": 0
}
```
- Dates en ISO8601. `id` = identifiant du membre (carte client) ; l’app l’utilise comme `qrCodeValue` pour faire le lien avec les transactions.

---

### GET /api/businesses/:slug/dashboard/transactions?limit=100&offset=0

**Réponse 200** :
```json
{
  "transactions": [
    {
      "id": "string?",
      "member_id": "string?",
      "member_name": "string?",
      "member_email": "string?",
      "type": "string?",
      "points": 0,
      "metadata": "string?",
      "created_at": "string?"
    }
  ],
  "total": 0
}
```
- L’app fusionne settings, stats, members et transactions en local (Core Data) pour afficher le tableau de bord (membres, activité, stats).

---

## 3. Scan d’une carte (ajout d’un tampon / visite)

### POST /api/businesses/:slug/integration/scan

Le commerçant scanne le QR code de la carte fidélité du client. L’app envoie le code lu.

**Body** (snake_case) :
```json
{
  "barcode": "string",
  "visit": true,
  "points": null,
  "amount_eur": null
}
```
- `visit: true` = enregistrer une visite (tampon). `points` / `amount_eur` optionnels si ton backend gère d’autres types de scan.

**Réponse 200** :
```json
{
  "member": { "id": "string?", "name": "string?", "email": "string?", "points": 0 },
  "points_added": 0,
  "new_balance": 0
}
```
- L’app affiche le nom du membre et « X point(s) ajouté(s) », puis relance une sync pour mettre à jour le dashboard.

**Réponse 404** : code non reconnu pour ce commerce → l’app affiche « Code non reconnu ».

---

## 4. Notifications push (appareil du commerçant)

### POST /api/device/register

Enregistrement du token APNs pour envoyer des notifications au **commerçant** (sur son téléphone).

**Body** : `{ "device_token": "string" }`  
(Token hex reçu par l’app via `didRegisterForRemoteNotificationsWithDeviceToken`.)

**Réponse** : **200** ou **204** (sans body).

---

## 5. Apple Wallet (pass de test)

### GET /api/businesses/:slug/members/:memberId/pass?template=classic

Récupère le fichier **.pkpass** (bundle signé Apple Wallet) pour un membre donné. L’app utilise le **premier membre** de la liste (dashboard/members) comme `memberId` pour afficher la feuille « Tester dans l’Apple Wallet ».

**Headers** : `Authorization: Bearer <token>`

**Réponse 200** : body binaire = fichier `.pkpass`  
(Content-Type: `application/vnd.apple.pkpass`.)  
L’app présente `PKAddPassesViewController` pour ajouter le pass au Wallet.

**Réponse 404** : pass non trouvé pour ce membre.

---

## 6. Notifier les clients (message push / changeMessage PassKit)

### POST /api/businesses/:slug/notify

Envoi d’un message par le commerçant à tous les clients qui ont le pass installé (affiché sur l’écran de verrouillage via changeMessage ou notification APNs).

**Body** : `{ "message": "string" }`

**Réponse** : **200** ou **204** (sans body). Le backend envoie le message aux appareils enregistrés (APNs / mise à jour du pass avec changeMessage).

---

## Récap : ordre des appels pour que tout fonctionne

1. **Connexion** : `POST /api/auth/login` ou `POST /api/auth/apple` → retourne `token` + `businesses` (au moins un élément avec `slug`).
2. **Sync** : `GET /api/auth/me` → récupère le slug ; puis en parallèle :  
   `GET .../dashboard/settings`, `.../stats`, `.../members`, `.../transactions`.
3. **Scan** : `POST /api/businesses/:slug/integration/scan` avec le code QR scanné.
4. **Wallet** : `GET /api/businesses/:slug/members/:memberId/pass?template=classic` pour télécharger le .pkpass (l’app envoie le premier memberId de la liste membres).
5. **Notifications** : `POST /api/device/register` (token appareil) ; `POST /api/businesses/:slug/notify` (message aux clients).

Si un de ces endpoints n’existe pas ou renvoie un format différent, la fonction correspondante dans l’app ne fonctionnera pas (erreur réseau, 404, ou décodage JSON). Le backend doit implémenter **exactement** ces routes et formats.
