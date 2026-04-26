//
//  ImageCropSpec.swift
//  myfidpass
//
//  Ratios et tailles d’export alignés sur le backend PassKit (`fidelity/backend/src/pass/constants.js`).
//

import CoreGraphics
import UIKit

/// Objet pour présenter la feuille de cadrage (`PhotosPicker` → image → `ImageCropEditorView`).
struct ImageCropPayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let spec: ImageCropSpec
}

/// Contexte de cadrage : ratio imposé + taille d’export (voir chaque cas).
///
/// Réf. Apple PassKit (Creating.html) :
/// - **`logo.png`** : emplacement max. **160×50 pt** en face avant (coin supérieur gauche, à côté du titre) — ratio **16:5**.
/// - **`icon.png`** : **29×29 pt** (@1x) — notifications / verrou ; **pas** le bandeau large.
/// - **`strip.png`** : image de fond derrière les champs — **750×246** @2x usuel.
///
/// Le backend `fidelity/backend/src/pass/constants.js` utilise un canvas logo 400×125 (@2x) même ratio 16:5 ; le strip aligné `STRIP_W`×`STRIP_H`.
enum ImageCropSpec: Equatable {
    /// Bandeau **logo** Wallet (fichier `logo.png` / `logo@2x.png`) — même ratio que 160×50 pt Apple (`400/125` = `16/5`).
    case walletStripLogo
    /// Image de fond **`strip.png`** (750×246 @2x).
    case walletCardBackground
    /// **`icon.png`** carré 29/58/87 px côté serveur — cadrage 1:1 ; pass / notifications, logo carré établissement (même règle de confirmation « première image » iOS côté UX).
    case squareIcon
    /// Icône **importée** pour les cases **tampon** sur la carte (même cadrage qu’`icon.png` mais sans le flux « notification Wallet » : titres & alertes adaptés).
    case stampIcon
    /// Logo bandeau haut du **flyer QR** — ratio = zone réelle sur le canevas : `(W·f_w)/(H·f_h)` (≈ 2,76 pour 2400×3600), pas `f_w/f_h` (erreur ≈ 4,1 = cadre trop plat).
    case flyerPromoLogo
    /// Fond personnalisé **plein cadre** du flyer (même ratio que le visuel 2400×3600 = 2:3).
    case flyerCustomBackground

    // MARK: Canevas flyer (`flyer-embed`) — ratios cohérents avec l’affichage

    /// Canevas embarqué (portrait) : largeur × hauteur de référence.
    private static let flyerEmbedWidth: CGFloat = 2400
    private static let flyerEmbedHeight: CGFloat = 3600
    /// `FlyerStateDTO` par défaut : bandeau logo ≈ 62 % × largeur, 15 % × hauteur.
    private static let flyerLogoDefaultWFrac: CGFloat = 0.62
    private static let flyerDefaultLogoHFrac: CGFloat = 0.15

    /// Largeur / hauteur de la fenêtre de cadrage (identique au ratio d’export).
    var aspectWidthOverHeight: CGFloat {
        switch self {
        case .walletStripLogo:
            return 400.0 / 125.0
        case .walletCardBackground:
            return 750.0 / 246.0
        case .squareIcon, .stampIcon:
            return 1.0
        case .flyerPromoLogo:
            return (Self.flyerEmbedWidth * Self.flyerLogoDefaultWFrac)
                / (Self.flyerEmbedHeight * Self.flyerDefaultLogoHFrac)
        case .flyerCustomBackground:
            return Self.flyerEmbedWidth / Self.flyerEmbedHeight
        }
    }

    /// Taille d’export côté app (le backend `resizeLogoForPass` / `resizeLogoForPassIcon` réajuste si besoin).
    var exportPixelSize: CGSize {
        switch self {
        case .walletStripLogo:
            // 2× le canvas backend 400×125 (@2x) — ratio identique au slot Apple 160×50 pt.
            return CGSize(width: 800, height: 250)
        case .walletCardBackground:
            return CGSize(width: 1500, height: 492)
        case .squareIcon, .stampIcon:
            return CGSize(width: 512, height: 512)
        case .flyerPromoLogo:
            let w: CGFloat = 2000
            let a = (Self.flyerEmbedWidth * Self.flyerLogoDefaultWFrac) / (Self.flyerEmbedHeight * Self.flyerDefaultLogoHFrac)
            return CGSize(width: w, height: w / a)
        case .flyerCustomBackground:
            let w: CGFloat = 2000
            let a = Self.flyerEmbedWidth / Self.flyerEmbedHeight
            return CGSize(width: w, height: w / a)
        }
    }

    var navigationTitle: String {
        switch self {
        case .walletStripLogo:
            return "Logo bandeau"
        case .walletCardBackground:
            return "Image de fond"
        case .squareIcon:
            return "Icône de notification"
        case .stampIcon:
            return "Icône des tampons"
        case .flyerPromoLogo:
            return "Logo du flyer"
        case .flyerCustomBackground:
            return "Image de fond du flyer"
        }
    }

    var hint: String {
        switch self {
        case .walletStripLogo:
            return "Logo en bandeau (face carte, comme Apple 160×50 pt, ratio 16:5). Départ en haut à gauche du cadre ; pincez pour zoomer et faites glisser pour placer l’image comme vous voulez."
        case .walletCardBackground:
            return "Image de fond strip (750×246 @2x). Départ en haut à gauche du cadre ; pincez et faites glisser pour ajuster."
        case .squareIcon:
            // Affichage dédié dans `ImageCropEditorView` (carte + gras) — pas de chaîne ici.
            return ""
        case .stampIcon:
            return "Cadre carré pour l’icône dans chaque case tampon. Pincez pour cadrer le détail, puis validez. Vous pourrez changer d’image plus tard depuis Ma carte."
        case .flyerPromoLogo:
            return "Cadrage aligné sur le bandeau logo du flyer (zone en haut). Pincez pour zoomer et déplacez l’image ; le cadre est plus haut qu’avant pour mieux cadrer votre logo."
        case .flyerCustomBackground:
            return "Cadrage plein format du flyer (portrait, comme l’affichage final). Ajustez la zone visible derrière le dégradé et la roue : pincez, puis déplacez."
        }
    }
}
