//
//  BodyScanStepView.swift
//
//  ✨ VERSION COMPLÈTE REFONDUE - Body Scan avec flux 3 poses, détection auto, capture auto, ChatGPT
//

import SwiftUI
import AVFoundation
import Vision

struct BodyScanStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @StateObject private var chatGPTService = BodyScanChatGPTService.shared
    @StateObject private var cameraManager = BodyScanCameraManager()
    @StateObject private var hapticManager = HapticManager.shared

    @Binding var height: Double
    @Binding var weight: Double
    @Binding var age: Int
    @Binding var gender: Gender?

    var onValidationChanged: ((Bool) -> Void)?
    var onComplete: (() -> Void)?
    var onBack: (() -> Void)?

    // ✨ États du scan
    @State private var currentPose: BodyPose = .front
    @State private var capturedImages: [BodyPose: UIImage] = [:]
    @State private var isBodyDetected: Bool = false
    @State private var isPoseOptimal: Bool = false
    @State private var isAnalyzing: Bool = false
    @State private var scanData: BodyScanData?
    @State private var chatGPTResult: BodyScanChatGPTResult?
    @State private var errorMessage: String?

    // États de progression
    @State private var showInstructions: Bool = true
    @State private var showCamera: Bool = false
    @State private var showResults: Bool = false
    @State private var isCapturing: Bool = false

    // États pour HealthKit
    @State private var healthKitData: HealthKitDataForScan?

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if showInstructions {
                instructionsViewWithButton
            } else if showCamera {
                cameraView
            } else if isAnalyzing {
                analyzingView
            } else if showResults, let scanData = scanData {
                resultsView(scanData: scanData)
            }

            // Titre en overlay - uniquement si pas en mode caméra
            if !showCamera && !showInstructions {
                VStack {
                    OnboardingTitleView(titleText)
                        .padding(.top, OnboardingConstants.titleTopPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                    Spacer()
                }
            }
        }
        .onAppear {
            loadHealthKitData()
            requestCameraPermission()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }

    // MARK: - Titre dynamique

    private var titleText: String {
        if showInstructions {
            return "Scanne ton corps"
        } else if showCamera {
            switch currentPose {
            case .front: return "Pose 1/3 : Face avant"
            case .side: return "Pose 2/3 : Profil"
            case .back: return "Pose 3/3 : Dos"
            }
        } else if isAnalyzing {
            return "Analyse en cours..."
        } else {
            return "Résultats du scan"
        }
    }

    // MARK: - Vue Instructions avec vidéo

    @StateObject private var videoManager = BodyScanVideoPlayerManager()
    @State private var videoPlayer: AVPlayer?

    private var instructionsViewWithButton: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                // Vidéo body scan en arrière-plan (prend presque toute la page)
                if let player = videoPlayer {
                    BodyScanVideoPlayerView(player: player, screenSize: geometry.size)
                        .frame(width: geometry.size.width, height: geometry.size.height * 0.85)
                        .clipped()
                        .ignoresSafeArea()
                } else {
                    // Placeholder pendant le chargement
                    Color.black
                }

                // Bouton retour en haut à gauche
                VStack {
                    HStack {
                        Button(action: {
                            hapticManager.impact(.light)
                            onBack?()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 34, height: 34)
                        }
                        .glassStyle()
                        .buttonBorderShape(.circle)
                        .padding(.top, 50)
                        .padding(.leading, 20)

                        Spacer()
                    }

                    Spacer()
                }

                // Bouton "Commencer le scan" et texte "Scanner plus tard" en bas
                VStack(spacing: 16) {
                    Spacer()

                    Button(action: {
                        hapticManager.impact(.medium)
                        startScanning()
                    }) {
                        Text("Commencer le scan")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)

                    // Texte "Scanner plus tard" pour passer l'étape
                    Button(action: {
                        hapticManager.impact(.light)
                        onComplete?()
                    }) {
                        Text("Scanner plus tard")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            setupVideo()
        }
        .onDisappear {
            videoPlayer?.pause()
        }
    }

    private func setupVideo() {
        // Chercher la vidéo body scan (essayer plusieurs noms possibles)
        let videoNames = ["bodyScan", "bodyscan", "body_scan", "body-scan"]
        var player: AVPlayer?

        for videoName in videoNames {
            if let p = videoManager.setupPlayer(videoName: videoName) {
                player = p
                break
            }
        }

        // Si aucune vidéo trouvée, on continue sans vidéo (pas de crash)
        videoPlayer = player
        // ✅ La vidéo se lance automatiquement dans setupPlayer quand elle est prête
    }

    // MARK: - Vue Caméra

    private var cameraView: some View {
        ZStack {
            // Preview caméra en plein écran
            BodyScanCameraPreviewLayer(cameraManager: cameraManager)
                .ignoresSafeArea(.all)

            // Overlay silhouette guide (plus grande et plus visible)
            BodySilhouetteGuideView(
                pose: currentPose,
                isBodyDetected: isBodyDetected,
                isPoseOptimal: isPoseOptimal,
                instructionText: "" // Pas de texte - silhouette seule
            )

            // Indicateurs minimaux en haut
            VStack {
                HStack {
                    Spacer()

                    // Indicateur de progression discret
                    HStack(spacing: 6) {
                        ForEach([BodyPose.front, .side, .back], id: \.self) { pose in
                            Circle()
                                .fill(poseColor(for: pose))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.4))
                    )
                    .padding(.top, 60)
                    .padding(.trailing, 20)
                }

                Spacer()

                // ✅ Indicateurs en bas : Distance + Pose optimale
                VStack(spacing: 12) {
                    // Indicateur de distance (toujours visible si détecté)
                    if cameraManager.isBodyDetected && cameraManager.bodyDistance != .optimal {
                        HStack(spacing: 10) {
                            Image(systemName: cameraManager.bodyDistance.icon)
                                .font(.system(size: 18))
                                .foregroundColor(cameraManager.bodyDistance.color)
                            Text(cameraManager.bodyDistance.instruction)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule()
                                .fill(cameraManager.bodyDistance.color.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(cameraManager.bodyDistance.color.opacity(0.6), lineWidth: 1.5)
                                )
                        )
                        .shadow(color: cameraManager.bodyDistance.color.opacity(0.3), radius: 8, x: 0, y: 4)
                        .transition(.opacity.combined(with: .scale).combined(with: .move(edge: .bottom)))
                    }

                    // Indicateur de pose optimale
                    if isPoseOptimal && cameraManager.bodyDistance == .optimal {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.green)
                            Text("Pose optimale")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.25))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                                )
                        )
                        .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        .transition(.opacity.combined(with: .scale).combined(with: .move(edge: .bottom)))
                    } else if !cameraManager.isBodyDetected {
                        // Aucun corps détecté
                        HStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .font(.system(size: 18))
                                .foregroundColor(.orange)
                            Text("Place-toi devant la caméra")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 22)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
                                )
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .onChange(of: cameraManager.isBodyDetected) { _, newValue in
            isBodyDetected = newValue
        }
        .onChange(of: cameraManager.bodyDistance) { _, newValue in
            // Vibration tactile selon la distance
            if newValue == .optimal {
                hapticManager.notification(.success)
            } else if newValue == .tooClose || newValue == .tooFar {
                hapticManager.impact(.light)
            }
        }
    }

    // MARK: - Vue Analyse

    private var analyzingView: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: OnboardingConstants.titleAreaHeight + OnboardingConstants.titleToContentSpacing + 40)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2.0)

            Text("Analyse ChatGPT en cours...")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Text("Cette analyse peut prendre quelques secondes")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white.opacity(0.6))
                .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Vue Résultats

    private func resultsView(scanData: BodyScanData) -> some View {
        BodyScanResultsView(scanData: scanData, chatGPTResult: chatGPTResult) {
            hapticManager.impact(.medium)
            onComplete?()
        }
    }

    // MARK: - Helpers

    private var poseInstructionText: String {
        switch currentPose {
        case .front:
            return "Positionne-toi face à la caméra. Assure-toi que tes épaules sont alignées."
        case .side:
            return "Tourne-toi de profil. Un seul côté doit être visible."
        case .back:
            return "Tourne-toi complètement. Ton dos doit être face à la caméra."
        }
    }

    private func poseColor(for pose: BodyPose) -> Color {
        if pose == currentPose {
            return isPoseOptimal ? .green : .blue
        } else if capturedImages[pose] != nil {
            return .green
        } else {
            return .white.opacity(0.3)
        }
    }

    // MARK: - Actions

    private func loadHealthKitData() {
        Task {
            // Récupérer les données HealthKit si disponibles
            let healthData = HealthKitDataForScan(
                restingHeartRate: healthManager.restingHeartRate,
                heartRateVariability: healthManager.heartRateVariability,
                vo2Max: healthManager.vo2Max,
                bodyFatPercentage: 0 // TODO: Récupérer depuis HealthKit si disponible
            )

            await MainActor.run {
                self.healthKitData = healthData
            }
        }
    }

    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        errorMessage = "Accès à la caméra requis"
                    }
                }
            }
        default:
            errorMessage = "Accès à la caméra requis"
        }
    }

    private func startScanning() {
        withAnimation {
            showInstructions = false
            showCamera = true
        }

        currentPose = .front
        cameraManager.startSession()
        setupPoseDetection()
    }

    private func setupPoseDetection() {
        // Détecter la pose en temps réel et capturer automatiquement quand optimale
        cameraManager.onBodyDetected = { detected in
            Task { @MainActor in
                self.isBodyDetected = detected

                if detected, let currentImage = self.cameraManager.currentImage {
                    await self.checkPoseOptimal(image: currentImage)
                } else {
                    self.isPoseOptimal = false
                }
            }
        }
    }

    private func checkPoseOptimal(image: UIImage) async {
        let isOptimal = await detectOptimalPose(image: image, pose: currentPose)

        await MainActor.run {
            isPoseOptimal = isOptimal

            // ✨ CAPTURE AUTOMATIQUE quand pose optimale (avec délai de stabilité)
            if isOptimal && capturedImages[currentPose] == nil {
                // Utiliser un flag pour éviter captures multiples
                if !isCapturing {
                    isCapturing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        Task { @MainActor in
                            await self.captureCurrentPose()
                            self.isCapturing = false
                        }
                    }
                }
            }
        }
    }

    private func detectOptimalPose(image: UIImage, pose: BodyPose) async -> Bool {
        guard let cgImage = image.cgImage else { return false }

        return await withCheckedContinuation { continuation in
            let request = VNDetectHumanBodyPoseRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNHumanBodyPoseObservation],
                      let observation = observations.first else {
                    continuation.resume(returning: false)
                    return
                }

                let isOptimal: Bool
                switch pose {
                case .front:
                    isOptimal = BodyPoseDetector.isFrontPoseOptimal(observation, imageSize: image.size)
                case .side:
                    isOptimal = BodyPoseDetector.isSidePoseOptimal(observation, imageSize: image.size)
                case .back:
                    isOptimal = BodyPoseDetector.isBackPoseOptimal(observation, imageSize: image.size)
                }

                continuation.resume(returning: isOptimal)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }

    private func captureCurrentPose() async {
        hapticManager.notification(.success)

        // Utiliser un Task pour gérer la capture asynchrone
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let previousCallback = cameraManager.onImageCaptured

            cameraManager.onImageCaptured = { image in
                Task { @MainActor in
                    self.capturedImages[self.currentPose] = image
                    continuation.resume()
                }

                // Restaurer le callback précédent si nécessaire
                if let previous = previousCallback {
                    self.cameraManager.onImageCaptured = previous
                }
            }

            cameraManager.capturePhoto()
        }

        // Passer à la pose suivante après capture
        await moveToNextPose()
    }

    private func moveToNextPose() async {
        // Animation de transition
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s

        switch currentPose {
        case .front:
            currentPose = .side
            isPoseOptimal = false
        case .side:
            currentPose = .back
            isPoseOptimal = false
        case .back:
            // Toutes les poses capturées, analyser
            await analyzeAllPoses()
        }
    }

    private func analyzeAllPoses() async {
        guard let frontImage = capturedImages[.front],
              let sideImage = capturedImages[.side],
              let backImage = capturedImages[.back] else {
            await MainActor.run {
                errorMessage = "Impossible de capturer toutes les poses"
            }
            return
        }

        await MainActor.run {
            showCamera = false
            isAnalyzing = true
        }

        do {
            // Appeler ChatGPT avec toutes les données
            let result = try await chatGPTService.analyzeBodyScan(
                frontImage: frontImage,
                sideImage: sideImage,
                backImage: backImage,
                height: height > 0 ? height : nil,
                weight: weight > 0 ? weight : nil,
                age: age > 0 ? age : nil,
                gender: gender,
                healthData: healthKitData
            )

            // Convertir en BodyScanData
            let convertedData = BodyScanChatGPTService.convertToBodyScanData(
                chatGPTResult: result,
                frontImage: frontImage,
                sideImage: sideImage,
                backImage: backImage,
                height: height > 0 ? height : nil,
                weight: weight > 0 ? weight : nil,
                age: age > 0 ? age : nil,
                gender: gender
            )

            await MainActor.run {
                self.scanData = convertedData
                self.chatGPTResult = result // ✅ Stocker aussi le résultat ChatGPT complet
                self.isAnalyzing = false
                self.showResults = true
                onValidationChanged?(true)
            }

        } catch {
            await MainActor.run {
                errorMessage = "Erreur d'analyse: \(error.localizedDescription)"
                isAnalyzing = false
            }
        }
    }
}

// MARK: - Composant Instruction
struct InstructionItem: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 32)

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()
        }
    }
}
