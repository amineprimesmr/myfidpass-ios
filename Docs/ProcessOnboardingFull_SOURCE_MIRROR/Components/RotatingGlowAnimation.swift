//
//  RotatingGlowAnimation.swift
//  Process
//
//  Animation de lueur en dégradé qui tourne autour de l'écran
//  Commence lentement puis accélère progressivement
//

import SwiftUI

struct RotatingGlowAnimation: View {
    @State private var rotationAngle: Double = 0
    @State private var currentSpeed: Double = 30.0 // Vitesse actuelle en degrés/seconde
    @State private var timer: Timer?

    let progress: Double // 0.0 à 1.0 - synchronisé avec la barre de progression

    // Vitesse cible de rotation (en degrés par seconde)
    // Commence à 30°/s, accélère jusqu'à 180°/s
    private func targetRotationSpeed(progress: Double) -> Double {
        let minSpeed: Double = 30.0 // Début lent
        let maxSpeed: Double = 180.0 // Fin rapide

        // Accélération progressive basée sur la progression
        let easedProgress = easeInOutCubic(progress)
        return minSpeed + (maxSpeed - minSpeed) * easedProgress
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = max(geometry.size.width, geometry.size.height)
            let radius = screenSize * 0.85 // Rayon de rotation (85% de la taille de l'écran)
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2

            ZStack {
                // 4 lueurs en dégradé qui tournent autour de l'écran
                ForEach(0..<4) { index in
                    let angleOffset = Double(index) * 90.0 // Espacement de 90° entre chaque lueur
                    let currentAngle = (rotationAngle + angleOffset) * .pi / 180.0 // Conversion en radians

                    // Calculer la position sur le cercle
                    let x = centerX + radius * cos(currentAngle)
                    let y = centerY + radius * sin(currentAngle)

                    // Dégradé radial de couleurs (violet/bleu)
                    RadialGradient(
                        colors: [
                            Color(red: 0.85, green: 0.78, blue: 0.98).opacity(0.7),
                            Color(red: 0.70, green: 0.63, blue: 0.92).opacity(0.5),
                            Color(red: 0.50, green: 0.43, blue: 0.78).opacity(0.3),
                            Color(red: 0.20, green: 0.15, blue: 0.30).opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius * 0.35
                    )
                    .frame(width: radius * 0.7, height: radius * 0.7)
                    .position(x: x, y: y)
                    .blur(radius: 40)
                }
            }
        }
        .ignoresSafeArea(.all)
        .allowsHitTesting(false)
        .onAppear {
            startRotation()
        }
        .onChange(of: progress) { _, _ in
            // La vitesse s'ajustera automatiquement dans le timer
        }
        .onDisappear {
            // Nettoyer le timer quand la vue disparaît
            timer?.invalidate()
            timer = nil
        }
    }

    private func startRotation() {
        // Arrêter le timer existant s'il y en a un
        timer?.invalidate()

        // Timer pour animation fluide à 60 FPS
        timer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Calculer la vitesse cible basée sur la progression actuelle
            let targetSpeed = targetRotationSpeed(progress: progress)

            // Ajuster progressivement la vitesse vers la vitesse cible
            let speedDiff = targetSpeed - currentSpeed
            currentSpeed += speedDiff * 0.1 // Ajustement progressif (10% par frame)

            // Calculer l'incrément d'angle basé sur la vitesse actuelle
            let angleIncrement = currentSpeed * 0.016 // 60 FPS (0.016s = 1 frame)

            // Mettre à jour l'angle
            rotationAngle += angleIncrement

            // Garder l'angle dans la plage 0-360
            if rotationAngle >= 360 {
                rotationAngle -= 360
            }

            // Arrêter le timer si la progression est complète
            if progress >= 1.0 {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }

    // Fonction d'easing cubic pour accélération fluide et progressive
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 1 + f * f * f / 2
        }
}
}
