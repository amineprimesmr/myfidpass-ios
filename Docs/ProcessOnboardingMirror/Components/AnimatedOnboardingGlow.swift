//
//  AnimatedOnboardingGlow.swift
//  Process
//
//  Lueur animée qui se déplace progressivement entre les pages d'onboarding
//  Style identique à PaywallView avec animation ultra fluide
//

import SwiftUI

struct AnimatedOnboardingGlow: View {
    let currentStep: Int
    let visitedStepsCount: Int // Nombre d'étapes réellement visitées
    let totalStepsForFlow: Int // Total d'étapes pour le flux actuel

    // ✅ État pour la position animée - commence en bas
    @State private var animatedPosition: UnitPoint = UnitPoint(x: 0.5, y: 1.35)
    @State private var animatedRadius: CGFloat = 500

    // Calculer la position cible de la lueur en fonction de l'étape
    // ✅ Trajectoire qui évite le bas et le haut de l'écran
    // Commence en bas à droite, va à gauche, puis monte, puis redescend à droite
    private func calculateTargetPosition(for progressCount: Int) -> UnitPoint {
        // ✅ CORRECTION: Utiliser le total d'étapes dynamique du flux actuel au lieu d'un nombre fixe
        let totalSteps = max(1.0, Double(totalStepsForFlow))

        // ✅ Utiliser le paramètre progressCount (nombre d'étapes visitées) pour calculer la progression réelle
        let currentProgress = max(1, progressCount)
        let normalizedStep = min(1.0, Double(currentProgress) / totalSteps)

        // ✅ Trajectoire personnalisée qui évite le bas et le haut
        // 0.0-0.25 : Bas droite → Bas gauche (horizontal, y fixe en bas)
        // 0.25-0.5 : Bas gauche → Haut gauche (vertical, x fixe à gauche)
        // 0.5-0.75 : Haut gauche → Haut droite (horizontal, y fixe en haut)
        // 0.75-1.0 : Haut droite → Bas droite (vertical, x fixe à droite)

        let x: Double
        let y: Double

        if normalizedStep < 0.25 {
            // Bas droite → Bas gauche (horizontal, y fixe en bas)
            let segmentProgress = normalizedStep / 0.25
            x = 1.0 - (segmentProgress * 0.8) // De 1.0 (droite) à 0.2 (gauche)
            y = 0.9 // Bas de l'écran (mais pas tout en bas)
        } else if normalizedStep < 0.5 {
            // Bas gauche → Haut gauche (vertical, x fixe à gauche)
            let segmentProgress = (normalizedStep - 0.25) / 0.25
            x = 0.2 // Gauche
            y = 0.9 - (segmentProgress * 0.7) // De 0.9 (bas) à 0.2 (haut)
        } else if normalizedStep < 0.75 {
            // Haut gauche → Haut droite (horizontal, y fixe en haut)
            let segmentProgress = (normalizedStep - 0.5) / 0.25
            x = 0.2 + (segmentProgress * 0.8) // De 0.2 (gauche) à 1.0 (droite)
            y = 0.2 // Haut de l'écran (mais pas tout en haut)
        } else {
            // Haut droite → Bas droite (vertical, x fixe à droite)
            let segmentProgress = (normalizedStep - 0.75) / 0.25
            x = 1.0 // Droite
            y = 0.2 + (segmentProgress * 0.7) // De 0.2 (haut) à 0.9 (bas)
        }

        return UnitPoint(x: x, y: y)
    }

    // ✅ Calculer le rayon cible
    private func calculateTargetRadius(for step: Int) -> CGFloat {
        let baseRadius: CGFloat = 500
        // Variation subtile pour un effet organique
        let variation = sin(Double(step) * 0.2) * 20
        return baseRadius + CGFloat(variation)
    }

    // ✅ Fonction d'easing cubic pour mouvement ultra fluide
    private func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 1 + f * f * f / 2
        }
    }

    var body: some View {
        // ✅ Calculer la progression dans l'onboarding (0.0 = début, 1.0 = fin)
        let rawProgress = min(1.0, max(0.0, Double(visitedStepsCount) / Double(max(totalStepsForFlow, 1))))

        // ✅ ACCÉLÉRER ÉNORMÉMENT la transition vers le bleu pétant
        // Utiliser une courbe beaucoup plus agressive pour que la lueur soit bleue pétante dès ~30% du parcours
        // À 30% de progression → ~95% de bleu pétant (presque complètement bleu)
        // À 40% de progression → 100% de bleu pétant (complètement bleu)
        let progress = pow(rawProgress, 0.3) // Racine cubique pour accélérer ENCORE PLUS la transition

        // ✅ Opacité légèrement augmentée pour les premières pages (0-4: genre, âge, taille/poids, prénom)
        let isEarlyStep = currentStep <= 4

        // ✅ Détecter si la lueur est en bas ou en haut (moins visible dans ces zones)
        let isAtTopOrBottom = animatedPosition.y < 0.2 || animatedPosition.y > 0.8

        // ✅ Augmenter l'opacité si première page OU si en haut/bas
        let shouldIncreaseOpacity = isEarlyStep || isAtTopOrBottom

        // ✅ Opacités BEAUCOUP réduites pour rendre la lueur moins visible
        let centerOpacity = shouldIncreaseOpacity ? 0.15 : 0.10
        let middleOpacity = shouldIncreaseOpacity ? 0.12 : 0.08
        let outerOpacity = shouldIncreaseOpacity ? 0.08 : 0.05
        let edgeOpacity = shouldIncreaseOpacity ? 0.05 : 0.03

        // ✅ Interpoler les couleurs du BLEU (déjà bleu au début) vers le bleu PÉTANT en fonction de la progression
        // Bleu (début): RGB(0.3, 0.45, 0.95) -> Bleu PÉTANT (fin): RGB(0.2, 0.5, 1.0)
        // ✅ Couleurs de départ déjà bleues au lieu de violet
        let centerColor = interpolateColor(
            from: (r: 0.3, g: 0.45, b: 0.95), // ✅ Déjà bleu au début
            to: (r: 0.2, g: 0.5, b: 1.0), // ✅ Bleu pétant : bleu très vif et saturé
            progress: progress
        )
        let middleColor = interpolateColor(
            from: (r: 0.25, g: 0.4, b: 0.9), // ✅ Déjà bleu au début
            to: (r: 0.15, g: 0.4, b: 0.95), // ✅ Bleu pétant : bleu très vif
            progress: progress
        )
        let outerColor = interpolateColor(
            from: (r: 0.2, g: 0.35, b: 0.85), // ✅ Déjà bleu au début
            to: (r: 0.1, g: 0.35, b: 0.9), // ✅ Bleu pétant : bleu vif
            progress: progress
        )
        let edgeColor = interpolateColor(
            from: (r: 0.15, g: 0.3, b: 0.8), // ✅ Déjà bleu au début
            to: (r: 0.05, g: 0.25, b: 0.85), // ✅ Bleu pétant : bleu foncé vif
            progress: progress
        )

        RadialGradient(
            colors: [
                // ✅ Centre - couleur interpolée selon la progression
                Color(red: centerColor.r, green: centerColor.g, blue: centerColor.b).opacity(centerOpacity),
                // Milieu - couleur interpolée
                Color(red: middleColor.r, green: middleColor.g, blue: middleColor.b).opacity(middleOpacity),
                // Extérieur - couleur interpolée
                Color(red: outerColor.r, green: outerColor.g, blue: outerColor.b).opacity(outerOpacity),
                // Bords - couleur interpolée
                Color(red: edgeColor.r, green: edgeColor.g, blue: edgeColor.b).opacity(edgeOpacity),
                // Bords extérieurs - presque transparent
                Color.clear
            ],
            center: animatedPosition,
            startRadius: 0,
            endRadius: animatedRadius
        )
        .onChange(of: visitedStepsCount) { _, newValue in
            // ✅ CORRECTION: Utiliser visitedStepsCount au lieu de currentStep pour suivre le parcours réel
            let targetPosition = calculateTargetPosition(for: newValue)
            let targetRadius = calculateTargetRadius(for: newValue)

            // ✅ Animation fluide pour la position, le rayon ET la couleur
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85, blendDuration: 0.5)) {
                animatedPosition = targetPosition
                animatedRadius = targetRadius
            }
        }
        .onChange(of: totalStepsForFlow) { _, _ in
            // ✅ Recalculer la position si le total change (parcours personnalisé)
            let targetPosition = calculateTargetPosition(for: visitedStepsCount)
            let targetRadius = calculateTargetRadius(for: visitedStepsCount)

            // ✅ Animation fluide pour la position, le rayon ET la couleur
            withAnimation(.spring(response: 1.0, dampingFraction: 0.85, blendDuration: 0.5)) {
                animatedPosition = targetPosition
                animatedRadius = targetRadius
            }
        }
        .onAppear {
            // ✅ Initialiser la position au démarrage avec visitedStepsCount
            animatedPosition = calculateTargetPosition(for: visitedStepsCount)
            animatedRadius = calculateTargetRadius(for: visitedStepsCount)
        }
    }

    // ✅ Fonction pour interpoler les couleurs du violet vers le bleu PÉTANT
    private func interpolateColor(
        from: (r: Double, g: Double, b: Double),
        to: (r: Double, g: Double, b: Double),
        progress: Double
    ) -> (r: Double, g: Double, b: Double) {
        // ✅ Utiliser une courbe ULTRA agressive pour une transition TRÈS rapide vers le bleu pétant
        // Quartic ease-in (progress⁴) pour une transition ENCORE PLUS rapide
        // Cela fait que la lueur devient bleue pétante ÉNORMÉMENT plus rapidement
        let easedProgress = progress * progress * progress * progress

        return (
            r: from.r + (to.r - from.r) * easedProgress,
            g: from.g + (to.g - from.g) * easedProgress,
            b: from.b + (to.b - from.b) * easedProgress
        )
    }
}
