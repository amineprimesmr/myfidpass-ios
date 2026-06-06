//
//  MyCardProgramDefaults.swift
//  myfidpass
//
//  Valeurs par défaut cohérentes lors d’un changement Points ↔ Tampons (Ma carte + onboarding).
//

import Foundation

enum MyCardProgramDefaults {
    static let pointsTierCount = MyCardPointsRewardTiers.slotCount
    static let signupRewardPoints = 10

    /// Sépare les paliers API : le palier 10 pts va dans la 1ʳᵉ ligne éditable (plus de ligne « Début du jeu » séparée).
    static func splitPointsTiersFromAPI(
        _ tiers: [PointsRewardTierDTO]?,
        apiStartGameLabel: String?
    ) -> (startGameRewardLabel: String, tierPoints: [String], tierLabels: [String]) {
        let sorted = (tiers ?? [])
            .filter { $0.points >= 0 }
            .sorted { $0.points < $1.points }
        var startGame = apiStartGameLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var ptsOut = Array(repeating: "", count: pointsTierCount)
        var labsOut = Array(repeating: "", count: pointsTierCount)
        var slot = 0
        for t in sorted {
            let lab = t.label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !lab.isEmpty else { continue }
            if t.points == signupRewardPoints {
                if startGame.isEmpty { startGame = lab }
                if ptsOut[0].trimmingCharacters(in: .whitespaces).isEmpty {
                    ptsOut[0] = String(signupRewardPoints)
                    labsOut[0] = lab
                }
                continue
            }
            if slot == 0, !ptsOut[0].trimmingCharacters(in: .whitespaces).isEmpty {
                slot = 1
            }
            while slot < pointsTierCount, !ptsOut[slot].trimmingCharacters(in: .whitespaces).isEmpty {
                slot += 1
            }
            guard slot < pointsTierCount else { continue }
            ptsOut[slot] = String(t.points)
            labsOut[slot] = lab
            slot += 1
        }
        if startGame.isEmpty {
            startGame = "Boisson offerte"
        }
        if ptsOut[0].trimmingCharacters(in: .whitespaces).isEmpty {
            ptsOut[0] = String(signupRewardPoints)
            labsOut[0] = startGame
        }
        sanitizeEditableTierSlots(tierPoints: &ptsOut, tierLabels: &labsOut)
        syncStartGameLabelFromFirstTier(
            startGameRewardLabel: &startGame,
            tierPoints: ptsOut,
            tierLabels: labsOut
        )
        return (startGame, ptsOut, labsOut)
    }

    /// Retire les doublons 10 pts hors 1ʳᵉ ligne.
    static func sanitizeEditableTierSlots(tierPoints: inout [String], tierLabels: inout [String]) {
        ensureTierArraysCapacity(tierPoints: &tierPoints, tierLabels: &tierLabels)
        for i in 1..<pointsTierCount {
            if Int(tierPoints[i].trimmingCharacters(in: .whitespaces)) == signupRewardPoints {
                tierPoints[i] = ""
                if i < tierLabels.count { tierLabels[i] = "" }
            }
        }
    }

    /// Garantit des tableaux de taille fixe sans écraser le contenu saisi.
    static func ensureTierArraysCapacity(tierPoints: inout [String], tierLabels: inout [String]) {
        var pts = Array(tierPoints.prefix(pointsTierCount))
        var labs = Array(tierLabels.prefix(pointsTierCount))
        while pts.count < pointsTierCount { pts.append("") }
        while labs.count < pointsTierCount { labs.append("") }
        if pts[0].trimmingCharacters(in: .whitespaces).isEmpty {
            pts[0] = String(signupRewardPoints)
        }
        tierPoints = pts
        tierLabels = labs
    }

    /// Nombre de lignes à afficher dans l’éditeur (au moins `minVisibleCount`, jusqu’au dernier palier rempli).
    static func resolvedVisibleTierRowCount(tierPoints: [String], tierLabels: [String]) -> Int {
        var lastFilled = -1
        for i in 0..<pointsTierCount {
            let p = tierPoints.indices.contains(i) ? tierPoints[i].trimmingCharacters(in: .whitespaces) : ""
            let l = tierLabels.indices.contains(i) ? tierLabels[i].trimmingCharacters(in: .whitespaces) : ""
            if !p.isEmpty || !l.isEmpty { lastFilled = i }
        }
        return min(
            max(MyCardPointsRewardTiers.minVisibleCount, lastFilled + 1),
            pointsTierCount
        )
    }

    /// Supprime un palier (index > 0) et remonte les suivants.
    static func removePointsTier(at index: Int, tierPoints: inout [String], tierLabels: inout [String]) {
        guard index > 0, index < pointsTierCount else { return }
        ensureTierArraysCapacity(tierPoints: &tierPoints, tierLabels: &tierLabels)
        for i in index..<(pointsTierCount - 1) {
            tierPoints[i] = tierPoints[i + 1]
            tierLabels[i] = tierLabels[i + 1]
        }
        tierPoints[pointsTierCount - 1] = ""
        tierLabels[pointsTierCount - 1] = ""
    }

    /// Aligne `startGameRewardLabel` sur la 1ʳᵉ ligne si elle vaut 10 pts (champ API legacy).
    static func syncStartGameLabelFromFirstTier(
        startGameRewardLabel: inout String,
        tierPoints: [String],
        tierLabels: [String]
    ) {
        let ptsStr = tierPoints.first?.trimmingCharacters(in: .whitespaces) ?? ""
        if Int(ptsStr) == signupRewardPoints {
            let lab = tierLabels.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !lab.isEmpty {
                startGameRewardLabel = lab
            }
        }
        ensureStartGameRewardLabel(&startGameRewardLabel)
    }

    /// Valeur par défaut si le commerçant n’a pas saisi le libellé (placeholder UI ≠ valeur enregistrée).
    static func ensureStartGameRewardLabel(_ label: inout String) {
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            label = "Boisson offerte"
        }
    }

    private static func resolvedSignupRewardLabel(
        startGameRewardLabel: String,
        tierPoints: [String],
        tierLabels: [String]
    ) -> String {
        let ptsStr = tierPoints.first?.trimmingCharacters(in: .whitespaces) ?? ""
        if Int(ptsStr) == signupRewardPoints {
            let lab = tierLabels.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !lab.isEmpty {
                return String(lab.prefix(120))
            }
        }
        var startLab = startGameRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if startLab.isEmpty { startLab = "Boisson offerte" }
        return String(startLab.prefix(120))
    }

    /// Payload API : palier 10 pts (1ʳᵉ ligne) + paliers saisis (sans doublon 10 pts).
    static func buildPointsRewardTiersForAPI(
        startGameRewardLabel: String,
        tierPoints: [String],
        tierLabels: [String]
    ) -> [PointsRewardTierPayload] {
        var tiers: [PointsRewardTierPayload] = []
        let signupLabel = resolvedSignupRewardLabel(
            startGameRewardLabel: startGameRewardLabel,
            tierPoints: tierPoints,
            tierLabels: tierLabels
        )
        tiers.append(PointsRewardTierPayload(points: signupRewardPoints, label: signupLabel))
        for i in 0..<pointsTierCount {
            let ptsStr = tierPoints.indices.contains(i) ? tierPoints[i].trimmingCharacters(in: .whitespaces) : ""
            let lab = tierLabels.indices.contains(i) ? tierLabels[i].trimmingCharacters(in: .whitespaces) : ""
            guard let pts = Int(ptsStr), pts >= 0, !lab.isEmpty else { continue }
            if pts == signupRewardPoints { continue }
            tiers.append(PointsRewardTierPayload(points: pts, label: String(lab.prefix(120))))
        }
        tiers.sort { $0.points < $1.points }
        return tiers
    }

    /// Exemples fixes (bouton « Appliquer les exemples » uniquement — jamais au enregistrement silencieux).
    static func applyExamplePointsTiers(tierPoints: inout [String], tierLabels: inout [String]) {
        let defaultsPts = ["10", "50", "100", "150", "200"]
        let defaultsLabs = [
            "Boisson offerte",
            "Un café offert",
            "Un dessert offert",
            "10 % de réduction",
            "15 % de réduction",
        ]
        tierPoints = defaultsPts + Array(repeating: "", count: max(0, pointsTierCount - defaultsPts.count))
        tierLabels = defaultsLabs + Array(repeating: "", count: max(0, pointsTierCount - defaultsLabs.count))
    }

    /// Remplit les récompenses tampons si vides (ex. passage Points → Tampons).
    static func fillDefaultStampRewardsIfNeeded(
        requiredStamps: inout Int,
        stampRewardLabel: inout String,
        stampMidRewardLabel: inout String,
        startGameRewardLabel: inout String,
        stampEmoji: inout String
    ) {
        if requiredStamps < 5 { requiredStamps = 10 }
        if startGameRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startGameRewardLabel = "Boisson offerte"
        }
        if stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stampRewardLabel = "Une récompense offerte"
        }
        if stampEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stampEmoji = "cafe"
        }
    }
}
