# Plan d'action — Réponse au refus Apple (Guideline 2.1)

**Document principal à jour (texte prêt à coller + checklist + correctifs code) :**  
→ **`Docs/APP_STORE_CONNECT_REPONSE_EXAMEN.md`**

Ce fichier garde le contexte historique. Le message d’Apple demande surtout des **informations dans App Review Information** et une **vidéo sur appareil réel** — ce n’est en général **pas** un rejet définitif pour bug.

---

## Ce qu’Apple demande réellement

Apple ne dit pas que l’app est buguée ou non conforme. Il demande des **informations** pour comprendre l’app et pouvoir la tester correctement. Sans ces éléments, la revue ne peut pas aller jusqu’au bout.

---

## 1. Vidéo de démonstration (obligatoire)

**À faire :** Enregistrer une vidéo sur un **iPhone physique** (pas simulateur) montrant :

| Étape | Contenu à montrer |
|-------|-------------------|
| 1 | Lancement de l’app |
| 2 | **Inscription** : bouton « Créer un compte » → ouverture de myfidpass.fr (ou flux complet si possible) |
| 3 | **Connexion** : email/mot de passe ou Sign in with Apple / Google |
| 4 | **Parcours principal** : tableau de bord, scan d’une carte, Ma Carte, Profil |
| 5 | **Déconnexion** : Profil → Se déconnecter |
| 6 | **Suppression de compte** : si disponible (voir section 2) |
| 7 | **Abonnement** : si l’app affiche ou accède à du contenu payant (voir section 3) |
| 8 | **Permissions** : montrer les prompts caméra, localisation, photos si l’app les demande |

**Format :** MP4 ou MOV, durée 1–3 minutes, enregistrement direct depuis l’iPhone (Centre de contrôle → Enregistrement d’écran).

**Où l’ajouter :** App Store Connect → Ton app → Version 1.0 → **App Review Information** → champ **Notes** (ou pièce jointe si possible).

---

## 2. Suppression de compte (Account deletion)

**Constat :** L’app propose uniquement une **déconnexion** (logout). Apple exige un moyen de **supprimer le compte** pour les apps avec création de compte.

**Options :**

### Option A — Lien vers le site (rapide)
- Ajouter dans **Profil** un lien « Supprimer mon compte » qui ouvre une page sur myfidpass.fr (ex. `/supprimer-compte` ou `/parametres-compte`).
- Cette page doit permettre de demander la suppression du compte (formulaire ou bouton).
- Documenter ce flux dans les Notes pour Apple.

### Option B — Endpoint API + flow in-app (idéal)
- Créer `DELETE /api/auth/account` ou équivalent côté fidelity.
- Ajouter dans l’app un bouton « Supprimer mon compte » avec confirmation et appel API.
- Plus conforme aux attentes Apple.

**Action recommandée :** Au minimum Option A pour la prochaine soumission. Option B à planifier.

---

## 3. Abonnements (Guideline 3.1.2)

**Constat :** Les abonnements sont gérés sur **myfidpass.fr** (Stripe), pas dans l’app iOS. L’app ne propose pas d’achats in-app.

**À faire :**
- Si l’app affiche ou restreint des fonctionnalités selon l’abonnement : s’assurer que les infos d’abonnement (titre, durée, prix, CGU, politique de confidentialité) sont accessibles depuis le site.
- Dans les Notes pour Apple : préciser que « Les abonnements sont gérés sur le site myfidpass.fr. L’app iOS ne propose pas d’achats in-app. »

---

## 4. Texte à fournir dans App Store Connect

À coller dans le champ **Notes** de la section **App Review Information** :

---

### 1. Description de l’app (purpose, problème, valeur)

```
MyFidpass est une application pour commerçants qui souhaitent fidéliser leurs clients avec des cartes dans l'Apple Wallet.

Problème : Les cartes fidélité papier sont perdues, oubliées ou peu pratiques. Les solutions logicielles existantes sont souvent complexes ou coûteuses.

Valeur : MyFidpass permet aux commerçants de créer une carte fidélité (tampons ou points), de la personnaliser (logo, couleurs), et de la distribuer à leurs clients via un lien. Les clients ajoutent la carte dans l'Apple Wallet. Le commerçant scanne le QR code à chaque passage pour enregistrer les achats et gérer les récompenses. L'app affiche le tableau de bord, la liste des membres et permet d'envoyer des notifications aux clients.
```

---

### 2. Instructions pour accéder aux fonctionnalités + identifiants de test

```
ACCÈS AUX FONCTIONNALITÉS PRINCIPALES :

1. Connexion : L'app affiche un écran d'accueil avec « Se connecter » et « Créer un compte ». La création de compte se fait sur le site myfidpass.fr. Une fois le compte créé, revenir dans l'app pour se connecter (email/mot de passe, Sign in with Apple, ou Google).

2. Compte de test pour la revue :
   Email : [À REMPLIR — ex. review@myfidpass.fr]
   Mot de passe : [À REMPLIR]

3. Parcours après connexion :
   - Tableau de bord : statistiques, membres, scans du jour
   - Scanner : bouton « Scanner » pour lire le QR code d'une carte client
   - Ma Carte : personnalisation du design (logo, couleurs, tampons)
   - Profil : informations de l'établissement, notifications, déconnexion

4. Déconnexion : Profil → « Se déconnecter » → confirmation
```

**Important :** Créer un compte de test dédié à la revue Apple et le maintenir actif. Si l’app a plusieurs types de comptes, fournir des identifiants pour chacun.

---

### 3. Liste des services externes

```
SERVICES EXTERNES UTILISÉS :

- Authentification : API MyFidpass (api.myfidpass.fr) — login email/mot de passe, Sign in with Apple, OAuth Google
- Données : API MyFidpass — tableau de bord, membres, transactions, paramètres de carte
- Paiements / Abonnements : Stripe (géré sur le site myfidpass.fr, pas d'achats in-app)
- Cartes Wallet : Apple Wallet (PassKit) — génération et mise à jour des passes
- Notifications : APNs (Apple Push Notification service) pour les alertes commerçant
- Localisation : Core Location — pour définir l'emplacement du commerce dans le pass (Relevant locations)
- Pas de services IA ou de fournisseurs de données tiers supplémentaires
```

---

### 4. Différences régionales

```
L'app fonctionne de manière identique dans toutes les régions où elle est disponible. Aucune différence de contenu ou de fonctionnalités selon la localisation.
```

---

### 5. Industrie réglementée

```
L'app n'opère pas dans une industrie fortement réglementée (santé, finance, etc.). Il s'agit d'un outil de fidélisation client pour commerçants.
```

---

## 5. Captures d’écran (Guideline 2.3.3)

**Règle Apple :** Les captures doivent montrer l’**app en utilisation**, pas uniquement l’écran de connexion ou le splash.

**À vérifier :**
- Au moins une capture du tableau de bord (connecté)
- Une capture du scanner ou de Ma Carte
- Pas de capture qui ne montre que l’écran de login

---

## 6. Chaînes de justification des permissions (Guideline 5.1.1)

Chaque permission doit avoir une description claire et complète. Actuellement dans l’app :

| Permission | Chaîne actuelle | Statut |
|------------|-----------------|--------|
| Localisation | « MyFidpass utilise votre position pour définir l'emplacement de votre commerce sur la carte et le périmètre de notification des clients. » | ✅ Correct |
| Caméra | « Pour scanner les cartes de fidélité des clients » | ⚠️ Peut être enrichie |
| Photos | « Pour choisir le logo et l'image de fond de votre carte de fidélité » | ✅ Correct |

**Suggestion pour la caméra :**  
« MyFidpass utilise la caméra pour scanner le QR code des cartes fidélité de vos clients lors de leurs passages en caisse, afin d'enregistrer les achats et les points. »

---

## 7. Checklist avant re-soumission

- [ ] Vidéo de démonstration enregistrée sur iPhone physique
- [ ] Compte de test créé et identifiants fournis dans les Notes
- [ ] Texte complet (1 à 5 ci-dessus) collé dans App Review Information → Notes
- [ ] Captures d’écran montrant l’app en utilisation (pas seulement login)
- [ ] Suppression de compte : au minimum un lien vers le site
- [ ] Chaîne caméra enrichie si souhaité (optionnel mais recommandé)
- [ ] Test sur appareil physique (TestFlight ou build direct)
- [ ] Vérification que l’app ne crash pas au lancement

---

## 8. Ordre des actions recommandé

1. **Créer le compte de test** pour Apple (email + mot de passe).
2. **Enregistrer la vidéo** sur iPhone physique (connexion, parcours, déconnexion).
3. **Ajouter le lien « Supprimer mon compte »** dans le Profil (vers myfidpass.fr) si pas encore fait.
4. **Rédiger et coller** tout le texte dans App Store Connect → App Review Information → Notes.
5. **Vérifier les captures** et les remplacer si nécessaire.
6. **Re-soumettre** pour examen.

---

## Résumé

Apple demande des **informations**, pas des corrections de bugs. En fournissant la vidéo, les identifiants de test, la description de l’app, la liste des services et les instructions dans les Notes, la revue pourra reprendre et aboutir.
