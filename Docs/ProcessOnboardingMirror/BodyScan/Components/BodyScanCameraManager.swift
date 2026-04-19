//
//  BodyScanCameraManager.swift
//  Process
//
//  Gestionnaire de caméra pour le scan corporel
//

import Foundation
import AVFoundation
import UIKit
import Vision
import Combine
import SwiftUI

// ✅ NOUVEAU : Enum pour la distance du corps
enum BodyDistance {
    case unknown
    case tooClose    // Trop proche
    case optimal     // Distance optimale
    case tooFar      // Trop loin

    var instruction: String {
        switch self {
        case .unknown:
            return "Positionne-toi devant la caméra"
        case .tooClose:
            return "Recule un peu"
        case .optimal:
            return "Distance parfaite ✓"
        case .tooFar:
            return "Approche-toi"
        }
    }

    var icon: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .tooClose:
            return "arrow.down.circle"
        case .optimal:
            return "checkmark.circle.fill"
        case .tooFar:
            return "arrow.up.circle"
        }
    }

    var color: Color {
        switch self {
        case .unknown:
            return .gray
        case .tooClose, .tooFar:
            return .orange
        case .optimal:
            return .green
        }
    }
}

class BodyScanCameraManager: NSObject, ObservableObject {
    var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?

    @Published var isSessionRunning = false
    @Published var isBodyDetected = false
    @Published var currentImage: UIImage?
    @Published var bodyDistance: BodyDistance = .unknown // ✅ NOUVEAU : Distance du corps
    @Published var bodyBoundingBox: CGRect? // ✅ NOUVEAU : Bounding box du corps détecté

    var onImageCaptured: ((UIImage) -> Void)?
    var onBodyDetected: ((Bool) -> Void)?

    private nonisolated(unsafe) var lastDetectionTime: Date = Date()
    private let detectionInterval: TimeInterval = 0.3 // ✅ Détection plus fréquente (0.3s au lieu de 0.5s)
    private nonisolated(unsafe) var detectionHistory: [Bool] = [] // ✅ Historique pour stabilisation
    private let historySize = 5 // ✅ Garder 5 dernières détections

    override init() {
        super.init()
    }

    @MainActor
    func startSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            Logger.error("Caméra frontale non disponible", category: "BodyScan")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(input) {
                session.addInput(input)
            }

            // Video output pour détection en temps réel
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "body.scan.camera.queue"))

            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                self.videoOutput = videoOutput
            }

            // Photo output pour capture
            let photoOutput = AVCapturePhotoOutput()
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                self.photoOutput = photoOutput
            }

            captureSession = session

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = true
                }
            }
        } catch {
            Logger.error("Erreur configuration caméra: \(error)", category: "BodyScan")
        }
    }

    @MainActor
    func stopSession() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        photoOutput = nil
        isSessionRunning = false
        isBodyDetected = false
    }

    @MainActor
    func capturePhoto() {
        guard let photoOutput = photoOutput else { return }

        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension BodyScanCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }
        let image = UIImage(cgImage: cgImage)

        // Détecter le corps avec Vision
        detectBody(in: image)
    }

    nonisolated private func detectBody(in image: UIImage) {
        guard let cgImage = image.cgImage else { return }

        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        let request = VNDetectHumanBodyPoseRequest { [weak self] request, error in
            guard let self = self else { return }

            guard error == nil,
                  let observations = request.results as? [VNHumanBodyPoseObservation],
                  !observations.isEmpty else {
                // ✅ Utiliser l'historique pour éviter les faux négatifs
                self.detectionHistory.append(false)
                if self.detectionHistory.count > self.historySize {
                    self.detectionHistory.removeFirst()
                }

                // Seulement mettre à jour si la majorité des dernières détections sont négatives
                let recentDetections = self.detectionHistory.suffix(3)
                let falseCount = recentDetections.filter { !$0 }.count

                if falseCount >= 2 { // Au moins 2/3 des dernières détections sont négatives
                    Task { @MainActor in
                        self.isBodyDetected = false
                        self.bodyDistance = .unknown
                        self.bodyBoundingBox = nil
                        self.onBodyDetected?(false)
                    }
                }
                return
            }

            // ✅ Prendre la première observation (le corps principal)
            let observation = observations[0]

            // ✅ Vérifier que c'est vraiment un corps détecté (au moins 3 points clés)
            let isRealBody = BodyPoseDetector.isBodyDetected(observation)

            // ✅ Calculer la bounding box à partir des points clés détectés
            var minX: CGFloat = 1.0
            var maxX: CGFloat = 0.0
            var minY: CGFloat = 1.0
            var maxY: CGFloat = 0.0

            // Points clés pour calculer la bounding box
            let keyPoints: [VNHumanBodyPoseObservation.JointName] = [
                .nose, .neck, .leftShoulder, .rightShoulder,
                .leftElbow, .rightElbow, .leftWrist, .rightWrist,
                .leftHip, .rightHip, .leftKnee, .rightKnee,
                .leftAnkle, .rightAnkle
            ]

            var detectedPointsCount = 0
            for pointName in keyPoints {
                if let point = try? observation.recognizedPoint(pointName),
                   point.confidence > 0.3 {
                    let location = point.location
                    minX = min(minX, location.x)
                    maxX = max(maxX, location.x)
                    minY = min(minY, location.y)
                    maxY = max(maxY, location.y)
                    detectedPointsCount += 1
                }
            }

            // ✅ Calculer la couverture du corps dans l'image
            var coverage: CGFloat = 0.0
            var normalizedBoundingBox: CGRect = .zero

            if detectedPointsCount >= 3 && minX < maxX && minY < maxY {
                // Calculer la bounding box normalisée
                let width = maxX - minX
                let height = maxY - minY

                // Ajouter un padding pour inclure les extrémités
                let padding: CGFloat = 0.1
                let paddedWidth = min(1.0, width + padding * 2)
                let paddedHeight = min(1.0, height + padding * 2)

                // Calculer la couverture
                coverage = paddedWidth * paddedHeight

                // Calculer la bounding box en pixels pour l'affichage
                let boundingBox = CGRect(
                    x: max(0, minX - padding),
                    y: max(0, minY - padding),
                    width: paddedWidth,
                    height: paddedHeight
                )

                normalizedBoundingBox = VNImageRectForNormalizedRect(
                    boundingBox,
                    Int(imageSize.width),
                    Int(imageSize.height)
                )
            }

            // ✅ Déterminer la distance
            var distance: BodyDistance = .unknown
            if isRealBody && coverage > 0 {
                if coverage > 0.35 { // Corps prend plus de 35% de l'image = trop proche
                    distance = .tooClose
                } else if coverage > 0.20 { // 20-35% = distance optimale
                    distance = .optimal
                } else if coverage > 0.10 { // 10-20% = un peu loin
                    distance = .tooFar
                } else { // < 10% = très loin
                    distance = .tooFar
                }
            }

            // ✅ Mettre à jour l'historique
            self.detectionHistory.append(isRealBody)
            if self.detectionHistory.count > self.historySize {
                self.detectionHistory.removeFirst()
            }

            // ✅ Utiliser l'historique pour stabiliser la détection (éviter clignotements)
            let recentDetections = self.detectionHistory.suffix(3)
            let trueCount = recentDetections.filter { $0 }.count
            let isStableDetected = trueCount >= 2 // Au moins 2/3 des dernières détections sont positives

            Task { @MainActor in
                self.isBodyDetected = isStableDetected
                self.bodyDistance = isStableDetected ? distance : .unknown
                self.bodyBoundingBox = isStableDetected ? normalizedBoundingBox : nil
                self.currentImage = image
                self.onBodyDetected?(isStableDetected)
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension BodyScanCameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }

        Task { @MainActor in
            self.currentImage = image
            self.onImageCaptured?(image)
        }
    }
}
