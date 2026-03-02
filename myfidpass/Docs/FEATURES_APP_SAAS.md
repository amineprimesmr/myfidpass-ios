# Où trouver les fonctionnalités du SaaS dans l’app

Ce document indique **où se trouve chaque fonctionnalité** dans l’app mobile, pour avoir la même logique que le SaaS.

---

## Onglet **Tableau de bord**

- **Cartes actives** : nombre de membres (clients avec une carte).
- **Scans aujourd’hui** : nombre de scans du jour.
- **Activité récente** : derniers passages enregistrés (scans).
- **Membres** : liste des clients/membres (synchronisée avec le SaaS).  
→ Données issues de la sync (auth/me + dashboard/stats, members, transactions). **Tirer pour actualiser** = resync avec le SaaS.

---

## Onglet **Scanner**

- **Scan des cartes** : scan QR → envoi direct au SaaS (`POST .../integration/scan`).  
- Les nouveaux passages et membres remontent dans le SaaS ; un **pull-to-refresh** sur le Tableau de bord met à jour les chiffres et la liste.

---

## Onglet **Ma Carte**

- **Aperçu en direct** : rendu de la carte telle que les clients la voient (format Apple Wallet).
- **Personnalisation pour tous les clients** : nom de la carte, couleurs (principale + points), logo (URL ou photo), nombre de tampons pour une récompense.  
  → Le design que tu définis ici **s’applique à la carte que tous les clients ajoutent à l’Apple Wallet** (une fois synchronisé avec le SaaS).
- **Tester dans l’Apple Wallet** : bouton pour charger le pass (.pkpass) depuis le SaaS et l’ajouter à l’Apple Wallet sur ton appareil.

---

## Onglet **Profil**

### Informations commerce

- **Nom, email, téléphone, adresse** : édition et enregistrement en local.  
  → L’adresse est aussi **récupérée depuis le SaaS** lors de la sync (si le SaaS renvoie `locationAddress` dans les settings).

### Notifications

- **Statut** : « Notifications activées » ou « Notifications désactivées » selon la permission iOS.
- **Ouvrir les réglages** : ouvre les réglages iOS pour activer/désactiver les notifications de l’app.  
  → L’app envoie le **device token** au SaaS (`POST /api/device/register`) pour que le SaaS puisse t’envoyer des push (alertes, rappels, etc.).

### Localisation du commerce

- **Adresse** : affichée ici si renseignée (depuis le formulaire ou depuis le SaaS).
- **Voir sur la carte** : ouvre l’adresse dans l’app Plans (Maps).

### Carte Wallet & clients

- **Explication** : la carte personnalisable dans **Ma Carte** est celle que **tous les clients** reçoivent dans leur Apple Wallet.  
  → Design unique pour tous ; les modifications (nom, couleurs, logo, tampons) sont côté commerçant et s’appliquent à tous les clients.

### Déconnexion

- **Se déconnecter** : fermeture de session (token effacé, retour à l’écran d’accueil).

---

## Récapitulatif : SaaS ↔ App

| Fonctionnalité SaaS | Dans l’app |
|---------------------|------------|
| Compte / connexion | Écran d’accueil → Connexion (email, Apple, Google) |
| Tableau de bord (stats, membres, activité) | Onglet **Tableau de bord** (+ pull-to-refresh = sync) |
| Scan / enregistrement des passages | Onglet **Scanner** |
| Personnalisation de la carte (design pour les clients) | Onglet **Ma Carte** |
| Pass Apple Wallet (test + pour les clients) | **Ma Carte** → « Tester dans l’Apple Wallet » ; le même pass est celui que les clients ajoutent |
| Notifications (push) | **Profil** → section Notifications (statut + lien réglages) ; token envoyé au SaaS |
| Localisation / adresse du commerce | **Profil** → Infos (adresse) + section Localisation (« Voir sur la carte ») |
| Profil commerce (nom, email, tél, adresse) | **Profil** → formulaire + enregistrement |

---

## Données synchronisées avec le SaaS

- **À l’ouverture** de l’app (après connexion) et au **pull-to-refresh** (Tableau de bord ou Profil) :  
  - Infos utilisateur et commerces (`/api/auth/me`)  
  - Paramètres du commerce (nom, couleurs, **adresse** via settings)  
  - Stats (membres, transactions)  
  - Liste des membres  
  - Transactions (scans)  

Donc **les modifications faites dans le SaaS** (nouveaux membres, adresse, paramètres, etc.) **apparaissent dans l’app** après une sync (ouverture d’app ou actualisation).
