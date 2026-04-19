//
//  BodyScanService.swift
//  Process
//
//  Service principal de scan corporel - Orchestre tout le processus
//

import Foundation
import UIKit
import Vision
import AVFoundation
import Combine

@MainActor
class BodyScanService: ObservableObject {
    static let shared = BodyScanService()

    // MARK: - États publiés
    @Published var scanState: BodyScanState = .idle
    @Published var scanData: BodyScanData?
    @Published var posePoints: BodyPosePoints = BodyPosePoints()
    @Published var isBodyDetected: Bool = false

    // MARK: - Données sources
    var height: Double?
    var weight: Double?
    var age: Int?
    var gender: Gender?

    // MARK: - Images capturées
    private var frontImage: UIImage?
    private var sideImage: UIImage?
    private var currentImageSize: CGSize = .zero

    private init() {}

    // MARK: - Flux de scan

    /// Lance le scan corporel complet
    func startScan(
        height: Double?,
        weight: Double?,
        age: Int?,
        gender: Gender?
    ) {
        self.height = height
        self.weight = weight
        self.age = age
        self.gender = gender

        scanState = .preparing
        scanData = nil
        posePoints = BodyPosePoints()
        isBodyDetected = false
    }

    /// Analyse une image du corps (front ou side)
    func analyzeImage(_ image: UIImage, orientation: ScanOrientation) async {
        currentImageSize = image.size

        // Détecter les points de pose avec Vision
        let detectedPoints = await detectBodyPose(from: image)

        await MainActor.run {
            updatePosePoints(detectedPoints, for: orientation)

            // Vérifier si le corps est bien détecté
            isBodyDetected = hasEnoughPointsDetected(detectedPoints)

            // Sauvegarder l'image
            if orientation == .front {
                frontImage = image
            } else {
                sideImage = image
            }
        }
    }

    /// Finalise le scan et génère toutes les données
    func finalizeScan() async {
        guard let height = height else {
            await MainActor.run {
                scanState = .error("Taille requise pour le calibrage")
            }
            return
        }

        await MainActor.run {
            scanState = .analyzing
        }

        // Créer les données de scan
        var data = BodyScanData()
        data.scanDate = Date()
        data.height = height
        data.weight = weight
        data.age = age
        data.gender = gender
        data.frontImageData = frontImage?.jpegData(compressionQuality: 0.7)
        data.sideImageData = sideImage?.jpegData(compressionQuality: 0.7)

        // Analyser la posture
        if let frontImage = frontImage {
            data.postureAnalysis = BodyPostureAnalyzer.analyzePosture(
                from: frontImage,
                posePoints: posePoints
            )
        }

        // Estimer les mensurations
        data.measurements = BodyMeasurementEstimator.estimateMeasurements(
            posePoints: posePoints,
            imageSize: currentImageSize,
            realHeight: height
        )

        // Calculer la composition corporelle (si poids disponible)
        if let weight = weight, let age = age, let gender = gender {
            data.composition = BodyCompositionCalculator.calculate(
                height: height,
                weight: weight,
                age: age,
                gender: gender,
                measurements: data.measurements
            )
        }

        // Évaluer la qualité du scan
        data.scanQuality = evaluateScanQuality(data: data)
        data.calibrationSuccessful = height > 0

        await MainActor.run {
            scanData = data
            scanState = .completed
        }
    }

    // MARK: - Détection de pose

    /// Détecte les points de pose du corps avec Vision
    private func detectBodyPose(from image: UIImage) async -> BodyPosePoints {
        guard let cgImage = image.cgImage else {
            return BodyPosePoints()
        }

        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                var points = BodyPosePoints()

                guard error == nil,
                      let observations = request.results as? [VNHumanBodyPoseObservation],
                      let observation = observations.first else {
                    continuation.resume(returning: points)
                    return
                }

                // Extraire les points clés
                points = self.extractPosePoints(from: observation, imageSize: image.size)
                continuation.resume(returning: points)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    /// Extrait les points de pose depuis une observation Vision
    private func extractPosePoints(
        from observation: VNHumanBodyPoseObservation,
        imageSize: CGSize
    ) -> BodyPosePoints {
        var points = BodyPosePoints()

        // Convertir les coordonnées normalisées en coordonnées image
        func convertPoint(_ recognizedPoint: VNRecognizedPoint) -> CGPoint {
            let normalizedPoint = recognizedPoint.location
            // Vision utilise un système de coordonnées où (0,0) est en bas à gauche
            // SwiftUI utilise (0,0) en haut à gauche
            return CGPoint(
                x: normalizedPoint.x * imageSize.width,
                y: (1.0 - normalizedPoint.y) * imageSize.height
            )
        }

        // Extraire les points clés
        // Vision framework utilise try? pour recognizedPoint
        // Tête
        if let nose = try? observation.recognizedPoint(.nose) {
            points.nose = convertPoint(nose)
        }
        if let leftEye = try? observation.recognizedPoint(.leftEye) {
            points.leftEye = convertPoint(leftEye)
        }
        if let rightEye = try? observation.recognizedPoint(.rightEye) {
            points.rightEye = convertPoint(rightEye)
        }
        if let leftEar = try? observation.recognizedPoint(.leftEar) {
            points.leftEar = convertPoint(leftEar)
        }
        if let rightEar = try? observation.recognizedPoint(.rightEar) {
            points.rightEar = convertPoint(rightEar)
        }

        // Membres supérieurs
        if let leftShoulder = try? observation.recognizedPoint(.leftShoulder) {
            points.leftShoulder = convertPoint(leftShoulder)
        }
        if let rightShoulder = try? observation.recognizedPoint(.rightShoulder) {
            points.rightShoulder = convertPoint(rightShoulder)
        }
        if let leftElbow = try? observation.recognizedPoint(.leftElbow) {
            points.leftElbow = convertPoint(leftElbow)
        }
        if let rightElbow = try? observation.recognizedPoint(.rightElbow) {
            points.rightElbow = convertPoint(rightElbow)
        }
        if let leftWrist = try? observation.recognizedPoint(.leftWrist) {
            points.leftWrist = convertPoint(leftWrist)
        }
        if let rightWrist = try? observation.recognizedPoint(.rightWrist) {
            points.rightWrist = convertPoint(rightWrist)
        }

        // Tronc
        if let leftHip = try? observation.recognizedPoint(.leftHip) {
            points.leftHip = convertPoint(leftHip)
        }
        if let rightHip = try? observation.recognizedPoint(.rightHip) {
            points.rightHip = convertPoint(rightHip)
        }

        // Membres inférieurs
        if let leftKnee = try? observation.recognizedPoint(.leftKnee) {
            points.leftKnee = convertPoint(leftKnee)
        }
        if let rightKnee = try? observation.recognizedPoint(.rightKnee) {
            points.rightKnee = convertPoint(rightKnee)
        }
        if let leftAnkle = try? observation.recognizedPoint(.leftAnkle) {
            points.leftAnkle = convertPoint(leftAnkle)
        }
        if let rightAnkle = try? observation.recognizedPoint(.rightAnkle) {
            points.rightAnkle = convertPoint(rightAnkle)
        }

        // Calculer les points dérivés
        if let leftShoulder = points.leftShoulder, let rightShoulder = points.rightShoulder {
            points.centerShoulder = CGPoint(
                x: (leftShoulder.x + rightShoulder.x) / 2,
                y: (leftShoulder.y + rightShoulder.y) / 2
            )
            points.neck = points.centerShoulder // Approximation
        }

        if let leftHip = points.leftHip, let rightHip = points.rightHip {
            points.centerHip = CGPoint(
                x: (leftHip.x + rightHip.x) / 2,
                y: (leftHip.y + rightHip.y) / 2
            )
        }

        return points
    }

    /// Met à jour les points de pose pour une orientation donnée
    private func updatePosePoints(_ newPoints: BodyPosePoints, for orientation: ScanOrientation) {
        // Pour l'instant, on utilise les points du front
        // TODO: Combiner front + side pour meilleure précision
        posePoints = newPoints
    }

    /// Vérifie si assez de points sont détectés
    private func hasEnoughPointsDetected(_ points: BodyPosePoints) -> Bool {
        var count = 0

        if points.leftShoulder != nil { count += 1 }
        if points.rightShoulder != nil { count += 1 }
        if points.leftHip != nil { count += 1 }
        if points.rightHip != nil { count += 1 }
        if points.leftKnee != nil { count += 1 }
        if points.rightKnee != nil { count += 1 }

        return count >= 4 // Au moins 4 points principaux
    }

    /// Évalue la qualité du scan
    private func evaluateScanQuality(data: BodyScanData) -> ScanQuality {
        var qualityScore = 0

        // Points de pose détectés
        if data.postureAnalysis != nil { qualityScore += 1 }

        // Mensurations disponibles
        if let measurements = data.measurements {
            var measurementCount = 0
            if measurements.waist != nil { measurementCount += 1 }
            if measurements.chest != nil { measurementCount += 1 }
            if measurements.hips != nil { measurementCount += 1 }

            if measurementCount >= 3 { qualityScore += 1 }
        }

        // Composition calculée
        if data.composition != nil { qualityScore += 1 }

        // Images capturées
        if data.frontImageData != nil { qualityScore += 1 }

        switch qualityScore {
        case 0...1: return .poor
        case 2: return .fair
        case 3: return .good
        case 4...5: return .excellent
        default: return .unknown
        }
    }

    /// Réinitialise le service
    func reset() {
        scanState = .idle
        scanData = nil
        posePoints = BodyPosePoints()
        isBodyDetected = false
        frontImage = nil
        sideImage = nil
        height = nil
        weight = nil
        age = nil
        gender = nil
    }
}

// MARK: - Orientation de scan
enum ScanOrientation {
    case front  // Face avant
    case side   // Profil
}
