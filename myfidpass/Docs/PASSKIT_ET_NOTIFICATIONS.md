# PassKit, notifications et localisation – concepts Apple & backend

Ce document décrit les **noms officiels Apple** et ce que le **backend** doit mettre en place pour que l’app et le pass Wallet fonctionnent comme prévu (affichage à la proximité, mises à jour, notifications, lien au dos du pass).

---

## 1. Framework Apple : PassKit

**PassKit** est le framework Apple pour les passes (cartes de fidélité, billets, etc.) dans le Wallet.

- Doc : [PassKit | Apple Developer](https://developer.apple.com/documentation/passkit)
- L’app mobile utilise PassKit pour afficher la feuille « Ajouter à l’Apple Wallet » (`PKAddPassesViewController`). La **génération et la signature du pass** (.pkpass) se font côté **backend**.

---

## 2. Affichage du pass sur l’écran de verrouillage (proximité)

### Relevant locations (dans le pass)

Ce sont les **coordonnées (lat/long)** que l’on met **dans le pass** (champ `relevantLocations` dans `pass.json`). Quand l’utilisateur est **près** d’un de ces points, iOS peut **proposer le pass sur l’écran de verrouillage**. La position n’est **pas** envoyée à ton serveur.

- Doc Apple : [Showing a Pass on the Lock Screen](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Creating.html#//apple_ref/doc/uid/TP40012195-CH4-SW1) (voir « Relevant locations »).

**À faire côté backend :**

- Lors de la génération du pass (`.pkpass`), inclure dans `pass.json` le champ **`relevantLocations`** avec les coordonnées du commerce (lat/long). L’app envoie l’**adresse** du commerce (Profil → formulaire + sync depuis `dashboard/settings` avec `locationAddress` / `locationLat` / `locationLng`). Le backend peut utiliser cette adresse (ou des coordonnées déjà stockées) pour remplir `relevantLocations`.

**Résumé pour l’équipe :**  
« On utilise les **relevant locations** du pass (PassKit) pour que le pass s’affiche sur l’écran de verrouillage quand l’utilisateur est proche du commerce. »

---

## 3. Mises à jour du pass + notification (changeMessage)

### Web Service URL

URL de ton backend que le **Wallet** appelle pour :

- **Enregistrer l’appareil** : device library ID + **push token** (APNs).
- **Télécharger la dernière version du pass** quand Wallet le demande (après une notification push).

Le pass contient dans `pass.json` l’URL de ce web service. C’est le **backend** qui l’expose (endpoints documentés par Apple pour les passes).

### Push token (APNs)

Quand le pass est installé, l’**appareil du client** envoie ce token à ton serveur (via le Web Service du pass). Pour **mettre à jour le pass** (points, tampons, texte), le backend envoie une **notification push** via APNs ; l’iPhone **recharge alors le pass** depuis ta Web Service URL.

### changeMessage

Lors d’une **mise à jour du pass**, tu peux définir un **`changeMessage`** (ex. « Tu as maintenant 42 points ! »). iOS peut l’afficher comme **notification sur l’écran de verrouillage**.

**À faire côté backend :**

- Implémenter le **Web Service** PassKit (enregistrement device + push token, mise à jour du pass).
- Lors d’un scan ou d’un envoi de message depuis l’app commerçant : envoyer une **mise à jour de pass** (avec `changeMessage` si souhaité) via APNs pour que les clients reçoivent la notif et le pass à jour.

**Résumé :**  
« On utilise le **Web Service du pass** (enregistrement du push token) et **APNs** pour pousser des mises à jour du pass ; le **changeMessage** permet d’afficher une notification sur l’écran de verrouillage. »

---

## 4. Envoi d’un message par le commerçant (app → backend)

L’app mobile propose dans **Profil → Notifications** une zone **« Notifier vos clients »** : le commerçant **écrit un message** et tape **« Envoyer la notification »**.

- L’app appelle : **POST** `/api/businesses/:slug/notify`  
  Body : `{ "message": "Texte du message" }`
- Le **backend** doit :
  - soit envoyer ce message aux clients (pass installé) via **APNs** (en tant que `changeMessage` ou notification associée au pass),
  - soit déclencher une mise à jour de pass avec ce message en `changeMessage`.

Aucune logique PassKit côté app : l’app envoie uniquement le message au backend ; c’est le backend qui décide comment le diffuser (push, mise à jour de pass, etc.).

---

## 5. Lien au dos du pass

### Back field avec URL

Sur le **dos du pass**, un champ (**back field**) avec une **URL** et **`PKDataDetectorTypeLink`** pour que le lien soit **cliquable**.

- Chez nous : libellé **« Voir en ligne »**, lien vers le site (ex. `https://myfidpass.fr`).

**À faire côté backend :**  
Lors de la génération du pass, ajouter dans `pass.json` un **back field** avec cette URL et le type approprié pour que le lien soit détecté et cliquable.

---

## 6. Récap : ce qu’on a mis en place ↔ nom technique Apple

| Ce qu’on a mis en place | Nom technique / Apple |
|-------------------------|------------------------|
| Pass s’affiche près du magasin | **Relevant locations** / “Showing a Pass on the Lock Screen” |
| Mise à jour des points/tampons à distance | **Pass update** via **Web Service URL** + **push token** + **APNs** |
| Notification « Tu as X points » sur l’écran de verrouillage | **changeMessage** lors de la mise à jour du pass |
| Lien cliquable au dos du pass | **Back field** avec URL + **PKDataDetectorTypeLink** |
| Commerçant envoie un message aux clients | App : **POST /api/businesses/:slug/notify** ; backend envoie via APNs / changeMessage |

---

## 7. Références doc Apple

- **Wallet Passes** : [PassKit](https://developer.apple.com/documentation/passkit)
- **Updating a Pass** : [Updating a Pass](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Updating.html)
- **Showing a Pass on the Lock Screen** : [Relevant locations](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Creating.html)

---

## 8. Contrat API app ↔ backend (rappel)

- **GET** `/api/businesses/:slug/wallet-pass` → retourne le fichier **.pkpass** (avec `relevantLocations`, back field « Voir en ligne », etc.).
- **POST** `/api/businesses/:slug/notify` → body `{ "message": "string" }` → le backend envoie ce message aux clients (push / changeMessage).
- **GET** `.../dashboard/settings` → peut retourner `locationAddress`, `locationLat`, `locationLng` pour que l’app et le backend aient la même adresse / coordonnées pour les **relevant locations**.

---

## 9. Matrice des canaux (refonte notifications)

| Canal | Public | Contenu typique | Cooldown auto |
|--------|--------|-----------------|---------------|
| **PassKit** (APNs `PASS_TYPE_ID`) | Clients avec carte dans Apple Wallet | Push vide → iPhone retélécharge le pass (`last_broadcast_message`, points, etc.) | Oui pour les campagnes (`notification_log` avec `counts_for_member_cooldown=1`) |
| **Web Push** (VAPID) | Clients ayant activé les notifs navigateur | Titre + message + icône | Idem |
| **App commerçant** (APNs bundle `com.myfidpass`) | Commerçant connecté sur l’app iOS | **Accusé** de campagne (résumé Wallet / Web), pas le message client | Non (`merchant_receipt`, cooldown 0) |

- Chaque envoi campagne crée un **`batch_id`** (`notification_batches` + lignes dans `notification_log`).
- Les mises à jour pass « techniques » (points en caisse, etc.) peuvent être journalisées avec `trigger_name=pass_sync` et **sans** impacter le cooldown (à activer côté serveur si besoin).

---

## 10. Pourquoi « rien ne se passe » puis tout apparaît après rafraîchir dans Wallet ?

### Comportement normal Apple (PassKit)

- La **mise à jour d’une carte** ne passe **pas** par une notification comme iMessage : le serveur envoie un **push APNs vide** (`aps: {}`) vers le **Pass Type ID**. Ce n’est **pas** une alerte avec titre/corps comme une app classique.
- Ce push sert surtout à **réveiller** le Wallet pour qu’il interroge ton **Web Service** (`GET …/devices/…/registrations/…` puis `GET …/passes/…`) et **retélécharge** le `.pkpass`.
- **Apple ne garantit pas** une bannière immédiate sur l’écran de verrouillage ni une mise à jour instantanée : mode économie d’énergie, réseau, file d’arrière-plan, etc. peuvent retarder le fetch.
- **Tirer pour rafraîchir** dans le détail de la carte force un **téléchargement immédiat** du pass : c’est pour ça que le texte / les points « apparaissent enfin » même si le push a été lent ou la bannière absente.

### Ce qui améliore vraiment l’expérience « comme les concurrents »

1. **Web Service joignable** : `PASSKIT_WEB_SERVICE_URL` (ou `API_URL`) correct sur Railway ; enregistrement device visible dans les logs (`POST …/devices/…/registrations/…` avec push token).
2. **APNs production** pour les vrais iPhones : `APNS_USE_SANDBOX` ne doit pas être activé en prod ; `PASS_TYPE_ID` = identifiant du type de pass dans Apple Developer.
3. **`changeMessage` sur un champ visible sur la face** : le message de campagne est aussi exposé sur la **face** du pass (champ dédié), pas seulement au verso, pour que Wallet puisse associer la mise à jour à une alerte utilisateur lorsque le pass est rechargé.

### Ce qu’il ne faut pas confondre

- **PassKit** = clients avec carte dans **Apple Wallet**.
- **Web Push** = clients avec notif **navigateur** (autre canal).
- **App commerçant (bundle `com.myfidpass`)** = accusés / infos pour le **commerçant**, pas le message client sur Wallet.
