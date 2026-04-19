# Soumettre l’app myfidpass à l’App Store

Checklist pour débloquer **« Ajouter pour vérification »** et soumettre la version 1.0.

---

## 1. Informations sur l’app (sidebar → Général → Informations sur l’app)

| À faire | Où / Comment |
|--------|----------------|
| **Classifications d’âge** | Répondre à toutes les questions (violence, contenu mature, etc.). Pour une app commerçant fidélité, en général tout à « Aucun » ou équivalent. |
| **Droits relatifs au contenu** | Cocher / remplir la section « Contenu » (ex. : « Cette app ne contient pas de contenu tiers protégé par des droits d’auteur » si c’est le cas). |
| **Informations de contact** | Renseigner email + téléphone (visible par Apple et parfois par les utilisateurs). |
| **Copyright** | Ex. : `© 2026 [Ton nom ou société]`. Obligatoire. |

---

## 2. Page de la version (App iOS 1.0) — métadonnées en français

Dans la zone **« Cette page contient une erreur ou plus »** :

| Champ obligatoire | Exemple / Conseil |
|-------------------|-------------------|
| **URL de l’assistance (Support URL)** | URL où les utilisateurs peuvent t’écrire (ex. `https://myfidpass.fr/support` ou `https://myfidpass.fr/contact`). Doit être une vraie page. |
| **Mots-clés** | Liste séparée par des virgules, sans espaces superflus (ex. `fidélité,carte,tampons,commerce,Wallet`). Max 100 caractères. |
| **Description** | Texte de présentation de l’app en français (ce que voient les utilisateurs sur la fiche App Store). 2–3 paragraphes suffisent. |

---

## 3. Aperçus et captures d’écran

| Exigence | Action |
|----------|--------|
| **iPhone** | Au moins une capture (6,7" ou 6,5" selon les tailles demandées). |
| **iPad 13 pouces** | Apple exige une capture pour iPad avec écran 13". Dans Xcode : lancer l’app sur un simulateur **iPad Pro 13"** (ou exporter depuis le simulateur), faire une capture (Cmd+S ou capture d’écran), puis l’uploader dans App Store Connect pour la taille « iPad Pro 13" ». |

Astuce : si l’app est surtout iPhone, tu peux quand même la lancer sur simulateur iPad et faire une capture de la vue iPad pour satisfaire l’obligation.

---

## 4. Confidentialité de l’app (sidebar → Confiance et sécurité → Confidentialité de l’app)

| À faire | Détail |
|--------|--------|
| **URL de la politique de confidentialité** | Page web qui explique quelles données tu collectes (email, nom, usage de l’app, etc.). Ex. : `https://myfidpass.fr/confidentialite` ou `https://myfidpass.fr/privacy`. |
| **Questionnaire sur les pratiques** | Un **administrateur** du compte doit remplir le questionnaire (types de données collectées, usage, partage avec des tiers, etc.). Sans ça, « Ajouter pour vérification » reste bloqué. |

---

## 5. Tarifs et disponibilité (sidebar → Monétisation → Tarifs et disponibilité)

| À faire | Détail |
|--------|--------|
| **Choisir un tarif** | Même si l’app est gratuite : aller dans **Tarifs et disponibilité**, sélectionner **Gratuit** (ou le pays + prix si payant). Sans tarif choisi, la soumission est refusée. |

---

## 6. Ordre recommandé

1. **Informations sur l’app** : âge, droits contenu, contact, copyright.  
2. **Confidentialité** : URL politique de confidentialité + questionnaire par un admin.  
3. **Tarifs et disponibilité** : au moins « Gratuit » pour les pays voulus.  
4. **Page version 1.0** : URL d’assistance, mots-clés, description (français).  
5. **Captures** : iPhone + **iPad 13"** (obligatoire si l’app est proposée sur iPad).  

Quand tout est vert / sans erreur, le bouton **« Ajouter pour vérification »** s’active. Ensuite tu peux **Soumettre pour examen**.

---

## 7. Exemple de texte (à adapter)

**Description (français)** — à coller / adapter dans App Store Connect :

```
MyFidpass permet aux commerçants de fidéliser leurs clients avec des cartes dans l’Apple Wallet.

• Créez votre carte fidélité (tampons ou points) et personnalisez le design.
• Vos clients ajoutent la carte sur leur iPhone en un tap.
• Scannez le QR code à chaque passage pour enregistrer les achats et les récompenses.
• Consultez votre activité et la liste des membres depuis l’app.

Connectez-vous ou créez votre compte commerçant sur myfidpass.fr pour activer votre carte.
```

**Mots-clés (exemple)** :  
`fidélité,carte fidélité,tampons,points,commerce,Wallet,client`

**URL d’assistance** :  
`https://myfidpass.fr` (ou une page dédiée contact/support si tu en as une).

**Politique de confidentialité** :  
Si tu n’as pas encore de page, crée une page simple sur myfidpass.fr (ex. `/confidentialite`) qui indique quelles données sont collectées (compte, email, données de la carte, usage de l’app) et comment elles sont utilisées.
