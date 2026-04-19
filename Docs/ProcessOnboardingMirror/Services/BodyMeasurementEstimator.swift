//
//  BodyMeasurementEstimator.swift
//  Process
//
//  Estimateur de mensurations basé sur proportions et calibrage
//

import Foundation
import Vision

@MainActor
class BodyMeasurementEstimator {

    /// Estime les mensurations à partir des points de pose et de la taille réelle
    static func estimateMeasurements(
        posePoints: BodyPosePoints,
        imageSize: CGSize,
        realHeight: Double  // Taille réelle en cm (pour calibration)
    ) -> BodyMeasurements {
        var measurements = BodyMeasurements()

        guard let leftShoulder = posePoints.leftShoulder,
              let rightShoulder = posePoints.rightShoulder,
              let leftHip = posePoints.leftHip,
              let rightHip = posePoints.rightHip,
              let leftKnee = posePoints.leftKnee,
              let rightKnee = posePoints.rightKnee,
              let leftAnkle = posePoints.leftAnkle,
              let rightAnkle = posePoints.rightAnkle,
              let neck = posePoints.neck,
              let leftElbow = posePoints.leftElbow,
              let rightElbow = posePoints.rightElbow,
              let leftWrist = posePoints.leftWrist,
              let rightWrist = posePoints.rightWrist else {
            return measurements // Retourner vide si points manquants
        }

        // Calculer la hauteur du corps en pixels
        let topPoint = min(leftShoulder.y, rightShoulder.y)
        let bottomPoint = max(leftAnkle.y, rightAnkle.y)
        let bodyHeightPixels = abs(bottomPoint - topPoint)

        // Facteur de conversion pixel → cm
        let pixelsPerCm = bodyHeightPixels / realHeight

        // Estimation des mensurations

        // 1. Tour de poitrine (basé sur largeur épaules et position coudes)
        if let chestWidth = estimateChestWidth(
            leftShoulder: leftShoulder,
            rightShoulder: rightShoulder,
            pixelsPerCm: pixelsPerCm
        ) {
            measurements.chest = chestWidth
        }

        // 2. Tour de taille (basé sur largeur hanches et estimation)
        if let waistWidth = estimateWaistWidth(
            leftHip: leftHip,
            rightHip: rightHip,
            pixelsPerCm: pixelsPerCm
        ) {
            measurements.waist = waistWidth
        }

        // 3. Tour de hanches (largeur hanches)
        let hipWidthPixels = distance(leftHip, rightHip)
        measurements.hips = (hipWidthPixels / pixelsPerCm) * 1.1 // Ajustement pour circonférence

        // 4. Tour de cou (basé sur point cou)
        let neckWidth = estimateNeckWidth(neckPoint: neck, pixelsPerCm: pixelsPerCm)
        measurements.neck = neckWidth

        // 5. Largeur épaules
        let shoulderWidth = distance(leftShoulder, rightShoulder)
        measurements.shoulders = shoulderWidth / pixelsPerCm

        // 6. Tour de biceps (basé sur position coude et épaule)
        if let biceps = estimateBiceps(
            shoulder: leftShoulder,
            elbow: leftElbow,
            pixelsPerCm: pixelsPerCm
        ) {
            measurements.biceps = biceps
        }

        // 7. Tour de cuisses (basé sur position genou et hanche)
        if let thigh = estimateThigh(
            hip: leftHip,
            knee: leftKnee,
            pixelsPerCm: pixelsPerCm
        ) {
            measurements.thighs = thigh
        }

        // 8. Tour de mollets (basé sur position genou et cheville)
        if let calf = estimateCalf(
            knee: leftKnee,
            ankle: leftAnkle,
            pixelsPerCm: pixelsPerCm
        ) {
            measurements.calves = calf
        }

        // Calcul des ratios
        if let waist = measurements.waist, let hips = measurements.hips {
            measurements.waistToHipRatio = waist / hips
        }

        if let shoulders = measurements.shoulders, let waist = measurements.waist {
            measurements.shoulderToWaistRatio = shoulders / waist
        }

        // Estimation des longueurs (relatives)
        if let armLength = estimateArmLength(
            shoulder: leftShoulder,
            elbow: leftElbow,
            wrist: leftWrist
        ) {
            measurements.armLength = armLength / pixelsPerCm
        }

        if let legLength = estimateLegLength(
            hip: leftHip,
            knee: leftKnee,
            ankle: leftAnkle
        ) {
            measurements.legLength = legLength / pixelsPerCm
        }

        if let torsoLength = estimateTorsoLength(
            shoulder: leftShoulder,
            hip: leftHip
        ) {
            measurements.torsoLength = torsoLength / pixelsPerCm
        }

        return measurements
    }

    // MARK: - Estimations individuelles

    /// Estime la largeur de poitrine
    private static func estimateChestWidth(
        leftShoulder: CGPoint,
        rightShoulder: CGPoint,
        pixelsPerCm: Double
    ) -> Double? {
        let shoulderWidth = distance(leftShoulder, rightShoulder)
        // Estimation : poitrine ≈ 1.3 × largeur épaules (approximation)
        let chestWidth = shoulderWidth * 1.3
        return (chestWidth / pixelsPerCm) * 1.1 // Conversion en circonférence
    }

    /// Estime la largeur de taille
    private static func estimateWaistWidth(
        leftHip: CGPoint,
        rightHip: CGPoint,
        pixelsPerCm: Double
    ) -> Double? {
        let hipWidth = distance(leftHip, rightHip)
        // Estimation : taille ≈ 0.85 × largeur hanches (approximation)
        let waistWidth = hipWidth * 0.85
        return (waistWidth / pixelsPerCm) * 1.1 // Conversion en circonférence
    }

    /// Estime la largeur du cou
    private static func estimateNeckWidth(
        neckPoint: CGPoint,
        pixelsPerCm: Double
    ) -> Double {
        // Estimation basée sur position : cou ≈ 12-15 cm de circonférence moyenne
        // Utiliser une estimation fixe basée sur la hauteur (calibrée)
        let estimatedNeckCircumference = 13.5 // cm (moyenne)
        return estimatedNeckCircumference
    }

    /// Estime le tour de biceps
    private static func estimateBiceps(
        shoulder: CGPoint,
        elbow: CGPoint,
        pixelsPerCm: Double
    ) -> Double? {
        let armSegmentLength = distance(shoulder, elbow)
        // Estimation : biceps ≈ 0.25 × longueur segment bras (approximation)
        let estimatedCircumference = armSegmentLength * 0.25
        return estimatedCircumference / pixelsPerCm
    }

    /// Estime le tour de cuisses
    private static func estimateThigh(
        hip: CGPoint,
        knee: CGPoint,
        pixelsPerCm: Double
    ) -> Double? {
        let thighLength = distance(hip, knee)
        // Estimation : cuisse ≈ 0.5 × longueur cuisse (approximation)
        let estimatedCircumference = thighLength * 0.5
        return (estimatedCircumference / pixelsPerCm) * 1.1 // Conversion en circonférence
    }

    /// Estime le tour de mollets
    private static func estimateCalf(
        knee: CGPoint,
        ankle: CGPoint,
        pixelsPerCm: Double
    ) -> Double? {
        let calfLength = distance(knee, ankle)
        // Estimation : mollet ≈ 0.35 × longueur jambe inférieure (approximation)
        let estimatedCircumference = calfLength * 0.35
        return (estimatedCircumference / pixelsPerCm) * 1.1 // Conversion en circonférence
    }

    /// Calcule la longueur du bras
    private static func estimateArmLength(
        shoulder: CGPoint,
        elbow: CGPoint,
        wrist: CGPoint
    ) -> Double? {
        let upperArm = distance(shoulder, elbow)
        let forearm = distance(elbow, wrist)
        return upperArm + forearm
    }

    /// Calcule la longueur de la jambe
    private static func estimateLegLength(
        hip: CGPoint,
        knee: CGPoint,
        ankle: CGPoint
    ) -> Double? {
        let thigh = distance(hip, knee)
        let shin = distance(knee, ankle)
        return thigh + shin
    }

    /// Calcule la longueur du torse
    private static func estimateTorsoLength(
        shoulder: CGPoint,
        hip: CGPoint
    ) -> Double? {
        return distance(shoulder, hip)
    }

    // MARK: - Utilitaires

    /// Calcule la distance entre deux points
    private static func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        return sqrt(Double(dx * dx + dy * dy))
    }
}
