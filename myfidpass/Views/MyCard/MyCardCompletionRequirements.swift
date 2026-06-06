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
            return "Renseignez au minimum la récompense à 10 pts et les paliers actifs."
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

    /// Bandeau haut : texte personnalisé **ou** logo réel (fichier local ou URL serveur) — pas le placeholder « Votre logo ».
    static func hasBandeauComplet(
        stripDisplayMode: String,
        stripText: String,
        displayName: String,
        logoURL: String
    ) -> Bool {
        let mode = stripDisplayMode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if mode == "text" {
            let text = stripText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { return true }
            return !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasMerchantLogoConfigured(logoURL: logoURL)
    }

    /// Logo commerce enregistré (pas seulement l’asset placeholder de l’aperçu).
    static func hasMerchantLogoConfigured(logoURL: String) -> Bool {
        let logo = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !logo.isEmpty else { return false }
        if logo.lowercased().hasPrefix("http://") || logo.lowercased().hasPrefix("https://") {
            return true
        }
        if let path = CardLogoStorage.resolvedDisplayPath(forStoredPath: logo) {
            return FileManager.default.fileExists(atPath: path)
        }
        return false
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

    private static let pointsMaxTierCount = MyCardPointsRewardTiers.slotCount

    static func hasStartGameRewardLabel(_ startGameRewardLabel: String) -> Bool {
        !startGameRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Palier 10 pts obligatoire + chaque ligne remplie doit être complète ; tampons : finale + 5ᵉ optionnelle.
    static func hasRecompensesCompletes(
        programType: String,
        tierPoints: [String],
        tierLabels: [String],
        requiredStamps: Int,
        stampRewardLabel: String,
        stampMidRewardLabel: String,
        startGameRewardLabel: String,
        stampMidRewardEnabled: Bool = true
    ) -> Bool {
        if programType == "points" {
            var ptsArr = tierPoints
            var labArr = tierLabels
            MyCardProgramDefaults.ensureTierArraysCapacity(tierPoints: &ptsArr, tierLabels: &labArr)
            let signupPts = ptsArr[0].trimmingCharacters(in: .whitespaces)
            let signupLab = labArr[0].trimmingCharacters(in: .whitespaces)
            guard Int(signupPts) == MyCardProgramDefaults.signupRewardPoints, !signupLab.isEmpty else { return false }
            for i in 1..<pointsMaxTierCount {
                let ptsStr = ptsArr[i].trimmingCharacters(in: .whitespaces)
                let lab = labArr[i].trimmingCharacters(in: .whitespaces)
                let hasAny = !ptsStr.isEmpty || !lab.isEmpty
                guard !hasAny else {
                    guard let pts = Int(ptsStr), pts >= 0, !lab.isEmpty else { return false }
                    continue
                }
            }
            return true
        }
        guard hasStartGameRewardLabel(startGameRewardLabel) else { return false }
        if programType == "stamps" {
            let fin = stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if fin.isEmpty { return false }
            let total = max(1, requiredStamps)
            if total > 5, stampMidRewardEnabled {
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
        startGameRewardLabel: String,
        stampMidRewardEnabled: Bool = true
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
            startGameRewardLabel: startGameRewardLabel,
            stampMidRewardEnabled: stampMidRewardEnabled
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

