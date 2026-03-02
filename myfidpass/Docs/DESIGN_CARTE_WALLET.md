# Design de la carte Apple Wallet — ce qu’on peut faire

## Ce qu’Apple autorise (PassKit storeCard)

Sur un pass **storeCard**, Apple impose une structure fixe mais on peut personnaliser :

| Élément | Rôle | Contraintes | Chez nous |
|--------|------|-------------|-----------|
| **Logo** | Image en haut à gauche | 320×100 px (@2x), PNG | ✅ Logo établissement (upload / URL) |
| **Strip** | Bande derrière le contenu principal | 750×288 px recommandé, PNG | ✅ Dégradé aux couleurs du template (ou image custom possible) |
| **Icon** | Icône dans les notifications | 58×58 px | ✅ Générée (couleur du template) ou custom |
| **Couleurs** | Fond + texte | `backgroundColor`, `foregroundColor`, `labelColor` | ✅ Couleur principale + couleur des points + label |
| **Champs texte** | Infos affichées sur le pass | **Primary** (gros), **Secondary**, **Auxiliary** — label + value (texte) | ✅ Points ou Tampons, Niveau, Membre, Actualité |
| **QR / Barcode** | Code scannable | QR, PDF417, etc. | ✅ QR avec ID membre |
| **Dos du pass** | Conditions, contact, lien | Back fields + URL | ✅ Conditions, contact, lien « Voir en ligne » |
| **Localisation** | Affichage à l’approche du lieu | Jusqu’à 10 points lat/long | ✅ Si adresse commerce renseignée |

Les champs (primary, secondary, auxiliary) sont **texte uniquement** : pas d’image par champ. En revanche, la **value** peut contenir des **emoji** → on peut faire des designs stylés avec des symboles (☕ 🍔 ⭐ 🎁 etc.).

---

## Ce qu’on peut faire aujourd’hui

- **Logo** : image de l’établissement (depuis l’app ou le SaaS, URL ou import photo).
- **Couleurs** : couleur principale (fond), couleur des points/tampons, avec palettes prédéfinies (bleu, vert, violet, ambre, rouge, etc.).
- **Points ou tampons** : mode points (ex. « 42 Points ») ou tampons (ex. « 3 / 10 »).
- **Templates secteur** : café, fast-food, beauté, coiffure, boulangerie, boucherie — couleurs + textes adaptés (ex. « X cafés collectés »).
- **Texte au dos** : conditions, contact, lien cliquable vers le site.

---

## Pistes pour des cartes encore plus stylées

### 1. Emoji pour les points / tampons ✅ (prévu)

- Un **emoji choisi** par le commerce (☕ 🍔 ⭐ 🎁 🍕 🌸 etc.) affiché à côté des points ou des tampons.
- Ex. primary field : `"☕ 3"` ou `"⭐ 42 Points"`, ou en tampons `"☕☕☕ ○○○○○○○○○○"`.
- Côté technique : champ optionnel `stamp_emoji` (ou `points_emoji`) en BDD + dans les settings du dashboard ; le backend l’injecte dans la **value** du champ primary (PassKit accepte l’emoji en UTF-8).

### 2. Libellé personnalisable

- Remplacer « Points » par « Cafés », « Visites », « Tampons », « Étoiles », etc.
- Champ optionnel `points_label` (ex. `"Cafés"`) ; si vide, garder « Points » par défaut.

### 3. Strip image personnalisé

- Image **strip** custom (750×246 px) par commerce : motif, texture, photo, dégradé custom.
- Nécessite : upload dans le dashboard (ou app) → stockage (fichier ou BDD) → passage du buffer strip dans `buildBuffers` / génération du pass au lieu du dégradé actuel.

### 4. Plus de templates / thèmes

- Nouveaux jeux de couleurs (ex. « Nuit », « Pastel », « Néon ») et éventuellement libellés associés pour garder une cohérence visuelle.

### 5. Emoji dans les autres champs

- **Niveau** : ex. « ⭐ Débutant », « 🌟 Or ».
- **Actualité** : ex. « 🎉 Offre du jour : -20 % ».

Tout ça reste du **texte** dans les champs PassKit, donc pas de changement de structure du pass, seulement de contenu.

---

## Limites Apple (ce qu’on ne peut pas faire)

- Pas de **layout libre** : on ne peut pas placer des blocs d’image ou de texte où on veut.
- Pas d’**image par champ** : les champs sont label + value texte (avec emoji possible).
- Pas de **vrais tampons visuels** (une image par tampon) gérés par le pass lui-même ; on peut seulement simuler avec du texte/emoji (ex. `☕☕☕ ○○○○○○○○○○`).
- **Logo** : une seule image, dimensions fixes.
- **Strip** : une seule image, dimensions recommandées fixes.

En résumé : pour des **designs trop stylés**, on mise sur **couleurs**, **logo**, **strip** (dégradé ou image custom), **emoji** et **libellés** personnalisés dans les champs texte du pass.
