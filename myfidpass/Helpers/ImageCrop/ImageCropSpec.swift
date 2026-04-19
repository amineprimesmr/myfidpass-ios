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
    /// **`icon.png`** carré 29/58/87 px côté serveur — cadrage 1:1 ; export large puis compression API (notifications, logo carré, tampon importé).
    case squareIcon

    /// Largeur / hauteur de la fenêtre de cadrage (identique au ratio d’export).
    var aspectWidthOverHeight: CGFloat {
        switch self {
        case .walletStripLogo:
            return 400.0 / 125.0
        case .walletCardBackground:
            return 750.0 / 246.0
        case .squareIcon:
            return 1.0
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
        case .squareIcon:
            return CGSize(width: 512, height: 512)
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
        }
    }
}
