//
//  BodyPostureAnalyzer.swift
//  Process
//
//  Analyseur de posture utilisant Vision framework
//

import Foundation
import Vision
import UIKit

@MainActor
class BodyPostureAnalyzer {

    /// Analyse la posture à partir d'une image
    static func analyzePosture(
        from image: UIImage,
        posePoints: BodyPosePoints
    ) -> PostureAnalysis {
        var analysis = PostureAnalysis()

        // Analyser les alignements
        analysis.shoulderAlignment = analyzeShoulderAlignment(posePoints: posePoints)
        analysis.hipAlignment = analyzeHipAlignment(posePoints: posePoints)
        analysis.spineAlignment = analyzeSpineAlignment(posePoints: posePoints)

        // Calculer les angles
        analysis.headAngle = calculateHeadAngle(posePoints: posePoints)
        analysis.shoulderAngle = calculateShoulderAngle(posePoints: posePoints)
        analysis.hipAngle = calculateHipAngle(posePoints: posePoints)
        analysis.kneeAngle = calculateKneeAngle(posePoints: posePoints)

        // Détecter les déséquilibres
        analysis.imbalances = detectImbalances(posePoints: posePoints, analysis: analysis)

        // Calculer le score global
        analysis.overallScore = calculateOverallPostureScore(analysis: analysis)

        // Générer les recommandations
        analysis.recommendations = generateRecommendations(analysis: analysis)

        return analysis
    }

    // MARK: - Analyse d'alignement

    /// Analyse l'alignement des épaules
    private static func analyzeShoulderAlignment(posePoints: BodyPosePoints) -> AlignmentStatus {
        guard let leftShoulder = posePoints.leftShoulder,
              let rightShoulder = posePoints.rightShoulder else {
            return .unknown
        }

        let verticalDifference = abs(leftShoulder.y - rightShoulder.y)
        let threshold: CGFloat = 15.0 // pixels de tolérance

        if verticalDifference < threshold {
            return .aligned
        } else if verticalDifference < threshold * 2 {
            return .slightlyOff
        } else {
            return .misaligned
        }
    }

    /// Analyse l'alignement du bassin
    private static func analyzeHipAlignment(posePoints: BodyPosePoints) -> AlignmentStatus {
        guard let leftHip = posePoints.leftHip,
              let rightHip = posePoints.rightHip else {
            return .unknown
        }

        let verticalDifference = abs(leftHip.y - rightHip.y)
        let threshold: CGFloat = 15.0 // pixels de tolérance

        if verticalDifference < threshold {
            return .aligned
        } else if verticalDifference < threshold * 2 {
            return .slightlyOff
        } else {
            return .misaligned
        }
    }

    /// Analyse l'alignement de la colonne vertébrale
    private static func analyzeSpineAlignment(posePoints: BodyPosePoints) -> AlignmentStatus {
        guard let leftShoulder = posePoints.leftShoulder,
              let rightShoulder = posePoints.rightShoulder,
              let leftHip = posePoints.leftHip,
              let rightHip = posePoints.rightHip else {
            return .unknown
        }

        let shoulderCenter = CGPoint(
            x: (leftShoulder.x + rightShoulder.x) / 2,
            y: (leftShoulder.y + rightShoulder.y) / 2
        )
        let hipCenter = CGPoint(
            x: (leftHip.x + rightHip.x) / 2,
            y: (leftHip.y + rightHip.y) / 2
        )

        let horizontalOffset = abs(shoulderCenter.x - hipCenter.x)
        let threshold: CGFloat = 20.0 // pixels de tolérance

        if horizontalOffset < threshold {
            return .aligned
        } else if horizontalOffset < threshold * 2 {
            return .slightlyOff
        } else {
            return .misaligned
        }
    }

    // MARK: - Calculs d'angles

    /// Calcule l'angle de la tête (inclinaison avant/arrière)
    private static func calculateHeadAngle(posePoints: BodyPosePoints) -> Double? {
        guard let nose = posePoints.nose,
              let neck = posePoints.neck else {
            return nil
        }

        let horizontalOffset = abs(nose.x - neck.x)
        let verticalOffset = nose.y - neck.y

        // Angle en degrés (0 = droit, positif = penché en avant)
        let angle = atan2(horizontalOffset, abs(verticalOffset)) * 180.0 / .pi
        return angle
    }

    /// Calcule l'angle des épaules
    private static func calculateShoulderAngle(posePoints: BodyPosePoints) -> Double? {
        guard let leftShoulder = posePoints.leftShoulder,
              let rightShoulder = posePoints.rightShoulder else {
            return nil
        }

        let dy = rightShoulder.y - leftShoulder.y
        let dx = rightShoulder.x - leftShoulder.x
        let angle = atan2(dy, dx) * 180.0 / .pi
        return angle
    }

    /// Calcule l'angle du bassin
    private static func calculateHipAngle(posePoints: BodyPosePoints) -> Double? {
        guard let leftHip = posePoints.leftHip,
              let rightHip = posePoints.rightHip else {
            return nil
        }

        let dy = rightHip.y - leftHip.y
        let dx = rightHip.x - leftHip.x
        let angle = atan2(dy, dx) * 180.0 / .pi
        return angle
    }

    /// Calcule l'angle des genoux
    private static func calculateKneeAngle(posePoints: BodyPosePoints) -> Double? {
        guard let leftHip = posePoints.leftHip,
              let leftKnee = posePoints.leftKnee,
              let leftAnkle = posePoints.leftAnkle else {
            return nil
        }

        // Angle au niveau du genou (entre cuisse et jambe)
        let angle1 = angleBetweenThreePoints(p1: leftHip, p2: leftKnee, p3: leftAnkle)
        return angle1
    }

    /// Calcule l'angle entre trois points
    private static func angleBetweenThreePoints(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let a = p1
        let b = p2
        let c = p3

        let v1 = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let v2 = CGPoint(x: c.x - b.x, y: c.y - b.y)

        let dot = v1.x * v2.x + v1.y * v2.y
        let det = v1.x * v2.y - v1.y * v2.x
        let angle = atan2(det, dot) * 180.0 / .pi

        return abs(angle)
    }

    // MARK: - Détection de déséquilibres

    /// Détecte les déséquilibres posturaux
    private static func detectImbalances(
        posePoints: BodyPosePoints,
        analysis: PostureAnalysis
    ) -> [PostureImbalance] {
        var imbalances: [PostureImbalance] = []

        // Détecter tête en avant
        if let headAngle = analysis.headAngle, headAngle > 15 {
            imbalances.append(PostureImbalance(
                type: .forwardHead,
                severity: headAngle > 25 ? .severe : (headAngle > 20 ? .moderate : .mild),
                description: "Tête inclinée vers l'avant",
                recommendation: "Renforcer les muscles du cou et des épaules, améliorer la position de travail"
            ))
        }

        // Détecter épaules arrondies
        if analysis.shoulderAlignment == .misaligned {
            if let shoulderAngle = analysis.shoulderAngle, shoulderAngle < -10 {
                imbalances.append(PostureImbalance(
                    type: .roundedShoulders,
                    severity: abs(shoulderAngle) > 20 ? .severe : (abs(shoulderAngle) > 15 ? .moderate : .mild),
                    description: "Épaules arrondies vers l'avant",
                    recommendation: "Étirer les pectoraux, renforcer les muscles du dos"
                ))
            }
        }

        // Détecter épaules inégales
        if analysis.shoulderAlignment == .misaligned {
            imbalances.append(PostureImbalance(
                type: .unevenShoulders,
                severity: .moderate,
                description: "Épaules non alignées",
                recommendation: "Renforcer les muscles stabilisateurs, vérifier l'équilibre du dos"
            ))
        }

        // Détecter bassin incliné
        if analysis.hipAlignment == .misaligned {
            imbalances.append(PostureImbalance(
                type: .tiltedHips,
                severity: .moderate,
                description: "Bassin incliné",
                recommendation: "Renforcer les muscles abdominaux et fessiers, étirer les fléchisseurs de hanche"
            ))
        }

        // Détecter colonne non alignée
        if analysis.spineAlignment == .misaligned {
            imbalances.append(PostureImbalance(
                type: .lordosis,
                severity: .moderate,
                description: "Colonne vertébrale non alignée",
                recommendation: "Renforcer les muscles du tronc, améliorer la posture globale"
            ))
        }

        return imbalances
    }

    // MARK: - Score global

    /// Calcule le score global de posture (0-100)
    private static func calculateOverallPostureScore(analysis: PostureAnalysis) -> Double {
        var score = 100.0

        // Pénalités pour alignements
        if analysis.shoulderAlignment == .misaligned { score -= 15 } else if analysis.shoulderAlignment == .slightlyOff { score -= 7 }

        if analysis.hipAlignment == .misaligned { score -= 15 } else if analysis.hipAlignment == .slightlyOff { score -= 7 }

        if analysis.spineAlignment == .misaligned { score -= 20 } else if analysis.spineAlignment == .slightlyOff { score -= 10 }

        // Pénalités pour déséquilibres
        for imbalance in analysis.imbalances {
            switch imbalance.severity {
            case .severe: score -= 10
            case .moderate: score -= 5
            case .mild: score -= 2
            }
        }

        return max(0, min(100, score))
    }

    // MARK: - Recommandations

    /// Génère des recommandations basées sur l'analyse
    private static func generateRecommendations(analysis: PostureAnalysis) -> [String] {
        var recommendations: [String] = []

        if analysis.overallScore < 70 {
            recommendations.append("Considérez consulter un professionnel de la santé pour une évaluation complète")
        }

        if analysis.imbalances.contains(where: { $0.type == .forwardHead }) {
            recommendations.append("Renforcez les muscles du cou et des épaules avec des exercices ciblés")
        }

        if analysis.imbalances.contains(where: { $0.type == .roundedShoulders }) {
            recommendations.append("Étirez régulièrement les pectoraux et renforcez les muscles du dos")
        }

        if analysis.imbalances.contains(where: { $0.type == .tiltedHips }) {
            recommendations.append("Renforcez les muscles abdominaux et fessiers pour stabiliser le bassin")
        }

        if analysis.shoulderAlignment != .aligned || analysis.hipAlignment != .aligned {
            recommendations.append("Travaille sur l'équilibre et la symétrie du corps")
        }

        if recommendations.isEmpty {
            recommendations.append("Ta posture est globalement bonne, continue à maintenir de bonnes habitudes")
        }

        return recommendations
    }
}
