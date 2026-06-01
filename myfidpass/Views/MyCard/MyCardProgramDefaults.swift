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

    /// Sépare le palier 10 pts (début du jeu) des 5 paliers éditables affichés dans Ma carte.
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
                continue
            }
            guard slot < pointsTierCount else { continue }
            ptsOut[slot] = String(t.points)
            labsOut[slot] = lab
            slot += 1
        }
        if startGame.isEmpty {
            startGame = "Boisson offerte"
        }
        sanitizeEditableTierSlots(tierPoints: &ptsOut, tierLabels: &labsOut)
        return (startGame, ptsOut, labsOut)
    }

    /// Retire tout palier 10 pts des cases éditables (réservé à « Début du jeu »).
    static func sanitizeEditableTierSlots(tierPoints: inout [String], tierLabels: inout [String]) {
        for i in 0..<min(pointsTierCount, tierPoints.count) {
            if Int(tierPoints[i].trimmingCharacters(in: .whitespaces)) == signupRewardPoints {
                tierPoints[i] = ""
                if i < tierLabels.count { tierLabels[i] = "" }
            }
        }
    }

    /// Valeur par défaut si le commerçant n’a pas saisi le libellé (placeholder UI ≠ valeur enregistrée).
    static func ensureStartGameRewardLabel(_ label: inout String) {
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            label = "Boisson offerte"
        }
    }

    /// Payload API : palier 10 pts + paliers saisis (sans doublon 10 pts).
    static func buildPointsRewardTiersForAPI(
        startGameRewardLabel: String,
        tierPoints: [String],
        tierLabels: [String]
    ) -> [PointsRewardTierPayload] {
        var tiers: [PointsRewardTierPayload] = []
        var startLab = startGameRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        if startLab.isEmpty { startLab = "Boisson offerte" }
        tiers.append(PointsRewardTierPayload(points: signupRewardPoints, label: String(startLab.prefix(120))))
        for i in 0..<pointsTierCount {
            let ptsStr = tierPoints.indices.contains(i) ? tierPoints[i].trimmingCharacters(in: .whitespaces) : ""
            let lab = tierLabels.indices.contains(i) ? tierLabels[i].trimmingCharacters(in: .whitespaces) : ""
            guard let pts = Int(ptsStr), pts >= 0, !lab.isEmpty else { continue }
            if pts == signupRewardPoints, !startLab.isEmpty { continue }
            tiers.append(PointsRewardTierPayload(points: pts, label: String(lab.prefix(120))))
        }
        tiers.sort { $0.points < $1.points }
        return tiers
    }

    /// Remplit les paliers points s’ils sont incomplets (ex. passage Tampons → Points).
    static func fillDefaultPointsTiersIfNeeded(tierPoints: inout [String], tierLabels: inout [String]) {
        var pts = Array(tierPoints.prefix(pointsTierCount))
        var labs = Array(tierLabels.prefix(pointsTierCount))
        while pts.count < pointsTierCount { pts.append("") }
        while labs.count < pointsTierCount { labs.append("") }

        let complete = (0..<pointsTierCount).allSatisfy { i in
            let p = pts[i].trimmingCharacters(in: .whitespaces)
            let lab = labs[i].trimmingCharacters(in: .whitespaces)
            return Int(p) != nil && !lab.isEmpty
        }
        guard !complete else {
            tierPoints = pts
            tierLabels = labs
            return
        }

        tierPoints = ["50", "100", "150", "200", "250"]
        tierLabels = [
            "Un café offert",
            "Un dessert offert",
            "10 % de réduction",
            "15 % de réduction",
            "Un repas offert",
        ]
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
        if requiredStamps > 5,
           stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stampMidRewardLabel = "−50 % sur un article"
        }
        if stampEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            stampEmoji = "cafe"
        }
    }
}
