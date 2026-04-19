# Personnalisation des cartes fidélité — Ce qu’on peut modifier

Ce doc résume **tout ce qui est modifiable aujourd’hui** (app + SaaS + pass Wallet) et **ce qu’on peut ajouter** pour des designs avancés.

---

## 1. Ce qu’on peut modifier aujourd’hui

### 1.1 Couleurs (app + SaaS + pass)

| Élément | Où le modifier | Pass Wallet |
|--------|----------------|-------------|
| **Couleur principale (fond de la carte)** | App « Ma carte » → Couleurs ; SaaS Personnaliser → Fond | Oui |
| **Couleur du bandeau** (sans image de fond) | App « Couleur du bandeau » ; SaaS « Bandeau (sans image de fond) » | Oui |
| **Couleur des points / tampons** (accent) | App « Couleur des points » ; SaaS « Texte » | Utilisée pour les libellés / contrastes |
| **Couleur des labels** (texte secondaire) | SaaS « Labels » | Oui (pass) |

### 1.2 Images (app + SaaS + pass)

| Élément | Où le modifier | Pass Wallet |
|--------|----------------|-------------|
| **Logo** | App / SaaS : upload image | Oui (strip + icône notification) |
| **Image de fond de carte** (bandeau personnalisé) | App / SaaS : upload ou suppression | Oui (remplace la couleur du bandeau) |
| **Icône des tampons** | App : choix emoji/icône (☕, 🍕, etc.) ; fichiers dans `backend/assets/icons/` | Oui (grille tampons sur le strip) |

### 1.3 Textes et contenu (backend + réglages)

| Élément | Modifiable comment | Pass Wallet |
|--------|--------------------|-------------|
| **Nom du commerce** | App / SaaS : « Nom de la carte » | Oui (organisationName + affichage) |
| **Libellé récompense tampons** | App / SaaS : « Récompense (tampons) » (ex. « 10 tampons = 1 café offert ») | Oui (secondaryFields) |
| **Palier de points** | App / SaaS : « Paliers de récompenses » (ex. « 50 pts = café, 100 pts = croissant ») | Oui (secondaryFields + dos de la carte) |
| **Niveau** (ex. « Débutant ») | Calculé côté backend (getLevel) | Oui (champ NIVEAU) |
| **Nom du membre** | Saisi à la création de la carte | Oui (header ou MEMBRE) |
| **Texte sous les infos** | Fixe : « Touchez (i) en bas à droite… » | Oui |
| **Dos de la carte** | Conditions (back_terms), Contact (back_contact), lien « Voir en ligne » | Oui (backFields) |

### 1.4 Structure / format de la carte

| Élément | Où le modifier | Pass Wallet |
|--------|----------------|-------------|
| **Type de programme** | App / SaaS : Points **ou** Tampons | Oui (layout différent) |
| **Nombre de tampons pour la récompense** | App / SaaS : « Nombre de tampons pour la récompense » | Oui (grille + textes) |
| **Template visuel** | Implicite (classic, cafe, fastfood, etc.) selon secteur / type | Oui (strip + couleurs template) |

### 1.5 Alignement des champs (pass uniquement)

- **primaryFields** (ex. le chiffre des points) : `textAlignment: "PKTextAlignmentCenter"` (déjà en place).
- **secondaryFields** : on peut mettre `PKTextAlignmentLeft`, `PKTextAlignmentCenter`, `PKTextAlignmentRight`, `PKTextAlignmentNatural`.
- **headerFields** (nom du membre en mode secteur) : `PKTextAlignmentRight` déjà utilisé.

Donc **on peut déjà changer l’alignement** des blocs de texte (gauche / centre / droite) en modifiant le backend.

---

## 2. Ce qu’Apple Wallet (pass) impose ou permet

### 2.1 Polices

- **Polices personnalisées** : **non**. Le pass est rendu par le système avec les polices système. On ne peut pas envoyer une police custom (pas de clé `font` dans les champs).
- **Style des nombres** : Apple prévoit `numberStyle` (ex. décimal, pourcentage) pour les champs de type nombre. On peut l’utiliser pour le chiffre des points si on veut un rendu « nombre » explicite.
- En pratique : **on ne peut pas modifier la police ni la taille du texte** dans le pass. Seul le **contenu** (label, value) et l’**alignement** sont sous notre contrôle.

### 2.2 Taille des textes

- **Non modifiable** dans le pass. iOS choisit les tailles selon le type de champ (primary = plus gros, secondary/auxiliary = plus petit).

### 2.3 Emplacements des textes

- Les **emplacements** sont fixés par le type de pass (storeCard) et par l’ordre des champs :
  - **headerFields** : en haut (ex. nom du membre).
  - **primaryFields** : zone principale (ex. « 42 » + label « Points »).
  - **secondaryFields** : en dessous (ex. « Récompenses », « Paliers en magasin »).
  - **auxiliaryFields** : à droite de la zone principale (ex. « Membre » + nom).
- On **ne peut pas** placer un champ à des coordonnées libres (pas de x/y). On peut seulement :
  - Changer **l’ordre** des champs dans chaque groupe.
  - Changer **l’alignement** (gauche / centre / droite).
  - Choisir **quel champ** est en primary / secondary / auxiliary.

Donc **emplacements = ordre + alignement**, pas de position pixel.

### 2.4 Images

- **Strip** (bandeau) : une seule image en haut (ou couleur unie qu’on génère). On peut donc :
  - Soit une **image de fond** (uploadée).
  - Soit une **couleur unie** (couleur du bandeau).
- **Logo** : une image logo (affichée sur le strip).
- **Icône** : une image pour les notifications (dérivée du logo).
- Pas d’image « libre » au milieu du pass : tout passe par strip + champs texte.

---

## 3. Ce qu’on peut ajouter côté app / SaaS / backend (sans changer Apple)

### 3.1 Déjà faisable sans changement Apple

- **Libellés personnalisables** :  
  - Remplacer « Points » par un libellé custom (ex. « Étoiles », « Jetons »).  
  - Remplacer « Récompenses » / « Paliers en magasin » par un texte configurable.
- **Alignement des champs** :  
  - Exposer dans le SaaS / app : « Aligner le chiffre des points » (gauche / centre / droite), idem pour les lignes secondaires, et refléter ça dans le pass.
- **Ordre des champs** :  
  - Proposer 2–3 layouts (ex. « Points en premier » vs « Membre en premier ») en jouant sur primary/secondary/auxiliary.
- **Texte du dos de la carte** :  
  - Déjà modifiable (conditions, contact) ; on peut ajouter un champ « Message personnalisé » ou « Titre du dos ».
- **Couleur de la carte** :  
  - Déjà très flexible (fond + bandeau + labels). On peut ajouter une « couleur d’accent » dédiée aux boutons / liens si on étend le back.

### 3.2 Prévisualisation dans l’app (hors pass)

- **Tailles de texte** : Dans `WalletCardPreview` / `CafeDesArtsCardPreview` on utilise des `PassFontSize` (ex. primaryValue 48, primaryLabel 15). On peut :
  - Rendre ces tailles **réglables** (sliders ou presets « compact / normal / grand ») pour que la **prévisualisation** soit plus proche de ce que tu veux.
  - Ça ne changera pas le pass Wallet (iOS impose ses tailles), mais ça permet de **créer des designs « type carte »** dans l’app (export image, partage, etc.) avec des polices et tailles personnalisées.
- **Polices (prévisualisation uniquement)** :  
  - Dans l’app, on peut proposer le choix de la **police** (system, rounded, serif, etc.) et de la **taille** pour l’aperçu. Idéal pour des visuels « incroyables » à partager ou à afficher en dehors du Wallet.

### 3.3 Idées « designs incroyables » réalisables

1. **Thèmes / presets**  
   - Pack de couleurs + libellés (ex. « Café vintage », « Fast-food », « Spa ») avec bandeau + fond + labels cohérents.

2. **Bandeau 100 % image**  
   - Déjà possible : image de fond de carte = bandeau personnalisé (logo + visuel). Tu peux donc avoir des bandeaux très travaillés.

3. **Textes et libellés 100 % custom**  
   - Champs backend : « Label du chiffre » (au lieu de « Points »), « Ligne 1 / 2 / 3 » sous les points, « Message sous le QR », etc. Pour des cartes très marquées (nom de programme, slogan).

4. **Prévisualisation « design studio »**  
   - Dans l’app : réglages police + taille + alignement + couleurs pour l’**aperçu** uniquement, avec export image ou partage. Le pass Wallet reste conforme Apple, mais tu offres un outil de création visuelle en plus.

5. **Plus de champs au dos**  
   - Ajouter des backFields (ex. « Comment ça marche », « Valable dans », « Code promo ») pour des cartes plus riches.

---

## 4. Résumé rapide

| Souhait | Pass Wallet | App / SaaS (prévisualisation) |
|--------|-------------|-------------------------------|
| Changer la **police** | Non (système uniquement) | Oui (à ajouter) |
| Changer la **taille du texte** | Non (système) | Oui (à ajouter pour l’aperçu) |
| Changer les **couleurs** | Oui (déjà en place) | Oui |
| Changer les **images** (logo, bandeau, icônes) | Oui (déjà en place) | Oui |
| Changer les **textes / libellés** | Oui (partiellement ; extensible) | Oui |
| Changer l’**alignement** des textes | Oui (à brancher dans les champs) | Oui (à exposer) |
| Changer l’**ordre** des zones (primary/secondary/auxiliary) | Oui (en modifiant le backend) | Oui (en cohérence avec le pass) |
| Position **libre** (x/y) des textes | Non | Possible dans une vue « design » custom (hors pass) |

En résumé : **couleurs, images, textes et alignement** = modifiables et extensibles pour des designs très soignés ; **police et taille dans le pass** = non, mais on peut te proposer une **prévisualisation riche** (police, taille, disposition) dans l’app pour créer des visuels « incroyables » en plus du pass Wallet.
