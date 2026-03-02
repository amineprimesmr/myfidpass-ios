# Liste complète des fonctionnalités – App & logiciel MyFidpass

Document de référence pour organiser l’app et le logiciel : **tout ce qui existe** et **tout ce que le commerçant peut faire**.

---

## 1. Vue d’ensemble par onglet (App mobile)

| Onglet | Contenu principal |
|--------|-------------------|
| **Tableau de bord** | Stats, scans du jour, activité récente, liste des membres, envoi de notifications, accès aux catégories |
| **Scanner** | Scan QR code des cartes clients → enregistrement du passage + attribution des points/tampons |
| **Ma Carte** | Aperçu de la carte (Wallet / Carte bancaire / Grille), personnalisation du design, test Apple Wallet |
| **Profil** | Infos établissement, logo, adresse, notifications, localisation, déconnexion |

---

## 2. Tout ce que le commerçant peut faire (par domaine)

### 2.1 Compte & accès

- **Se connecter** : email + mot de passe, ou Sign in with Apple, ou (optionnel) Google.
- **Créer un compte** : via le site myfidpass.fr (l’app redirige si pas de compte).
- **Se déconnecter** : depuis l’onglet Profil.
- **Recevoir les notifications push** : statut affiché dans Profil ; lien vers les réglages iOS pour activer/désactiver. Le device token est envoyé au backend pour que le SaaS puisse envoyer des alertes au commerçant.

---

### 2.2 Carte de fidélité (concept global)

- **Une carte unique par commerce** : le design et les règles (tampons, couleurs, etc.) s’appliquent à **tous** les clients qui ajoutent la carte à leur Wallet.
- **Deux modes de fidélité** (définis côté backend / pass) :
  - **Points** : accumulation de points (par visite et/ou par euro).
  - **Tampons** : X tampons pour une récompense (ex. 10 cafés = 1 offert).

---

### 2.3 Design & personnalisation de la carte (« Ma Carte »)

- **Nom de l’établissement** : affiché sur la carte (ex. « Café du coin »).
- **Logo** : image du commerce sur la carte (URL ou import photo depuis l’app). Synchronisation « dernière modification gagne » entre app et SaaS.
- **Couleurs** : couleur principale (fond), couleur d’accent (points/tampons).
- **Emoji** : emoji optionnel affiché à côté des points/tampons (ex. ☕).
- **Nombre de tampons pour une récompense** : ex. 10 tampons = 1 café offert.
- **Aperçu en direct** : 3 formats — Wallet (style Apple Wallet), Carte bancaire, Grille (style STELLAR HUB).
- **Simuler les tampons** : slider pour prévisualiser la carte avec 0 à N tampons.
- **Galerie de designs** : appliquer un design prédéfini (café, fast-food, boulangerie, etc.) depuis « Designs » en haut à droite.
- **Tester dans l’Apple Wallet** : télécharger le pass (.pkpass) et l’ajouter à son propre Wallet pour vérifier le rendu.

---

### 2.4 Fonctions de la carte (règles d’attribution)

- **Points par visite** : réglé côté backend (ex. 1 point par scan).
- **Points par euro** : réglé côté backend (ex. 1 point par euro dépensé) — utilisé lors du scan si un montant est envoyé.
- **Format** : points ou tampons (et nombre de tampons pour la récompense) — synchronisé via les paramètres de la carte (Ma Carte + backend).

*(Ces réglages peuvent être exposés dans le SaaS ; dans l’app, la personnalisation visible est surtout : nom, couleurs, logo, nombre de tampons, emoji.)*

---

### 2.5 Données clients / membres

- **Liste des membres** : visible dans le Tableau de bord (nom, points/tampons, dernière visite). Données synchronisées avec le backend.
- **Données par membre** (fournies par l’API / sync) :
  - **Identifiant** (id)
  - **Nom** (prénom / nom ou nom affiché)
  - **Email** (si fourni à l’inscription)
  - **Points** (solde actuel)
  - **Dernière visite** (lastVisitAt)
  - **Catégories** : liste des catégories auxquelles le membre appartient (ids).
- **Création des membres** : automatique lors du **premier scan** du QR code d’un client (le backend crée le membre et associe les points/tampons).
- **Modification des catégories d’un membre** : depuis la liste des membres (Tableau de bord) ou l’écran Catégories (affectation aux catégories).

---

### 2.6 Catégories

- **Créer des catégories** : nom + couleur (hex). Ex. « VIP », « Étudiants », « Classe 1 ».
- **Modifier une catégorie** : nom, couleur, ordre d’affichage.
- **Supprimer une catégorie**.
- **Assigner des membres à des catégories** : un membre peut être dans plusieurs catégories.
- **Utilisation** : cibler les **notifications** par catégorie (envoyer à tous, ou seulement à certaines catégories).

*(Accès dans l’app : Tableau de bord → menu (icône personnes) → « Gérer les catégories ».)*

---

### 2.7 Notifications (envoi aux clients)

- **Envoyer un message à tous les membres** : barre de message en bas du Tableau de bord ; saisie du texte puis envoi (push Wallet + Web Push si les clients sont inscrits).
- **Envoyer uniquement à certaines catégories** : choix des catégories via les chips (destinataires) avant d’écrire/envoyer le message.
- **Contenu** : titre + corps du message. L’icône de la notification (navigateur) peut être le logo du commerce ; sur Wallet, l’icône est celle du pass (logo si configuré dans le pass).

---

### 2.8 Scan & enregistrement des passages

- **Scanner le QR code** d’une carte client (depuis l’onglet Scanner).
- **Effet** : envoi au backend (`POST .../integration/scan`) avec identifiant de la carte (barcode), optionnellement points à ajouter ou montant en euros (pour calcul points par euro).
- **Résultat** : le membre est mis à jour (points/tampons), sa « dernière visite » est mise à jour ; le client peut recevoir une mise à jour de son pass Wallet (changement de points/tampons).
- **Toast / feedback** : confirmation visuelle (ex. Dynamic Island style) après un scan réussi et détection du membre.

---

### 2.9 Localisation & rayon (pass Wallet)

- **Adresse du commerce** : renseignée dans **Profil** (établissement) avec recherche d’adresse. Enregistrée et envoyée au backend (`location_address`). Utilisée pour :
  - Affichage dans le Profil (« Voir sur la carte » = ouvrir l’adresse dans l’app Plans).
  - **Relevant locations** du pass Apple Wallet : quand le client est proche du commerce, l’iPhone peut afficher la carte sur l’écran de verrouillage.
- **Coordonnées (lat/lng)** et **rayon (mètres)** : gérés côté **backend** (et potentiellement SaaS). Le pass est généré avec des points de localisation autour de l’adresse et un rayon (ex. 100–2000 m). Dans l’app, seule l’**adresse** est éditée pour l’instant ; le backend peut dériver ou stocker lat/lng et rayon (SaaS ou à venir dans l’app).
- **Texte pertinent (relevant text)** : court texte affiché sur l’écran de verrouillage quand le client est proche (ex. « Votre café vous attend »). Côté backend ; à exposer en SaaS ou dans l’app si besoin.

---

### 2.10 Tableau de bord (stats & activité)

- **Cartes actives** : nombre de membres (clients avec une carte).
- **Scans aujourd’hui** : nombre de scans enregistrés le jour même.
- **Liste des membres** (depuis Cartes actives) : recherche par nom/email/identifiant, fiche membre (nom, email, points, dernière visite, catégories), actions Catégoriser et Ajouter des points.
- **Actualisation** : pull-to-refresh = resync avec le backend (stats, membres, transactions, catégories, paramètres).

---

### 2.11 Profil établissement

- **Nom de l’établissement**, **email**, **téléphone**, **adresse** : édition et enregistrement (sync avec le backend via paramètres / mise à jour carte).
- **Logo** : changement de logo (photo) ; synchronisation avec le SaaS (dernière modification gagne).
- **Localisation** : affichage de l’adresse + bouton « Voir sur la carte » (ouvre Plans).
- **Notifications** : statut (activées / désactivées) + lien vers réglages iOS.
- **Carte Wallet & clients** : rappel que le design dans Ma Carte s’applique à tous les clients.

---

### 2.12 Mises à jour de l’app

- **Vérification de version** : à l’ouverture, l’app peut vérifier si une nouvelle version est disponible sur l’App Store et afficher un écran invitant à mettre à jour (VersionAppCheck / AppUpdateView).

---

## 3. Ce qui existe côté logiciel (SaaS / backend)

- **Dashboard web** (myfidpass.fr) : accès par slug + token ou compte.
- **Paramètres complets** : organisation_name, couleurs, required_stamps, stamp_emoji, logo, **location_address**, **location_lat**, **location_lng**, **location_radius_meters**, **location_relevant_text**.
- **Stats & évolution** : membres, transactions, évolution dans le temps (endpoints dashboard/stats, dashboard/evolution).
- **Export** : export des membres (CSV), export des transactions (CSV).
- **Gestion des catégories** : CRUD catégories, affectation des membres aux catégories (API utilisée aussi par l’app).
- **Envoi de notifications** : API notify (avec option category_ids) ; Web Push + PassKit (APNs).
- **Génération du pass** : GET pass pour un membre avec design (couleurs, nom, emoji, tampons) ; génération des icônes du pass à partir du logo (notifications Wallet).
- **Scan** : POST integration/scan (barcode, visit, points, amount_eur).
- **Inscription device** : POST device/register (token push pour le commerçant).

---

## 4. Récapitulatif : où se fait quoi

| Action | App mobile | SaaS / Backend |
|--------|------------|----------------|
| Connexion / compte | ✅ | ✅ (création compte possible sur le site) |
| Modifier le design de la carte (nom, logo, couleurs, emoji, tampons) | ✅ Ma Carte + Profil (logo/adresse) | ✅ Paramètres |
| Modifier les fonctions (points par visite / par euro) | ❌ (backend) | ✅ |
| Localisation (adresse) | ✅ Profil | ✅ |
| Rayon + texte pertinent (relevant) | ❌ | ✅ (backend + SaaS) |
| Voir les membres & données client | ✅ Tableau de bord | ✅ Dashboard |
| Catégories (CRUD + affectation) | ✅ Gérer les catégories | ✅ |
| Envoyer des notifications (tous ou par catégorie) | ✅ Tableau de bord | ✅ |
| Scanner les cartes | ✅ Scanner | ✅ (enregistrement) |
| Tester le pass Wallet | ✅ Ma Carte | ✅ (génération pass) |
| Export membres / transactions | ❌ | ✅ |
| Évolution / stats avancées | ❌ (stats basiques dans l’app) | ✅ |

---

## 5. Idées d’organisation pour simplifier

1. **Regrouper « Ma Carte »** : tout ce qui touche au **design** (nom, logo, couleurs, emoji, nombre de tampons, galerie) est déjà dans Ma Carte ; les **règles** (points par visite / par euro) restent côté SaaS ou à exposer dans un écran « Règles de la carte » ou dans Profil/Paramètres.
2. **Profil** : garder « Établissement » (nom, logo, adresse, tél, email), « Notifications », « Localisation », « Déconnexion ». Optionnel : lien « Ouvrir le tableau de bord web » (myfidpass.fr) pour export et paramètres avancés (rayon, texte pertinent).
3. **Tableau de bord** : garder stats, activité, liste des membres, barre de notification, accès aux catégories. Clair que « Message » = envoi aux clients (tous ou par catégorie).
4. **Données client** : prénom/nom et email viennent du **membre** (créé au premier scan ou à l’inscription côté web). Les modifier peut rester sur le SaaS ou être ajouté dans l’app (fiche membre → éditer).

Tu peux utiliser ce doc comme base pour les specs, l’UX et les prochaines évolutions (ex. ajouter rayon + texte pertinent dans l’app, ou écran « Règles de la carte »).
