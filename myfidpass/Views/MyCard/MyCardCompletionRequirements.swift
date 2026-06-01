//
//  MyCardCompletionRequirements.swift
//  myfidpass
//
//  Règles obligatoires pour finaliser une carte en cours de personnalisation (Ma carte).
//

import Foundation
import SwiftUI

/// Élément manquant pour pouvoir enregistrer / tester le Wallet.
enum CardMissingRequirement: Identifiable, Equatable {
    case logoOrBandeauTexte
    case couleursCarte
    case recompenses
    case imageDeFondPoints
    case iconeTampons

    var id: String {
        switch self {
        case .logoOrBandeauTexte: return "logo"
        case .couleursCarte: return "colors"
        case .recompenses: return "rewards"
        case .imageDeFondPoints: return "bg"
        case .iconeTampons: return "stampIcon"
        }
    }

    /// Zone de la carte à ouvrir pour corriger rapidement.
    var suggestedEditZone: CardPreviewEditZone {
        switch self {
        case .logoOrBandeauTexte: return .logoBand
        case .couleursCarte: return .cardAppearance
        case .recompenses: return .headerRight
        case .imageDeFondPoints: return .backgroundImage
        case .iconeTampons: return .mainMetrics
        }
    }

    var title: String {
        switch self {
        case .logoOrBandeauTexte:
            return "Logo du commerce"
        case .couleursCarte:
            return "Couleurs de la carte"
        case .recompenses:
            return "Récompenses du programme"
        case .imageDeFondPoints:
            return "Image de fond (mode points)"
        case .iconeTampons:
            return "Icône des tampons"
        }
    }

    var detail: String {
        switch self {
        case .logoOrBandeauTexte:
            return "Ajoutez un logo (sinon le placeholder « Votre logo » s’affiche)."
        case .couleursCarte:
            return "Définissez le fond, les titres (POINTS, MEMBRE…) et les textes secondaires."
        case .recompenses:
            return "Renseignez toutes les récompenses, y compris « Début du jeu »."
        case .imageDeFondPoints:
            return "Choisissez une image pour la zone sous l’en-tête."
        case .iconeTampons:
            return "Choisissez une icône ou importez une image pour les cases tampon."
        }
    }

    var symbolName: String {
        switch self {
        case .logoOrBandeauTexte: return "photo.badge.plus"
        case .couleursCarte: return "paintpalette.fill"
        case .recompenses: return "gift.fill"
        case .imageDeFondPoints: return "photo.on.rectangle.angled"
        case .iconeTampons: return "square.grid.3x3.fill"
        }
    }
}

enum MyCardCompletionRequirements {

    /// Fond + textes + titres : trois hex `#RRGGBB` valides (le titrage était souvent vide par défaut).
    static func hasCouleursCarte(primaryHex: String, accentHex: String, labelHex: String) -> Bool {
        isValidHexRGB(primaryHex) && isValidHexRGB(accentHex) && isValidHexRGB(labelHex)
    }

    /// Chaîne hex sur 6 caractères (avec ou sans `#`).
    private static func isValidHexRGB(_ raw: String) -> Bool {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
        guard t.count == 6 else { return false }
        return t.allSatisfy(\.isHexDigit)
    }

    /// True si le bandeau haut est correctement renseigné (logo image ou placeholder par défaut).
    static func hasBandeauComplet(
        stripDisplayMode: String,
        stripText: String,
        displayName: String,
        logoURL: String
    ) -> Bool {
        _ = stripDisplayMode
        _ = stripText
        _ = displayName
        _ = logoURL
        return true
    }

    static func hasCardBackgroundPoints(
        programType: String,
        cardBackgroundImagePath: String?,
        cardBackgroundRemoteURL: String?,
        cardBackgroundWasRemoved: Bool
    ) -> Bool {
        guard programType == "points" else { return true }
        let path = cardBackgroundImagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remote = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !path.isEmpty || !remote.isEmpty { return true }
        if cardBackgroundWasRemoved { return false }
        return false
    }

    /// Tampons : clé d’icône assets, import en cours, ou icône déjà enregistrée côté serveur (non supprimée localement).
    static func hasStampVisual(
        programType: String,
        stampEmoji: String,
        stampIconPendingBase64: String?,
        stampIconWasRemoved: Bool,
        serverHasStampIcon: Bool
    ) -> Bool {
        guard programType == "stamps" else { return true }
        let em = stampEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        if !em.isEmpty { return true }
        if let p = stampIconPendingBase64, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if stampIconWasRemoved { return false }
        return serverHasStampIcon
    }

    private static let pointsRewardTierCount = 5

    static func hasStartGameRewardLabel(_ startGameRewardLabel: String) -> Bool {
        var label = startGameRewardLabel
        MyCardProgramDefaults.ensureStartGameRewardLabel(&label)
        return !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Tous les paliers points (5 + « Début du jeu »), ou toutes les récompenses tampons requises.
    static func hasRecompensesCompletes(
        programType: String,
        tierPoints: [String],
        tierLabels: [String],
        requiredStamps: Int,
        stampRewardLabel: String,
        stampMidRewardLabel: String,
        startGameRewardLabel: String
    ) -> Bool {
        guard hasStartGameRewardLabel(startGameRewardLabel) else { return false }
        if programType == "points" {
            let ptsArr = tierPoints + Array(repeating: "", count: max(0, pointsRewardTierCount - tierPoints.count))
            let labArr = tierLabels + Array(repeating: "", count: max(0, pointsRewardTierCount - tierLabels.count))
            for i in 0..<pointsRewardTierCount {
                let ptsStr = ptsArr[i].trimmingCharacters(in: .whitespaces)
                let lab = labArr[i].trimmingCharacters(in: .whitespaces)
                guard let pts = Int(ptsStr), pts >= 0, !lab.isEmpty else { return false }
            }
            return true
        }
        if programType == "stamps" {
            let fin = stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if fin.isEmpty { return false }
            let total = max(1, requiredStamps)
            if total > 5 {
                let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
                if mid.isEmpty { return false }
            }
            return true
        }
        return true
    }

    static func missingRequirements(
        primaryHex: String,
        accentHex: String,
        labelHex: String,
        stripDisplayMode: String,
        stripText: String,
        displayName: String,
        logoURL: String,
        programType: String,
        cardBackgroundImagePath: String?,
        cardBackgroundRemoteURL: String?,
        cardBackgroundWasRemoved: Bool,
        stampEmoji: String,
        stampIconPendingBase64: String?,
        stampIconWasRemoved: Bool,
        serverHasStampIcon: Bool,
        tierPoints: [String],
        tierLabels: [String],
        requiredStamps: Int,
        stampRewardLabel: String,
        stampMidRewardLabel: String,
        startGameRewardLabel: String
    ) -> [CardMissingRequirement] {
        var missing: [CardMissingRequirement] = []

        if !hasBandeauComplet(
            stripDisplayMode: stripDisplayMode,
            stripText: stripText,
            displayName: displayName,
            logoURL: logoURL
        ) {
            missing.append(.logoOrBandeauTexte)
        }

        if !hasCouleursCarte(primaryHex: primaryHex, accentHex: accentHex, labelHex: labelHex) {
            missing.append(.couleursCarte)
        }

        if !hasRecompensesCompletes(
            programType: programType,
            tierPoints: tierPoints,
            tierLabels: tierLabels,
            requiredStamps: requiredStamps,
            stampRewardLabel: stampRewardLabel,
            stampMidRewardLabel: stampMidRewardLabel,
            startGameRewardLabel: startGameRewardLabel
        ) {
            missing.append(.recompenses)
        }

        if !hasCardBackgroundPoints(
            programType: programType,
            cardBackgroundImagePath: cardBackgroundImagePath,
            cardBackgroundRemoteURL: cardBackgroundRemoteURL,
            cardBackgroundWasRemoved: cardBackgroundWasRemoved
        ) {
            missing.append(.imageDeFondPoints)
        }

        if !hasStampVisual(
            programType: programType,
            stampEmoji: stampEmoji,
            stampIconPendingBase64: stampIconPendingBase64,
            stampIconWasRemoved: stampIconWasRemoved,
            serverHasStampIcon: serverHasStampIcon
        ) {
            missing.append(.iconeTampons)
        }

        return missing
    }
}

