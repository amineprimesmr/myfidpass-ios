# Sync app ↔ SaaS & authentification

L’app fonctionne **uniquement** avec l’API réelle (https://api.myfidpass.fr). Aucun mode démo ni données simulées. Voir `POUR_QUE_TOUT_FONCTIONNE.md` et `CONTRAT_API_LOGICIEL.md` pour ce que le backend doit exposer.

---

## Erreur « Réseau: cancelled »

Cette erreur apparaissait quand une requête de **synchronisation était annulée** (changement d’onglet rapide, pull-to-refresh pendant une sync, app en arrière-plan). Ce n’est **pas** un problème de connexion au SaaS.

**Comportement actuel** : l’app **n’affiche plus** cette erreur. Les annulations de requêtes sont ignorées silencieusement. Seules les vraies erreurs (pas de réseau, serveur injoignable, 401, etc.) sont montrées.

---

## Comment la synchronisation fonctionne

### Sens SaaS → App (ce qui se passe dans le SaaS se retrouve dans l’app)

1. **À l’ouverture de l’app** (après connexion), une sync automatique est lancée : `GET /api/auth/me` puis pour ton commerce `GET /api/businesses/:slug/dashboard/settings`, `stats`, `members`, `transactions`.
2. **Au pull-to-refresh** sur le Tableau de bord ou le Profil, la même sync est relancée.
3. Les données reçues sont **fusionnées en local** (Core Data) : nom du commerce, paramètres de la carte (couleurs, nom), **membres**, **transactions** (scans). Le dashboard affiche ces données (cartes actives, scans du jour, activité récente, liste des membres).

Donc **si tu modifies ton compte ou tes données dans le SaaS** (nouveau membre, changement de nom, etc.), **ça apparaît dans l’app** dès que :
- tu rouvres l’app, ou  
- tu tires pour actualiser le Tableau de bord (ou le Profil).

### Sens App → SaaS (ce que l’app envoie au SaaS)

- **Connexion** : login (email, Apple, Google) → token stocké, slug du commerce récupéré via `/api/auth/me`.
- **Scan** : quand tu scannes une carte, l’app envoie directement **POST /api/businesses/:slug/integration/scan** avec le code. Le SaaS enregistre le passage / les points. Ensuite un pull-to-refresh (ou la prochaine sync) met à jour les stats et l’activité dans l’app.
- **Modifications « Ma Carte »** (nom, couleurs, logo, tampons) : enregistrées en **local** pour l’instant. Pour qu’elles remontent dans le SaaS, le backend doit exposer un endpoint (ex. PATCH dashboard/settings ou card-template) et l’app devra l’appeler à l’« Enregistrer ».

---

## Ce qui est branché aujourd’hui

| Fonctionnalité | App | SaaS (à fournir) |
|----------------|-----|-------------------|
| Connexion email / Apple | ✅ | POST /api/auth/login, /api/auth/apple, réponse avec `token` + `businesses` |
| Données du commerce (nom, stats, membres, transactions) | ✅ Pull (sync) | GET /api/auth/me, GET /api/businesses/:slug/dashboard/* |
| Scan carte → enregistrement | ✅ | POST /api/businesses/:slug/integration/scan |
| Profil commerçant (nom, email, tél) | ✅ Affichage + sauvegarde locale | Optionnel : PATCH pour renvoyer les modifs au SaaS |
| Ma Carte (design, logo) | ✅ Affichage + sauvegarde locale | Optionnel : PATCH pour renvoyer au SaaS |
| Pass Apple Wallet (tester la carte) | ✅ Bouton + affichage feuille Apple | GET /api/businesses/:slug/wallet-pass retourne un .pkpass |
| Notifications push | ✅ Permission + envoi du token | POST /api/device/register avec le device token |
| Connexion Google | 🔜 Bouton « Bientôt disponible » | POST /api/auth/google quand SDK intégré |

---

## Règles métier

- **Connexion** : autorisée **uniquement** si le compte existe déjà dans le SaaS (sinon message + lien myfidpass.fr).
- **Création de compte** : sur **myfidpass.fr** ; l’app ne fait qu’ouvrir le site.
- Les **modifications faites dans le SaaS** (membres, scans, paramètres) sont visibles dans l’app après une **sync** (ouverture de l’app ou pull-to-refresh).

---

## En résumé

- L’erreur **« Réseau: cancelled »** est masquée ; seules les vraies erreurs réseau/serveur s’affichent.
- L’app **est bien synchronisée avec le SaaS** pour : connexion, récupération du commerce (auth/me + dashboard), membres, transactions, scan. Les changements côté SaaS apparaissent dans l’app après une sync.
- Ce qui peut manquer côté « prêt » : 1) que le **backend** expose tous ces endpoints avec les bons formats (voir `CONTRAT_API_LOGICIEL.md`) ; 2) remonter les modifs « Ma Carte » et « Profil » vers le SaaS si tu le souhaites (endpoints PATCH à ajouter côté API + app).
