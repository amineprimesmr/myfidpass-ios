# Contrat API – Catégories de membres

Ce document décrit les endpoints et formats nécessaires pour le **système de catégories** (classement des membres par le commerçant, ciblage des notifications). À implémenter côté **backend / logiciel** et à garder synchronisé avec l’app mobile.

Base URL : `https://api.myfidpass.fr`  
Headers : `Authorization: Bearer <token>`, `Content-Type: application/json`, `Accept: application/json`  
Body JSON : **snake_case** (l’app utilise `keyEncodingStrategy: .convertToSnakeCase`).

---

## 1. Lister les catégories

### GET /api/businesses/:slug/dashboard/categories

**Réponse 200** :
```json
{
  "categories": [
    {
      "id": "string",
      "name": "string",
      "color_hex": "string?",
      "sort_order": 0
    }
  ]
}
```
- `id` : identifiant unique de la catégorie (ex. UUID string).
- `sort_order` : entier pour l’ordre d’affichage (tri croissant).

**Si l’endpoint n’existe pas (404)** : l’app ignore les catégories et continue la sync (members sans `category_ids`).

---

## 2. Créer une catégorie

### POST /api/businesses/:slug/dashboard/categories

**Body** :
```json
{
  "name": "string",
  "color_hex": "string?"
}
```

**Réponse 201** (recommandé) : body = un objet catégorie (même format qu’un élément de `categories` ci‑dessus), ex. :
```json
{
  "id": "string",
  "name": "string",
  "color_hex": "string?",
  "sort_order": 0
}
```
- L’app peut décoder ce body comme `CategoryDTO` pour mise à jour locale ou relancer une sync.

---

## 3. Modifier une catégorie

### PATCH /api/businesses/:slug/dashboard/categories/:categoryId

**Body** (tous les champs optionnels) :
```json
{
  "name": "string?",
  "color_hex": "string?",
  "sort_order": 0
}
```

**Réponse** : **200** ou **204** (avec ou sans body). Si body présent, même format qu’un élément de `categories`.

---

## 4. Supprimer une catégorie

### DELETE /api/businesses/:slug/dashboard/categories/:categoryId

**Réponse** : **200** ou **204** (sans body).

- Les membres ne sont pas supprimés ; seules leurs assignations à cette catégorie sont retirées.

---

## 5. Assignation des membres aux catégories

### GET /api/businesses/:slug/dashboard/members

Étendre la réponse existante des membres avec un champ optionnel **category_ids** :

```json
{
  "members": [
    {
      "id": "string",
      "name": "string?",
      "email": "string?",
      "points": 0,
      "created_at": "string?",
      "last_visit_at": "string?",
      "category_ids": ["id1", "id2"]
    }
  ],
  "total": 0
}
```
- `category_ids` : liste des `id` de catégories auxquelles le membre appartient. Optionnel (si absent, l’app considère une liste vide).

---

### POST /api/businesses/:slug/dashboard/members/:memberId/categories

Met à jour les catégories d’un membre (remplace la liste entière).

**Body** :
```json
{
  "category_ids": ["id1", "id2"]
}
```

**Réponse** : **200** ou **204** (avec ou sans body).

- L’app envoie la liste **complète** des `category_ids` pour ce membre après chaque ajout/suppression dans une catégorie.

---

## 6. Notifications ciblées par catégorie

### POST /api/businesses/:slug/notify

Étendre le body existant avec un champ optionnel **category_ids** :

**Body** :
```json
{
  "message": "string",
  "category_ids": ["id1", "id2"] | null
}
```

- **Sans `category_ids` ou tableau vide** : envoi à **tous** les membres (comportement actuel).
- **Avec `category_ids` non vide** : envoi **uniquement** aux membres qui ont au moins une de ces catégories (intersection ou union selon la règle métier ; l’app envoie la liste sélectionnée par le commerçant).

**Réponse** : **200** ou **204** (sans body). Le backend envoie le message (APNs / changeMessage PassKit) aux appareils concernés.

---

## Récap ordre / usage

1. **Sync** : `GET .../dashboard/categories` (optionnel) + `GET .../dashboard/members` (avec `category_ids`) → l’app fusionne en local.
2. **Gestion catégories** : `POST` create, `PATCH` update, `DELETE` delete.
3. **Assignation** : `POST .../members/:memberId/categories` avec la liste complète des `category_ids`.
4. **Notification** : `POST .../notify` avec `message` et optionnellement `category_ids` pour cibler par catégorie.

Une fois ces routes et formats en place côté backend, l’app mobile (tableau de bord, cloche, envoi de notification) reste synchronisée et prête pour la production.
