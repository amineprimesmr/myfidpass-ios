# Pour que tout fonctionne réellement

Ce document décrit **ce que l’app fait vraiment** (sans démo ni simulé) et **tout ce qu’il faut faire côté backend** pour que chaque fonction marche.

**Checklist complète (Apple Developer + Xcode + Backend) :** voir **`CHECKLIST_APPLE_ET_BACKEND.md`** — tout y est listé (App ID, Sign in with Apple, Push Notifications, Pass Type ID, endpoints backend). Si tu vois encore un message contenant « Mode démo » sur le bouton Wallet, fais un **Clean Build** puis **Run** pour être sûr d’avoir la dernière version du code (ce message a été supprimé ; l’app affiche maintenant « Configurez le pass depuis votre espace en ligne » en cas de 404).

---

## 1. Ce que fait l’app (côté mobile)

L’app est une **app commerçant** : le commerçant se connecte, voit son tableau de bord, scanne les cartes fidélité (QR) de ses clients, personnalise sa carte (Ma Carte), gère son profil et peut envoyer des notifications aux clients. Tout est branché sur l’API **https://api.myfidpass.fr** : **aucune donnée en dur, aucun mode démo**. Si l’API ne répond pas ou renvoie une erreur, la fonction concernée échoue.

| Écran / action | Comportement réel |
|----------------|-------------------|
| **Connexion** | Email/mot de passe ou Sign in with Apple → `POST /api/auth/login` ou `POST /api/auth/apple`. Réponse 200 avec `token` + `businesses` (au moins un commerce avec `slug`) → session ouverte. 404 → « Créez votre compte sur myfidpass.fr ». |
| **Ouverture de l’app / pull-to-refresh** | `GET /api/auth/me` pour récupérer le slug du commerce, puis 4 appels en parallèle : `GET .../dashboard/settings`, `.../stats`, `.../members`, `.../transactions`. Les données sont fusionnées en local (Core Data) et affichées au tableau de bord. |
| **Scanner une carte** | Le commerçant scanne le QR code → l’app envoie le code à `POST /api/businesses/:slug/integration/scan`. Réponse 200 → affichage du nom du client et des points ajoutés, puis sync pour mettre à jour le dashboard. 404 → « Code non reconnu ». |
| **Ma Carte** | Aperçu en direct de la carte (design, couleurs, logo). Les modifications sont sauvegardées en **local** (Core Data). Le bouton « Tester dans l’Apple Wallet » appelle `GET /api/businesses/:slug/wallet-pass` ; si le backend renvoie un .pkpass, l’app affiche la feuille Apple pour ajouter le pass au Wallet. 404 → message « Configurez le pass depuis votre espace en ligne ». |
| **Profil** | Affichage et édition du nom, email, tél, adresse (sauvegarde locale). Section « Notifier vos clients » → `POST /api/businesses/:slug/notify` avec le message saisi. Section localisation : l’adresse est celle renvoyée par `.../dashboard/settings` (`location_address`) et sert à expliquer les « relevant locations » PassKit (pass sur l’écran de verrouillage près du commerce). |
| **Notifications (pour le commerçant)** | Demande de permission + enregistrement du token APNs → `POST /api/device/register` avec le `device_token`. |

En résumé : **connexion, sync, scan, wallet, notifications** dépendent **à 100 %** des réponses du backend. Pas de fallback « démo » ou simulé.

---

## 2. Ce que le backend doit implémenter (checklist)

Le backend (api.myfidpass.fr) doit exposer les endpoints suivants avec les **méthodes, chemins et formats** décrits dans **`CONTRAT_API_LOGICIEL.md`**. Tout écart (mauvais chemin, body/réponse différent) fera échouer la fonction correspondante.

### Obligatoire pour une utilisation minimale

| Endpoint | Rôle |
|----------|------|
| `POST /api/auth/login` | Connexion email/mot de passe. Réponse 200 : `token`, `user`, `businesses` (au moins un objet avec `slug`). 404 = pas de compte → message myfidpass.fr. |
| `GET /api/auth/me` | Donne `user` + `businesses` (avec `slug`). Utilisé à chaque sync. |
| `GET /api/businesses/:slug/dashboard/settings` | Nom, couleurs, adresse du commerce. |
| `GET /api/businesses/:slug/dashboard/stats` | Stats (membres, points, transactions, etc.). |
| `GET /api/businesses/:slug/dashboard/members` | Liste des membres (id, name, email, points, dates). |
| `GET /api/businesses/:slug/dashboard/transactions` | Liste des transactions (scans, points, etc.). |
| `POST /api/businesses/:slug/integration/scan` | Enregistre un scan (barcode). Réponse : member + points_added / new_balance. 404 si code inconnu. |

Sans ces 7 points, au moins une des fonctions de base (connexion, tableau de bord, scan) ne fonctionnera pas.

### Pour les autres fonctions

| Endpoint | Rôle |
|----------|------|
| `POST /api/auth/apple` | Connexion Sign in with Apple. Body : `id_token`, `name`, `email`. Même format de réponse que login. |
| `POST /api/device/register` | Enregistrer le token APNs du commerçant (notifications vers son téléphone). |
| `GET /api/businesses/:slug/wallet-pass` | Retourner le fichier .pkpass (binaire). 404 si pass non configuré. |
| `POST /api/businesses/:slug/notify` | Envoyer un message aux clients (push / changeMessage PassKit). |

---

## 3. Étapes concrètes pour que « tout fonctionne »

1. **Vérifier l’URL de l’API**  
   Dans l’app : `APIConfig.baseURL` = `https://api.myfidpass.fr`. En DEBUG, tu peux surcharger avec la variable d’environnement `MYFIDPASS_API_URL` (ex. pour un backend local).

2. **Implémenter les 7 endpoints obligatoires** (voir tableau ci‑dessus) en respectant **exactement** les chemins et formats du fichier **`CONTRAT_API_LOGICIEL.md`** (body et réponses en **snake_case**, dates ISO8601, etc.).

3. **S’assurer que login et auth/me renvoient au moins un commerce**  
   L’app utilise `businesses[0].slug` pour tous les appels suivants. Si `businesses` est vide, le tableau de bord, le scan, le wallet et les notifications ne pourront pas fonctionner (slug manquant).

4. **Scanner**  
   Le QR code scanné par l’app est envoyé dans `barcode`. Le backend doit reconnaître ce code (ex. identifiant de la carte client) et renvoyer les infos du membre + points. Si le code n’existe pas pour ce commerce → 404.

5. **Apple Wallet**  
   Pour que le bouton « Tester dans l’Apple Wallet » fonctionne : le backend doit générer et servir le fichier .pkpass à `GET /api/businesses/:slug/wallet-pass` (Content-Type recommandé : `application/vnd.apple.pkpass`). Si le pass n’est pas encore configuré pour ce commerce → 404 (l’app affiche alors le message « Configurez le pass depuis votre espace en ligne »).

6. **Notifications**  
   - Commerçant : `POST /api/device/register` avec le token APNs.  
   - Clients : `POST /api/businesses/:slug/notify` avec le message ; le backend envoie les push / met à jour le pass (changeMessage) côté PassKit.

7. **Tester**  
   - Connexion (email ou Apple) → vérifier que le token et le slug sont bien reçus.  
   - Pull-to-refresh sur le tableau de bord → pas d’erreur, données cohérentes.  
   - Scan d’un QR code valide → succès et mise à jour du dashboard.  
   - Bouton « Tester dans l’Apple Wallet » → téléchargement du .pkpass et affichage de la feuille Apple.  
   - Envoi d’un message « Notifier vos clients » → 200/204 et envoi côté backend.

---

## 4. En résumé

- **L’app ne simule rien** : tout passe par l’API.
- **Si « rien ne fonctionne »** : en général l’API n’est pas joignable, ou les endpoints/format ne correspondent pas au contrat. Vérifier les 7 endpoints obligatoires et les formats dans `CONTRAT_API_LOGICIEL.md`.
- **Pour que chaque fonction marche** : implémenter le bon endpoint avec le bon format (paths, body, réponses) décrit dans le contrat.

Une fois le backend aligné sur ce contrat, connexion, sync, scan, profil, notifications et test Wallet fonctionnent réellement de bout en bout.
