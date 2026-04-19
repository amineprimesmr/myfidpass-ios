# Réponse App Store Connect — informations pour la revue (copier-coller)

Ce message Apple n’est **pas** un rejet pour bug : il manque des **informations dans App Store Connect** et, souvent, une **vidéo** + **compte de test**. Collez les blocs ci-dessous dans **App Store Connect → votre app → App Review Information → Notes** (et joignez la vidéo si le champ pièce jointe est disponible, ou indiquez un lien sécurisé si Apple l’accepte).

Vérifiez que les URLs **https://myfidpass.fr/cgu** et **https://myfidpass.fr/confidentialite** existent et s’affichent correctement (sinon mettez à jour `LegalURLs.swift` dans le projet).

---

## 1. Vidéo (obligatoire — enregistrer sur **iPhone physique**)

Enregistrement d’écran 1–3 min, en commençant par **l’icône de l’app** (cold start), puis dans l’ordre :

1. **Lancement** de l’app  
2. **Inscription** : onglet Connexion → segment **Inscription** → email + mot de passe → **Créer mon compte** (ou flux site via « Créer un compte sur le web »)  
3. **Connexion** : email / mot de passe **ou** Sign in with Apple / Google  
4. **Fonctions principales** : Tableau de bord, **Scanner** (autorisation **caméra**), **Ma Carte**, **Espace pro** (si abonné), **Profil**  
5. **Périmètre / carte** (si testé) : **Profil** → carte du commerce → **Utiliser ma position** (autorisation **localisation**)  
6. **Photos** : **Ma Carte** ou **Profil** → import logo (autorisation **bibliothèque photos** si demandée)  
7. **Abonnement** : **Espace pro** → **Compte pro** → bouton paiement Stripe (Safari) — montrer que le **prix / durée** apparaît sur la page Stripe  
8. **Déconnexion** : Profil → Se déconnecter  
9. **Suppression de compte** : Profil → **Supprimer mon compte** → confirmer (compte **démo uniquement**)

---

## 2. Texte à coller dans « Notes » (français)

```
DESCRIPTION DE L’APP (problème / valeur)
MyFidpass est une application pour commerçants qui fidélisent leurs clients avec des cartes numériques dans l’Apple Wallet. Elle remplace les cartes papier difficiles à conserver et centralise points ou tampons, design de carte, liste des membres et envoi de notifications aux clients ayant ajouté la carte.

INSTRUCTIONS POUR LA REVUE
1) Connexion : écran d’accueil → Se connecter. Inscription possible dans l’app (segment « Inscription ») ou via le site https://myfidpass.fr .
2) Compte de démonstration (À REMPLIR par vous avant envoi) :
   - Email : …
   - Mot de passe : …
3) Parcours : Tableau de bord → Scanner (caméra pour lire le QR du pass client) → Ma Carte (personnalisation) → Profil (établissement, notifications, périmètre, déconnexion, suppression de compte).
4) Abonnement : l’app ne propose pas d’In-App Purchase. L’abonnement se souscrit sur notre site via Stripe (bouton dans Espace pro → Compte pro). Le détail des offres (titre, durée, prix) s’affiche sur la page de paiement Stripe. Liens légaux : https://myfidpass.fr/cgu et https://myfidpass.fr/confidentialite (également accessibles dans l’app : Connexion / Inscription / Profil / Compte pro).

SERVICES EXTERNES (fonctionnalité principale)
- API backend MyFidpass (https://api.myfidpass.fr) : compte, sync commerce, membres, cartes, scans.
- Site web myfidpass.fr : création de compte, CGU, confidentialité, paiement Stripe.
- Stripe : traitement des paiements d’abonnement (hors IAP).
- Sign in with Apple et Google : authentification.
- Apple Wallet (PassKit) : distribution et mise à jour des passes ; notifications push Apple pour les mises à jour de pass (côté serveur).
- Apple Push Notification service (APNs) : notifications vers l’app / passes selon configuration serveur.

CONTENU GÉNÉRÉ PAR L’UTILISATEUR
L’app est destinée aux commerçants (B2B). Les messages de notification aux clients sont rédigés par le commerçant. Il n’y a pas de fil public de contenu UGC ; pas de fonction de signalement / blocage type réseau social (non applicable).

RÉGIONS
Fonctionnement identique dans toutes les régions ; contenu et langue principalement en français. Aucune restriction régionale de fonctionnalités dans l’app.

SECTEUR RÉGLEMENTÉ
Application outil commerçant (fidélité / carte Wallet). Pas de service financier, médical ou juridique réglementé au sens App Store. Aucun document d’agrément spécifique à fournir.

VIDÉO
Une capture d’écran vidéo sur iPhone physique est fournie (voir description du parcours ci-dessus).
```

---

## 3. English summary (optional, if your primary App Review language is English)

```
APP PURPOSE
MyFidpass helps merchants run a digital loyalty program with Apple Wallet passes: design the card, manage members, scan customer QR codes, and send notifications. It solves the problem of paper loyalty cards and fragmented tools.

HOW TO TEST
1) Sign in from the welcome screen. In-app registration is available on the Login screen (segment “Inscription”) or via https://myfidpass.fr .
2) Demo credentials (REPLACE): email … / password …
3) Core flows: Dashboard → Scanner (camera) → My Card → Profile (logout, account deletion).
4) Subscription: no In-App Purchase. Billing is via Stripe on the website; price/duration appear on Stripe’s checkout. Legal: https://myfidpass.fr/cgu and https://myfidpass.fr/confidentialité — also linked inside the app.

EXTERNAL SERVICES
MyFidpass API (api.myfidpass.fr), myfidpass.fr, Stripe, Sign in with Apple, Google Sign-In, Apple Wallet / PassKit, APNs (server-driven).

UGC / REPORTING
B2B merchant tool; no public social feed. Not applicable.

REGIONS / REGULATED INDUSTRY
Same features worldwide (French-first). Not a regulated financial/medical/legal service app.
```

---

## 4. Checklist avant renvoi

| Élément | Action |
|--------|--------|
| **Compte démo** | Créer un compte dédié `review@…` avec données factices ; mettre identifiants dans les Notes **et** dans le champ **Identifiant / mot de passe** App Review si présent. |
| **Vidéo** | Fichier court, iPhone réel, parcours complet incluant permissions. |
| **Captures App Store** | Montrer l’**app après connexion** (tableau de bord, scanner, ma carte), pas seulement l’écran de login (guideline 2.3.3). |
| **Archive Release** | Build Release ; pour les notifications push, le profil de signature App Store utilise en général **aps-environment = production** (automatique à l’archivage). |
| **Pages web légales** | `/cgu` et `/confidentialite` joignables et à jour. |

---

## 5. Modifications code réalisées pour la conformité

- **Guideline 5.1.1** : textes d’usage **caméra**, **photos** et **localisation** enrichis (Info.plist + projet Xcode).  
- **Guideline 3.1.2** : écran **Compte pro** : mention « pas d’IAP », liens **CGU** + **confidentialité** ; liens aussi **Connexion / Inscription / Profil**.  
- **Privacy manifest** : `PrivacyInfo.xcprivacy` avec déclaration **UserDefaults** (raison **CA92.1**, exemple officiel TN3183).  
- **Bug critique inscription** : le bouton principal en mode « Inscription » appelait par erreur la connexion — corrigé (`LoginView`).  
