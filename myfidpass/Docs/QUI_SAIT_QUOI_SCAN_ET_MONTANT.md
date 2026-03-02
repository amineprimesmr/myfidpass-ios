# Qui sait quoi ? Scan, montant et produits

## En résumé

**On ne sait pas tout seul ce que le client a acheté ni combien il a dépensé.**  
Le système ne lit pas la caisse et ne voit pas le panier. **Quelqu’un doit nous le dire** au moment du scan (ou après) : soit « 1 passage », soit « il a dépensé X € », soit « ajouter N points ».

---

## Ce qu’on sait vraiment

| Info | Comment on l’a |
|------|----------------|
| **Qui est scanné** | Le QR de la carte = identifiant du membre (UUID). Le backend retrouve le client. |
| **Combien de points/tampons ajouter** | Uniquement ce qui est **envoyé** par l’app, le logiciel ou la caisse : « 1 passage », ou « montant X € », ou « N points ». |

Donc : **on ne “détecte” pas le montant ni les produits.** On enregistre ce que le commerçant (ou sa caisse) envoie.

---

## Les 3 façons d’ajouter des points (côté API)

Quand on appelle `POST .../integration/scan` avec le `barcode` (ID du membre), on peut envoyer **un seul** (ou une combinaison) de :

1. **`visit: true`**  
   → « Un passage » : on ajoute les points prévus pour 1 visite (ex. 1 tampon, ou `points_per_visit`).

2. **`amount_eur: 12.50`**  
   → « Le client a dépensé 12,50 € » : le backend calcule les points (ex. 1 pt/€ → 12 points), en respectant le montant minimum si tu l’as réglé.

3. **`points: 5`**  
   → « Ajouter 5 points manuellement » (sans montant ni visite).

Le backend applique tes **règles de carte** (points/€, points/visite, tampons, etc.) à partir de ce qu’il reçoit.

---

## Qui envoie quoi aujourd’hui ?

| Où | Ce qui est envoyé | Donc on “sait” |
|----|-------------------|----------------|
| **App (Scanner)** | Pour l’instant : **uniquement `visit: true`** (pas de montant). | Uniquement « 1 passage » par scan. |
| **Logiciel (SaaS)** | Le commerçant **saisit** un montant (€) ou clique sur « 1 passage », puis valide. | Ce qu’il a tapé : montant ou 1 passage. |
| **Intégration caisse / borne** | La caisse envoie un appel API avec `barcode` + `amount_eur` (ou `visit`, ou `points`). | Ce que la caisse envoie (souvent le total payé en €). |

Donc :  
- **Montant en €** : connu seulement si **le commerçant ou la caisse** l’envoie (logiciel ou intégration).  
- **Produits (café, croissant, etc.)** : **on ne les gère pas**. On peut seulement enregistrer un **total en €** ou « 1 passage ». Si tu veux du détail produit plus tard, il faudrait une évolution (champs ou structure dédiés).

---

## Ce dont on a vraiment besoin

Pour faire tourner la fidélité comme aujourd’hui :

- **Identifier le client** → QR scanné (OK).
- **Décider quoi créditer** → soit :
  - **« 1 passage »** (tampon ou points par visite),  
  - soit **« X € dépensés »** (points calculés avec tes règles),  
  - soit **« N points »** en direct.
- **Qui donne l’info** : le **commerçant** (saisie dans l’app ou le logiciel) ou la **caisse** (via l’API d’intégration).

Donc on n’a **pas besoin** que le système “devine” le panier : il a besoin que **quelqu’un envoie** soit un passage, soit un montant, soit des points.

---

## Idée d’évolution côté app

Aujourd’hui, dans l’app, au scan on envoie toujours **1 passage** uniquement.  
Si tu veux que le commerçant puisse aussi créditer selon le montant :

- Après un scan réussi, afficher un champ **« Montant (€) »** (optionnel) et un bouton du type **« 1 passage »**.
- Si montant saisi → appeler l’API avec `amount_eur` (et éventuellement `visit: false`).
- Si « 1 passage » → garder l’actuel `visit: true`.

Comme ça, depuis l’app aussi, **on sait combien d’euros le client a dépensé** uniquement parce que **le commerçant l’a saisi** (ou que la caisse l’envoie via l’intégration).
