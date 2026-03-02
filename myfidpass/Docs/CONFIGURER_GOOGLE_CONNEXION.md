# Configurer la connexion Google — guide pas à pas

Pour que le bouton **« Continuer avec Google »** fonctionne dans l’app et sur le site, il faut configurer un projet Google et des variables d’environnement. Suis ces étapes dans l’ordre.

---

## Étape 1 : Ouvrir les identifiants dans Google Cloud

1. Tu es déjà sur la console Google Cloud, projet **Myfidpass**.
2. Dans le menu de gauche (ou dans **Accès rapide**), clique sur **« API et services »**.
3. Dans le sous-menu, clique sur **« Identifiants »** (Credentials).

---

## Étape 2 : Créer un client OAuth (ou le modifier)

- Si tu n’as **pas encore** de client OAuth pour le site MyFidPass :
  1. Clique sur **« + Créer des identifiants »**.
  2. Choisis **« ID client OAuth »**.
  3. Si on te demande de configurer l’écran de consentement OAuth, valide les infos demandées (nom de l’app, email de support, etc.), puis reviens aux Identifiants.
- Si tu as **déjà** un client OAuth (type « Application Web ») :
  1. Clique dessus pour l’ouvrir et passer à l’étape 3.

---

## Étape 3 : Type d’application = « Application Web »

1. Type d’application : **« Application Web »**.
2. Donne-lui un nom, par exemple : **MyFidPass Web + App**.

---

## Étape 4 : Origines JavaScript autorisées (pour le site)

Dans **« Origines JavaScript autorisées »**, ajoute (une ligne par URL) :

- `https://myfidpass.fr`
- En dev local : `http://localhost:5173` (optionnel)

---

## Étape 5 : URI de redirection autorisés (pour l’app iOS)

Dans **« URI de redirection autorisés »**, ajoute **exactement** cette ligne :

```
https://api.myfidpass.fr/api/auth/google-oauth-callback
```

- Si ton API est ailleurs (ex. `https://ton-api.railway.app`), remplace par :
  `https://ton-api.railway.app/api/auth/google-oauth-callback`

Enregistre (Créer ou Enregistrer).

---

## Étape 6 : Récupérer le Client ID et le Secret

Une fois le client créé ou modifié :

1. Tu vois **« ID client »** (quelque chose comme `123456789-xxx.apps.googleusercontent.com`) → **copie-le**.
2. Tu vois **« Secret client »** → clique sur « Afficher » ou l’icône copier, puis **copie-le** aussi.  
   (Si tu ne vois pas le secret, c’est peut-être un ancien client : crée un **nouveau** client OAuth « Application Web » pour avoir un secret.)

Tu en auras besoin pour l’étape 7.

---

## Étape 7 : Mettre les valeurs dans Railway (backend)

1. Ouvre **Railway** → ton projet → le **service backend** (API).
2. Onglet **Variables** (ou **Variables d’environnement**).
3. Ajoute ou modifie :

| Nom de la variable   | Valeur à coller |
|----------------------|------------------|
| `GOOGLE_CLIENT_ID`   | L’**ID client** copié à l’étape 6 |
| `GOOGLE_CLIENT_SECRET` | Le **Secret client** copié à l’étape 6 |
| `API_URL`            | `https://api.myfidpass.fr` (ou l’URL réelle de ton API sur Railway) |

4. Sauvegarde. Railway redémarre le backend tout seul.

---

## Étape 8 : Mettre le Client ID dans Vercel (site web)

1. Ouvre **Vercel** → ton projet (frontend myfidpass).
2. **Settings** → **Environment Variables**.
3. Ajoute ou modifie :

| Nom                    | Valeur |
|------------------------|--------|
| `VITE_GOOGLE_CLIENT_ID` | Le **même** ID client qu’à l’étape 6 |

4. Sauvegarde et redéploie le frontend si besoin.

---

## Résumé rapide

- **Google Cloud** : client OAuth « Application Web » avec :
  - Origines JS : `https://myfidpass.fr`
  - URI de redirection : `https://api.myfidpass.fr/api/auth/google-oauth-callback`
- **Railway** : `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `API_URL`
- **Vercel** : `VITE_GOOGLE_CLIENT_ID`

Une fois tout ça fait, le bouton « Continuer avec Google » doit fonctionner sur le site et dans l’app (après redéploiement / réinstall de l’app si besoin).

---

## En cas de problème

- **« Connexion Google non configurée »** ou **« Bientôt disponible »**  
  → Vérifie que `GOOGLE_CLIENT_ID` et `GOOGLE_CLIENT_SECRET` sont bien définis sur Railway et que l’app pointe vers la bonne API.

- **Erreur après avoir cliqué sur Google dans l’app**  
  → Vérifie que l’URI de redirection dans Google Cloud est **exactement** :
  `https://api.myfidpass.fr/api/auth/google-oauth-callback`  
  (même protocole, pas d’espace, pas de slash à la fin).

- **Ça marche sur le site mais pas dans l’app**  
  → Vérifie `API_URL` sur Railway (doit être l’URL publique de ton API, ex. `https://api.myfidpass.fr`).
