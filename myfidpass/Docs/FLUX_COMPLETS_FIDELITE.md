# Flux complets fidélité — du début à la fin

Tous les scénarios possibles pour le **client** (celui qui a la carte) et le **commerçant** (qui scanne et enregistre).

---

## 1. Côté client (utilisateur final)

### 1.1 Obtenir la carte
- Le client reçoit un lien (SMS, WhatsApp, affiche en magasin) ou scanne un QR.
- Il ouvre le lien sur son téléphone → page « Ajouter à l’Apple Wallet » (ou équivalent).
- Il ajoute la carte à son Wallet. La carte affiche **0 point / 0 tampon** (ou le solde initial si le commerçant a importé des clients avec des points).

### 1.2 Gagner des points ou des tampons
- Le client vient en magasin et achète (ou fait un passage).
- Le **commerçant** scanne la carte du client (QR dans le Wallet) ou saisit le client + montant/passage dans le logiciel.
- Selon les règles du commerce :
  - **Tampons** : 1 tampon par passage (ou 1 par € si réglé ainsi) → la carte se remplit (ex. 3/10).
  - **Points** : X points par € dépensé et/ou Y points par passage → le total de points augmente (ex. 42 pts).
- Le pass Wallet se met à jour (push ou au prochain ouvert).

### 1.3 Utiliser sa récompense (c’est là que ça bloque aujourd’hui sans « redeem »)
- **Tampons** : quand le client a 10/10 (ou le nombre requis), il a droit à la récompense (ex. 1 café offert). Il dit au commerçant : « Je prends mon café offert. »
- **Points** : quand il a assez de points (ex. 100 pts = 5 € de réduction), il dit : « Je utilise mes points pour la réduction. »

**Sans fonction « Utiliser la récompense »** : le commerçant n’a aucun moyen dans l’app ni le logiciel de **déduire** les tampons (remise à 0) ou les points (soustraire 100). Donc le client ne peut pas « consommer » sa récompense dans le système.

**Avec la fonction « Utiliser la récompense »** (à implémenter) :
- Le commerçant scanne la carte (ou ouvre la fiche du client), puis clique sur **« Utiliser la récompense »**.
- **Tampons** : le solde repasse à 0 (et on enregistre une transaction « récompense tampons »).
- **Points** : on déduit le nombre de points du palier choisi (ex. 100 pts), et on enregistre une transaction « récompense points ».
- Le pass du client se met à jour (nouveau solde).

---

## 2. Côté commerçant — ce qu’il fait aujourd’hui

| Action | Où | Ce qui se passe |
|--------|-----|------------------|
| **Configurer les règles** | Ma Carte (app ou SaaS) | Type (points / tampons), points par €, points par visite, montant min, paliers (ex. 100 pts = 5 €), nombre de tampons pour la récompense, libellé de la récompense. |
| **Scanner pour créditer** | Scanner (app) ou Caisse / Scanner (SaaS) | Lookup client → choix « 1 passage » ou « Montant (€) » → enregistrement → points ou tampons ajoutés, pass mis à jour. |
| **Voir les membres** | Tableau de bord (app ou SaaS) | Liste des clients, solde de points/tampons, dernière visite. |
| **Utiliser la récompense** | **Manquant** | Le commerçant doit pouvoir, après un scan ou depuis la fiche membre, cliquer sur « Utiliser la récompense » pour déduire les tampons (remise à 0) ou les points (soustraire selon le palier). |

---

## 3. Scénarios complets de bout en bout

### Scénario A — Carte tampons (ex. café)
1. Le commerçant règle : 10 tampons = 1 café offert, 1 tampon par passage.
2. Le client ajoute la carte au Wallet (0/10).
3. À chaque visite, le commerçant scanne → « 1 passage » → le client passe à 1/10, 2/10, … 10/10.
4. Au 10ᵉ passage, le client demande son café offert. **Le commerçant** : scanne la carte (ou ouvre la fiche) → **« Utiliser la récompense »** → le système remet les tampons à 0/10 et enregistre la récompense.
5. La carte Wallet affiche à nouveau 0/10 ; le client peut recommencer à remplir.

### Scénario B — Carte points (ex. 1 pt/€, paliers)
1. Le commerçant règle : 1 pt/€, 100 pts = 5 € de réduction, 200 pts = 10 €.
2. Le client a 150 pts. Il achète pour 30 € et demande à utiliser 100 pts (5 € de réduction).
3. Le commerçant : scanne (ou saisit le client) → enregistre d’abord les 30 € (client passe à 180 pts) puis **« Utiliser la récompense »** → choisit le palier 100 pts → le système déduit 100 pts (solde 80 pts) et enregistre la transaction « récompense ».
4. Le client paie 25 € (30 − 5). Son pass affiche 80 pts.

### Scénario C — Intégration caisse
1. La caisse envoie `POST .../integration/scan` avec `barcode` + `amount_eur` à chaque achat.
2. Les points s’accumulent automatiquement.
3. Quand le client veut utiliser ses points, le commerçant peut le faire depuis l’app ou le SaaS (**« Utiliser la récompense »**) car la caisse ne gère en général que l’ajout, pas la déduction.

---

## 4. Ce qu’il faut ajouter pour que « utiliser les points » marche

- **Backend** : un endpoint du type `POST .../members/:memberId/redeem` (ou `.../integration/redeem` avec barcode) avec body :
  - **Tampons** : `{ "type": "stamps" }` → remise des points (tampons) à 0, si `member.points >= required_stamps`.
  - **Points** : `{ "type": "points", "points": 100 }` ou `{ "tier_index": 0 }` → déduction du nombre de points du palier, si le solde est suffisant.
- **App** : après un lookup (scanner) ou dans la fiche membre, bouton **« Utiliser la récompense »** (affiché seulement si le client a assez de points/tampons), qui appelle cet endpoint.
- **SaaS** : même bouton dans la caisse rapide (après sélection du client) et/ou dans la fiche membre.
- **Historique** : enregistrer une transaction de type `reward_redeem` (ou `stamps_redeem` / `points_redeem`) pour l’historique et les stats.
- **Wallet** : après redeem, déclencher la mise à jour du pass (même mécanisme qu’après ajout de points) pour que le client voie son nouveau solde.

Une fois tout ça en place, les flux « gagner » et « utiliser » sont complets de A à Z.
