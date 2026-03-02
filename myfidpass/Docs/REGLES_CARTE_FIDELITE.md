# Règles de la carte fidélité — système complet

Ce document décrit le système de règles que le **commerçant** peut configurer pour sa carte (dans l’app MyFidpass et sur le site SaaS).

## Types de programme

- **Points** : le client accumule des points (ex. 1 pt par €, ou X pts par passage). Les points peuvent être échangés contre des paliers de récompenses (ex. 100 pts = 5€ de réduction).
- **Tampons** : le client reçoit 1 tampon par visite (ou par passage). Après X tampons (ex. 10), il obtient une récompense (ex. 1 café offert).

## Champs côté backend (business)

| Champ | Description |
|-------|-------------|
| `program_type` | `"points"` ou `"stamps"` |
| **Points** | |
| `points_per_euro` | Nombre de points par € dépensé (défaut 1) |
| `points_per_visit` | Points par passage sans montant (défaut 0) |
| `points_min_amount_eur` | Montant minimum (€) pour gagner des points (optionnel) |
| `points_reward_tiers` | JSON : tableau `[{ "points": 100, "label": "5€ de réduction" }, ...]` |
| **Tampons** | |
| `required_stamps` | Nombre de tampons pour la récompense (ex. 10) |
| `stamp_emoji` | Emoji affiché (ex. ☕ 🍔) |
| `stamp_reward_label` | Texte de la récompense (ex. "1 café offert") |
| **Commun** | |
| `expiry_months` | Expiration des points/tampons après X mois (0 = jamais) |
| `sector` | Secteur optionnel : cafe, restaurant, fastfood, bakery, beauty, retail, other |

## Comportement

- **Scan / ajout de points** : le backend calcule les points selon `points_per_euro`, `points_per_visit` et `points_min_amount_eur`. Si un montant est envoyé et qu’il est inférieur au minimum, aucun point n’est ajouté pour ce montant.
- **Pass Wallet** : le format (points ou tampons) est déterminé par `program_type` ; si non défini, par la présence de `required_stamps` (rétrocompatibilité). Le libellé de récompense sur le pass utilise `stamp_reward_label` quand il est renseigné.

## Où configurer

- **App iOS** : Ma Carte → Modifier → section « Règles de la carte » (type, points/€, points/passage, paliers, récompense tampons, expiration).
- **SaaS** : Ma carte → bloc « Règles de la carte » (même champs). Enregistrement avec le bouton « Enregistrer les modifications ».

## API

- **GET** `/api/businesses/:slug/dashboard/settings` : retourne tous les champs (dont `program_type`, `points_per_euro`, `points_reward_tiers`, etc.).
- **PATCH** `/api/businesses/:slug/dashboard/settings` ou **PATCH** `/api/businesses/:slug` : envoi des règles (snake_case ou camelCase selon le client).
