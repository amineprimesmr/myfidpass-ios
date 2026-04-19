//
//  BodyPoseDetector.swift
//
//  Détecteur de pose optimale pour chaque angle (face, profil, dos)
//

import Foundation
import UIKit
import Vision

/// Détecte si la pose du corps est optimale pour un angle donné
class BodyPoseDetector {

    /// Détecte si la pose est optimale pour une vue de face
    static func isFrontPoseOptimal(_ observation: VNHumanBodyPoseObservation, imageSize: CGSize) -> Bool {
        // Pour la vue de face, on vérifie :
        // 1. Les épaules sont alignées horizontalement
        // 2. Le corps est centré
        // 3. Les bras sont visibles et symétriques

        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              leftShoulder.confidence > 0.5,
              rightShoulder.confidence > 0.5 else {
            return false
        }

        // Vérifier l'alignement horizontal des épaules (tolérance de 5% de la hauteur d'image)
        let shoulderHeightDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
        let tolerance = imageSize.height * 0.05
        guard shoulderHeightDiff < tolerance else {
            return false
        }

        // Vérifier que le corps est centré (épaules au centre de l'image ± 20%)
        let shoulderCenterX = (leftShoulder.location.x + rightShoulder.location.x) / 2.0
        let imageCenterX = 0.5
        let centerOffset = abs(shoulderCenterX - imageCenterX)
        guard centerOffset < 0.20 else {
            return false
        }

        // Vérifier la présence des bras (au moins un)
        let hasLeftArm = (try? observation.recognizedPoint(.leftWrist))?.confidence ?? 0 > 0.3
        let hasRightArm = (try? observation.recognizedPoint(.rightWrist))?.confidence ?? 0 > 0.3
        guard hasLeftArm || hasRightArm else {
            return false
        }

        return true
    }

    /// Détecte si la pose est optimale pour une vue de profil
    static func isSidePoseOptimal(_ observation: VNHumanBodyPoseObservation, imageSize: CGSize) -> Bool {
        // Pour la vue de profil, on vérifie :
        // 1. Le corps est bien de profil (une épaule plus visible que l'autre)
        // 2. Le corps est centré verticalement
        // 3. Les points clés du profil sont visibles

        // ✅ CRITÈRE PRINCIPAL : Différence de visibilité ET position des épaules
        let leftShoulderConf = (try? observation.recognizedPoint(.leftShoulder))?.confidence ?? 0
        let rightShoulderConf = (try? observation.recognizedPoint(.rightShoulder))?.confidence ?? 0
        let leftShoulderPoint = try? observation.recognizedPoint(.leftShoulder)
        let rightShoulderPoint = try? observation.recognizedPoint(.rightShoulder)

        let maxShoulderConf = max(leftShoulderConf, rightShoulderConf)

        // ✅ Vérification 1 : Au moins une épaule doit être bien visible
        guard maxShoulderConf > 0.4 else {
            return false
        }

        // ✅ Vérification 2 : Pour un vrai profil, les épaules ne doivent PAS être alignées horizontalement
        // Si les deux épaules sont détectées avec bonne confiance, elles doivent être décalées en Y
        if let leftShoulder = leftShoulderPoint, let rightShoulder = rightShoulderPoint,
           leftShoulderConf > 0.3 && rightShoulderConf > 0.3 {
            // Pour un profil, les épaules doivent être décalées verticalement (pas alignées)
            let shoulderHeightDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
            let toleranceY = imageSize.height * 0.10 // 10% de tolérance pour l'alignement vertical

            // Si les épaules sont alignées verticalement, c'est face/dos, pas profil
            if shoulderHeightDiff < toleranceY {
                return false
            }
        }

        // ✅ Vérification 3 : Une épaule doit être significativement plus visible que l'autre
        // (mais on accepte aussi si une seule épaule est visible avec bonne confiance)
        let shoulderDiff = abs(leftShoulderConf - rightShoulderConf)
        let minShoulderConf = min(leftShoulderConf, rightShoulderConf)

        // Accepter si :
        // - Différence significative (>= 0.15) ET une épaule bien visible (>= 0.4), OU
        // - Une seule épaule bien visible (l'autre très faible < 0.2)
        let hasSignificantDiff = shoulderDiff >= 0.15 && maxShoulderConf >= 0.4
        let hasOnlyOneShoulder = maxShoulderConf >= 0.4 && minShoulderConf < 0.2

        guard hasSignificantDiff || hasOnlyOneShoulder else {
            return false // Les deux épaules sont trop équivalentes en visibilité
        }

        // ✅ ASSOUPLI : Vérifier la présence de points clés du corps (cou, hanches, chevilles)
        // Ne plus exiger le nez avec confiance > 0.5 (le nez peut être moins visible de profil)
        let neckConf = (try? observation.recognizedPoint(.neck))?.confidence ?? 0
        let hasNeck = neckConf > 0.3 // ✅ Seuil réduit de 0.5 à 0.3

        // Vérifier la présence des hanches (plus fiables que les chevilles)
        let hasLeftHip = (try? observation.recognizedPoint(.leftHip))?.confidence ?? 0 > 0.3
        let hasRightHip = (try? observation.recognizedPoint(.rightHip))?.confidence ?? 0 > 0.3
        let hasHips = hasLeftHip || hasRightHip

        // Vérifier la présence des jambes (chevilles ou genoux)
        let hasLeftAnkle = (try? observation.recognizedPoint(.leftAnkle))?.confidence ?? 0 > 0.2
        let hasRightAnkle = (try? observation.recognizedPoint(.rightAnkle))?.confidence ?? 0 > 0.2
        let hasLeftKnee = (try? observation.recognizedPoint(.leftKnee))?.confidence ?? 0 > 0.2
        let hasRightKnee = (try? observation.recognizedPoint(.rightKnee))?.confidence ?? 0 > 0.2
        let hasLegs = hasLeftAnkle || hasRightAnkle || hasLeftKnee || hasRightKnee

        // ✅ ASSOUPLI : Au moins 2 des 3 conditions (cou, hanches, jambes) doivent être remplies
        var validConditions = 0
        if hasNeck { validConditions += 1 }
        if hasHips { validConditions += 1 }
        if hasLegs { validConditions += 1 }

        guard validConditions >= 2 else {
            return false // Pas assez de points clés détectés
        }

        // ✅ ASSOUPLI : Vérifier le centrage vertical (tête dans la moitié supérieure, pas nécessairement < 0.4)
        if let nose = try? observation.recognizedPoint(.nose), nose.confidence > 0.3 {
            guard nose.location.y < 0.5 else {
                return false // Tête trop basse
            }
        } else if neckConf > 0.3, let neck = try? observation.recognizedPoint(.neck) {
            // Utiliser le cou comme référence si le nez n'est pas détecté
            guard neck.location.y < 0.5 else {
                return false
            }
        }

        return true
    }

    /// Détecte si la pose est optimale pour une vue de dos
    static func isBackPoseOptimal(_ observation: VNHumanBodyPoseObservation, imageSize: CGSize) -> Bool {
        // Pour la vue de dos, on vérifie :
        // 1. Les épaules sont alignées (similaire à face mais dos visible)
        // 2. Le corps est centré
        // 3. Pas de visage visible (ou très peu)

        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              leftShoulder.confidence > 0.5,
              rightShoulder.confidence > 0.5 else {
            return false
        }

        // Vérifier l'alignement horizontal des épaules
        let shoulderHeightDiff = abs(leftShoulder.location.y - rightShoulder.location.y)
        let tolerance = imageSize.height * 0.05
        guard shoulderHeightDiff < tolerance else {
            return false
        }

        // Pour le dos, le nez devrait être moins visible ou absent
        let noseConf = (try? observation.recognizedPoint(.nose))?.confidence ?? 0
        guard noseConf < 0.4 else {
            return false // Trop de visage visible = pas le dos
        }

        // Vérifier la présence du bassin (hanches)
        let hasLeftHip = (try? observation.recognizedPoint(.leftHip))?.confidence ?? 0 > 0.3
        let hasRightHip = (try? observation.recognizedPoint(.rightHip))?.confidence ?? 0 > 0.3
        guard hasLeftHip || hasRightHip else {
            return false
        }

        return true
    }

    /// Détecte si un corps est présent dans l'image
    static func isBodyDetected(_ observation: VNHumanBodyPoseObservation) -> Bool {
        // Vérifier qu'au moins quelques points clés sont détectés avec confiance suffisante
        let keyPoints: [VNHumanBodyPoseObservation.JointName] = [
            .neck, .leftShoulder, .rightShoulder, .leftHip, .rightHip
        ]

        var detectedPoints = 0
        for pointName in keyPoints {
            if let point = try? observation.recognizedPoint(pointName),
               point.confidence > 0.3 {
                detectedPoints += 1
            }
        }

        // Au moins 3 points clés doivent être détectés
        return detectedPoints >= 3
    }
}
