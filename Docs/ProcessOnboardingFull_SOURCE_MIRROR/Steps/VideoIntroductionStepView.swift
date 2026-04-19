//
//  VideoIntroductionStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import CoreMotion
import Combine

struct VideoIntroductionStepView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @StateObject private var parallaxManager = SimpleParallaxManager()

    // États pour le swipe de la page complète
    @State private var pageOffset: CGFloat = 0 // Offset de la page (0 = peek visible, screenHeight - peekHeight = complètement visible)
    @State private var isDragging = false
    @State private var hapticThreshold30: Bool = false
    @State private var hapticThreshold70: Bool = false
    @State private var previewSelectedGender: Gender? // ✅ CORRECTION: State local pour le preview
    @State private var imageLoaded = false // Pour simuler le chargement de l'image
    @State private var bounceOffset: CGFloat = 0 // Animation de bounce pour indiquer qu'on peut slider

    var onComplete: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            let peekHeight: CGFloat = 120 // Hauteur visible de la page en bas quand la vidéo se termine

            ZStack {
                // Fond noir
                Color.black
                    .ignoresSafeArea(.all)

                // Image onboarding en plein écran avec effet parallaxe 3D
                Image("onboarding")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenWidth * 1.4, height: screenHeight * 1.4) // ✅ Plus grande pour permettre le mouvement parallaxe sans espaces vides
                        .clipped()
                    .frame(width: screenWidth, height: screenHeight, alignment: .center) // ✅ Frame de contrainte centré
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                    .offset(parallaxManager.parallaxOffset) // ✅ Effet parallaxe basé sur l'inclinaison
                    .rotation3DEffect(
                        .degrees(parallaxManager.rotation3D),
                        axis: (x: 0, y: 1, z: 0) // ✅ Rotation 3D autour de l'axe Y
                    )
                        .scaleEffect(pageOffset > 0 ? 0.95 : 1.0) // Légère réduction quand la page apparaît
                        .opacity(pageOffset > 0 ? 0.7 : 1.0) // Légère transparence
                        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: pageOffset) // ✅ Plus rapide et fluide
                    .onAppear {
                        imageLoaded = true
                        parallaxManager.start() // ✅ Démarrer l'effet parallaxe
                        // Simuler la fin du "chargement" après un court délai pour permettre le swipe
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            // La page suivante peut maintenant être swipée
                        }
                    }
                    .onDisappear {
                        parallaxManager.stop() // ✅ Arrêter l'effet parallaxe
                }

                // ✅ CORRECTION: Page suivante visible dès le début (peek en bas) - peut être swipée vers le haut
                ZStack {
                    // Fond de la page avec effet glass
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .frame(width: screenWidth, height: screenHeight)

                    // Contenu de la page GenderSelectionStepView
                    GenderSelectionStepView(
                        selectedGender: $previewSelectedGender,
                        onValidationChanged: { _ in }
                    )
                        .frame(width: screenWidth, height: screenHeight)
                }
                .offset(y: screenHeight - peekHeight - pageOffset - bounceOffset)
                .opacity(1.0) // ✅ Toujours visible, même pendant la vidéo
                // ✅ Animation de bounce plus visible et rapide
                .animation(isDragging ? nil : .easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: bounceOffset)
                .gesture(
                    DragGesture(minimumDistance: 5) // ✅ Seuil réduit pour plus de réactivité
                        .onChanged { value in
                            // Seulement permettre le swipe vers le haut
                            let translation = -value.translation.height
                            if translation > 0 {
                                if !isDragging {
                                    isDragging = true
                                    hapticManager.impact(.light)
                                    // ✅ Arrêter l'animation de bounce quand l'utilisateur commence à drag
                                    withAnimation {
                                        bounceOffset = 0
                                    }
                                }

                                // Mettre à jour l'offset en temps réel avec le drag (sans animation pour fluidité)
                                let maxOffset = screenHeight - peekHeight
                                pageOffset = min(translation, maxOffset)

                                // Feedback haptique progressif (une seule fois par seuil)
                                let progress = pageOffset / maxOffset
                                if progress > 0.25 && !hapticThreshold30 {
                                    hapticThreshold30 = true
                                    hapticManager.impact(.light)
                                } else if progress > 0.65 && !hapticThreshold70 {
                                    hapticThreshold70 = true
                                    hapticManager.impact(.medium)
                                }
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let translation = -value.translation.height
                            let velocity = -value.predictedEndTranslation.height

                            // Seuil pour compléter la transition (25% de l'écran ou vitesse rapide) - ✅ Plus sensible
                            let maxOffset = screenHeight - peekHeight
                            let threshold = maxOffset * 0.25 // ✅ Réduit de 30% à 25% pour plus de facilité

                            if translation > threshold || velocity > 800 { // ✅ Seuil de vitesse réduit
                                // Transition complète : la page monte complètement - ✅ Animation ultra rapide et fluide
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    pageOffset = maxOffset
                                }

                                hapticManager.impact(.heavy)
                                hapticManager.notification(.success)

                                // Passer à la page suivante après l'animation - ✅ Plus rapide
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onComplete?()
                                }
                            } else {
                                // Retour à la position initiale (peek) - ✅ Animation rapide
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    pageOffset = 0
                                }
                                // Réinitialiser les seuils haptiques
                                hapticThreshold30 = false
                                hapticThreshold70 = false
                                hapticManager.impact(.light)

                                // ✅ Reprendre l'animation de bounce après le retour
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    if pageOffset == 0 && !isDragging {
                                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                            bounceOffset = 25 // ✅ Beaucoup plus visible (25px)
                                        }
                                    }
                                }
                            }
                        }
                )
            }
        }
        .onAppear {
            // ✅ CORRECTION: Afficher le peek de la page suivante dès le début
            // La page est déjà visible en bas avec un peek, prête à être swipée
            pageOffset = 0
            hapticManager.impact(.light)

            // ✅ Démarrer l'animation de bounce après un court délai pour indiquer qu'on peut slider
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // ✅ Plus rapide (0.5s au lieu de 1.0s)
                // Animation beaucoup plus visible de montée/descente (25 pixels) pour attirer l'attention
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    bounceOffset = 25 // ✅ Beaucoup plus visible (25px au lieu de 12px)
                }
            }

            // Simuler la fin du "chargement" après un court délai pour permettre le swipe
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Animation d'apparition de la page en bas (peek) si pas déjà swipée - ✅ Plus rapide
                if pageOffset == 0 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        pageOffset = 0 // Position initiale : juste le peek visible
                    }
                    hapticManager.notification(.success)
                }
            }
        }
    }
}

// MARK: - Simple Parallax Manager pour effet 3D

@MainActor
class SimpleParallaxManager: ObservableObject {
    @Published var parallaxOffset: CGSize = .zero
    @Published var rotation3D: Double = 0

    private let motionManager = CMMotionManager()
    private var smoothedRoll: Double = 0.0
    private var smoothedPitch: Double = 0.0

    func start() {
        guard motionManager.isDeviceMotionAvailable else {
            Logger.debug("Device motion non disponible pour effet parallaxe", category: "Onboarding")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS pour fluidité
        motionManager.showsDeviceMovementDisplay = false

        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical, to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let roll = motion.attitude.roll // Inclinaison gauche/droite
            let pitch = motion.attitude.pitch // Inclinaison avant/arrière

            // Lissage pour animation fluide (facteur de lissage)
            let smoothingFactor: Double = 0.15
            self.smoothedRoll = self.smoothedRoll * (1.0 - smoothingFactor) + roll * smoothingFactor
            self.smoothedPitch = self.smoothedPitch * (1.0 - smoothingFactor) + pitch * smoothingFactor

            // Convertir l'inclinaison en offset et rotation
            let maxTilt: Double = 0.5 // Angle maximum en radians
            let normalizedRoll = max(-1.0, min(1.0, self.smoothedRoll / maxTilt))
            let normalizedPitch = max(-1.0, min(1.0, self.smoothedPitch / maxTilt))

            // Offset pour l'effet parallaxe (réduit pour éviter les espaces noirs)
            let offsetX = normalizedRoll * 30.0  // Déplacement horizontal (réduit de 50 à 30)
            let offsetY = normalizedPitch * 20.0 // Déplacement vertical (réduit de 30 à 20)
            let rotation = normalizedRoll * 3.0   // Légère rotation 3D (réduite de 5 à 3)

            Task { @MainActor in
                // Pas d'animation pour un suivi direct et fluide du mouvement
                self.parallaxOffset = CGSize(width: offsetX, height: offsetY)
                self.rotation3D = rotation
            }
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}
