//
//  DiscountWheelView.swift
//  Process
//
//  Roulette de réduction avec gamification incroyable
//
//  Voir aussi : DiscountWheelComponents
//

import SwiftUI

struct DiscountWheelView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    let onDiscountSelected: (Int) -> Void // Pourcentage de réduction

    @State private var isSpinning = false
    @State private var rotationAngle: Double = 60.0 // Angle initial pour que la flèche pointe au centre de la première section (section 0, centre à -60°, donc on tourne de 60° pour l'amener à 0°)
    @State private var selectedDiscount: Int = 0
    @State private var showResult = false
    @State private var spinCount = 0
    @State private var canSpinAgain = false
    @State private var showRetryPopup = false
    @State private var hasScheduledExitNotification = false // Flag pour éviter les doublons
    @State private var wheelScale: CGFloat = 1.0 // Pour l'effet de scale pendant le spin

    // Sections de la roulette avec couleurs différentes et alternées
    // 6 sections : 1x -10%, 1x 0%, 1x "perdu", 1x -30%, 1x cadeau
    private let wheelSections: [WheelSection] = [
        WheelSection(value: -10, color: Color(red: 0.20, green: 0.20, blue: 0.25), icon: "percent", isDark: true), // Noir/gris foncé (-10% à la place du cadeau)
        WheelSection(value: -999, color: Color(red: 0.95, green: 0.95, blue: 0.98), icon: "xmark.circle.fill", isDark: false), // Blanc/clair ("perdu" - valeur spéciale -999)
        WheelSection(value: 0, color: Color(red: 0.20, green: 0.20, blue: 0.25), icon: "percent", isDark: true), // Noir/gris foncé
        WheelSection(value: 0, color: Color(red: 0.95, green: 0.95, blue: 0.98), icon: "percent", isDark: false), // Blanc/clair
        WheelSection(value: -30, color: Color(red: 0.20, green: 0.20, blue: 0.25), icon: "gift.fill", isGift: true, isDark: true), // Noir/gris foncé (cadeau)
        WheelSection(value: -30, color: Color(red: 0.95, green: 0.95, blue: 0.98), icon: "percent", isDark: false) // Blanc/clair (-30%)
    ]

    private let sectionAngle: Double = 360.0 / 6.0 // 6 sections (60° chacune)

    var body: some View {
        ZStack {
            // Fond noir complet
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // Titre
                VStack(spacing: 12) {
                    Text(spinCount == 0 ? "Tourne la roue pour débloquer une remise secrète" : "Dernière chance...")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 40)

                Spacer()

                // Roulette avec effets 3D améliorés
                ZStack {
                    // Ombre portée de la roulette (effet 3D)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.black.opacity(0.4),
                                    Color.black.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 140,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .offset(y: 8)
                        .blur(radius: 20)

                    // Roulette principale avec effets 3D
                    ZStack {
                        // Lueur extérieure animée
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(isSpinning ? 0.3 : 0.1),
                                        Color.white.opacity(0.0)
                                    ],
                                    center: .center,
                                    startRadius: 150,
                                    endRadius: 165
                                )
                            )
                            .frame(width: 330, height: 330)
                            .blur(radius: 10)

                        // Contour extérieur avec effet métallique
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.6),
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 5
                            )
                            .frame(width: 312, height: 312)
                            .shadow(color: .white.opacity(0.3), radius: 8, x: -2, y: -2)
                            .shadow(color: .black.opacity(0.5), radius: 8, x: 2, y: 2)

                        // Contour noir épais avec relief
                        Circle()
                            .stroke(Color.black, lineWidth: 14)
                            .frame(width: 304, height: 304)
                            .shadow(color: .black.opacity(0.8), radius: 4, x: 0, y: 2)

                        // Contour intérieur avec effet de profondeur
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.05)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 300, height: 300)

                        // Roulette avec effet de profondeur et animation fluide
                        WheelView(
                            sections: wheelSections,
                            rotationAngle: rotationAngle,
                            isSpinning: isSpinning
                        )
                        .frame(width: 300, height: 300)
                        .clipShape(Circle())
                        .scaleEffect(wheelScale)
                        .shadow(color: .black.opacity(0.6), radius: 15, x: 0, y: 5)
                        .shadow(color: .white.opacity(0.1), radius: 10, x: 0, y: -3)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: wheelScale)

                        // Image Tournette au centre avec effet 3D
                        ZStack {
                            // Ombre de la tournette
                            Image("Tournette")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(rotationAngle))
                                .opacity(0.3)
                                .offset(x: 2, y: 2)
                                .blur(radius: 3)

                            // Tournette principale
                            Image("Tournette")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(rotationAngle))
                                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)
                        }
                    }

                    // Pointeur fixe avec effets 3D améliorés
                    VStack(spacing: 0) {
                        ZStack {
                            // Ombre portée du pointeur
                            WheelPointer()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.black.opacity(0.5),
                                            Color.black.opacity(0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 36, height: 46)
                                .offset(x: 2, y: 3)
                                .blur(radius: 4)

                            // Lueur autour du pointeur
                            WheelPointer()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.white.opacity(0.4),
                                            Color.white.opacity(0.0)
                                        ],
                                        center: .center,
                                        startRadius: 5,
                                        endRadius: 20
                                    )
                                )
                                .frame(width: 40, height: 50)
                                .blur(radius: 8)

                            // Pointeur principal avec effet métallique
                            WheelPointer()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.15, green: 0.15, blue: 0.2),
                                            Color.black,
                                            Color(red: 0.1, green: 0.1, blue: 0.15)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 32, height: 42)
                                .overlay(
                                    WheelPointer()
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.8),
                                                    Color.white.opacity(0.3)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                        .frame(width: 32, height: 42)
                                )
                                .shadow(color: .white.opacity(0.3), radius: 4, x: -1, y: -1)
                                .shadow(color: .black.opacity(0.8), radius: 6, x: 1, y: 3)
                        }
                    }
                    .offset(y: -150)
                }
                .padding(.vertical, 40)

                // Bouton de spin avec effets 3D améliorés
                if !isSpinning {
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        spinWheel()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 22, weight: .bold))
                                .symbolEffect(.pulse, options: .repeating)

                            Text(spinCount == 0 ? "Faire tourner" : "Réessayer")
                                .font(.system(size: 20, weight: .black))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(
                            ZStack {
                                // Ombre portée
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(Color.black.opacity(0.3))
                                    .offset(x: 0, y: 4)
                                    .blur(radius: 8)

                                // Gradient principal avec effet métallique
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.75, green: 0.68, blue: 0.95),
                                        Color(red: 0.70, green: 0.63, blue: 0.92),
                                        Color(red: 0.80, green: 0.73, blue: 0.97)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .cornerRadius(32)

                                // Reflet lumineux
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                                .cornerRadius(32)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.5),
                                            Color.white.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: Color(red: 0.70, green: 0.63, blue: 0.92).opacity(0.5), radius: 20, x: 0, y: 8)
                        .shadow(color: Color(red: 0.70, green: 0.63, blue: 0.92).opacity(0.3), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSpinning)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                } else {
                    // Animation de chargement améliorée pendant le spin
                    HStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("En cours...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(height: 64)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .opacity(0.9)
                }

                Spacer()
            }

            // Popup de retry (quand on obtient 0% au premier tour)
            if showRetryPopup {
                RetryPopupView(
                    onDismiss: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showRetryPopup = false
                        }
                    },
                    onRetry: {
                        // Fermer le popup et relancer la roue
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showRetryPopup = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            spinWheel()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Overlay de résultat
            if showResult {
                ResultOverlay(
                    discount: selectedDiscount,
                    isGift: wheelSections.first(where: { $0.value == selectedDiscount })?.isGift ?? false,
                    onDismiss: {
                        if spinCount == 1 && selectedDiscount != -100 {
                            // Si premier spin et pas cadeau, on peut réessayer
                            canSpinAgain = true
                            showResult = false
                        } else {
                            // Appliquer la réduction et fermer
                            onDiscountSelected(selectedDiscount)
                            dismiss()
                        }
                    },
                    canSpinAgain: canSpinAgain && spinCount == 1
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            // Lancer automatiquement la roulette la première fois
            if spinCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    spinWheel()
                }
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Quand l'app passe en arrière-plan et qu'on est sur la page roulette
            if oldPhase == .active && (newPhase == .background || newPhase == .inactive) {
                scheduleExitNotificationIfNeeded()
            }
        }
        .onDisappear {
            // Quand l'utilisateur quitte la page roulette, programmer une notification
            scheduleExitNotificationIfNeeded()
        }
    }

    private func spinWheel() {
        guard !isSpinning else { return }

        HapticManager.shared.impact(.medium)
        isSpinning = true
        showResult = false

        // Effet de scale au début du spin
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            wheelScale = 0.95
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                wheelScale = 1.0
            }
        }

        // Déterminer le résultat selon les règles
        let result: Int
        if spinCount == 0 {
            // Premier spin : toujours 0%
            result = 0
        } else {
            // Deuxième spin : toujours le cadeau
            result = -100
        }

        selectedDiscount = result

        // Trouver l'index de la section gagnante
        let winningIndex: Int
        if spinCount == 0 && result == 0 {
            // Premier spin : toujours prendre la première section 0% (index 2)
            winningIndex = 2
        } else if spinCount == 1 && result == -100 {
            // Deuxième spin : toujours prendre la section cadeau (index 5 maintenant)
            winningIndex = 5
        } else {
            // Pour les autres cas, trouver la première occurrence
            guard let index = wheelSections.firstIndex(where: { $0.value == result }) else {
                Logger.error("Section avec valeur \(result) introuvable", category: "DiscountWheel")
                return
            }
            winningIndex = index
        }

        // Log pour débogage
        Logger.debug("Spin \(spinCount): Résultat = \(result)%, Section = index \(winningIndex)", category: "DiscountWheel")

        // ✅ CALCUL PRÉCIS POUR ALIGNEMENT PARFAIT AU CENTRE D'UN ÉLÉMENT
        // 
        // STRUCTURE :
        // - 6 sections de 60° chacune
        // - Section 0 : startAngle = -90°, centre = -90° + 30° = -60° (dans système non roté)
        // - Section 1 : startAngle = -30°, centre = -30° + 30° = 0°
        // - Section 2 : startAngle = 30°, centre = 30° + 30° = 60°
        // - Section 3 : startAngle = 90°, centre = 90° + 30° = 120°
        // - Pointeur fixe en haut (0°)
        // - Angle initial rotationAngle = 60° (section 0 alignée : -60° + 60° = 0°)
        //
        // PROBLÈME : La roulette s'arrête entre deux éléments
        // SOLUTION : Calculer l'angle exact pour que le CENTRE de la section soit à 0° (sous le pointeur)
        //
        // FORMULE SIMPLIFIÉE ET CORRIGÉE :
        // Le centre de la section winningIndex dans le système NON ROTATÉ est :
        //   centerNonRotated = winningIndex * 60 - 60
        //
        // Pour aligner ce centre EXACTEMENT sous le pointeur (0°), on doit avoir :
        //   centerNonRotated + rotationAngle = 0°
        //   Donc : rotationAngle = -centerNonRotated
        //
        // EXEMPLES :
        // - Section 0 : center = -60° → rotationAngle = 60° ✓
        // - Section 1 : center = 0° → rotationAngle = 0° ✓
        // - Section 3 : center = 120° → rotationAngle = 240° ✓

        // ✅ CALCUL PRÉCIS DU CENTRE ET DE L'ANGLE CIBLE
        // Les sections sont positionnées avec : startAngle = index * 60 - 90
        // Le centre de chaque section est : startAngle + 30 = index * 60 - 60
        // 
        // PROBLÈME : La roulette s'arrête entre deux éléments
        // SOLUTION : Calculer l'angle exact en tenant compte de l'angle initial
        //
        // L'angle initial est de 60° (pour aligner la section 0)
        // Dans le système roté, le centre de la section winningIndex est à :
        //   centerRotated = (index * 60 - 60) + 60 = index * 60
        //
        // Pour aligner le centre à 0° (sous le pointeur), on doit avoir :
        //   centerRotated + rotationAngle = 0°
        //   Donc : rotationAngle = -centerRotated = -index * 60
        //
        // Mais on doit tenir compte de l'angle initial de 60°
        // Donc : rotationAngle = 60 - index * 60 = 60 * (1 - index)

        // Calcul direct
        let targetRotationRaw = 60.0 * (1.0 - Double(winningIndex))

        // Normaliser entre 0 et 360
        var targetRotation = targetRotationRaw
        while targetRotation < 0 {
            targetRotation += 360.0
        }
        while targetRotation >= 360.0 {
            targetRotation -= 360.0
        }

        // ✅ FORCER LA PRÉCISION EXACTE
        targetRotation = round(targetRotation * 100000) / 100000

        // ✅ CORRECTION CRITIQUE : Si la roulette s'arrête entre deux éléments,
        // il y a probablement un décalage dans le système de coordonnées
        // On ajoute un offset pour compenser et aligner la flèche au centre d'un élément
        // L'offset négatif décale la roulette dans le sens inverse pour que la flèche pointe au centre
        let correctionOffset = -30.0 // Augmenté pour mieux centrer la flèche sur l'élément
        targetRotation += correctionOffset

        // Renormaliser après l'ajustement
        while targetRotation < 0 {
            targetRotation += 360.0
        }
        while targetRotation >= 360.0 {
            targetRotation -= 360.0
        }

        // Calcul du centre pour le log de débogage
        let startAngleNonRotated = Double(winningIndex) * sectionAngle - 90.0
        let centerNonRotated = startAngleNonRotated + (sectionAngle / 2.0) // startAngle + 30

        Logger.debug("Calcul détaillé: index=\(winningIndex), startAngle=\(startAngleNonRotated)°, center=\(centerNonRotated)°, targetRotation=\(targetRotation)° (offset: \(correctionOffset)°)", category: "DiscountWheel")
        Logger.debug("Calcul rotation: Section \(winningIndex), centerNonRotated=\(centerNonRotated)°, targetRotation=\(targetRotation)°", category: "DiscountWheel")

        // Différencier le premier et le deuxième spin
        let fullRotations: Double
        let duration: Double
        let animationCurve: Animation

        if spinCount == 0 {
            // Premier spin : 5 tours en 3.5 secondes avec courbe ultra fluide
            fullRotations = 5.0
            duration = 3.5
            // Courbe d'animation ultra fluide avec décélération progressive
            animationCurve = .timingCurve(0.25, 0.1, 0.25, 1.0, duration: duration)
        } else {
            // Deuxième spin : 10 tours en 4.5 secondes, plus spectaculaire
            fullRotations = 10.0
            duration = 4.5
            // Courbe avec accélération puis décélération dramatique
            animationCurve = .timingCurve(0.15, 0.0, 0.2, 1.0, duration: duration)
        }

        // ✅ APPROCHE COMPLÈTEMENT DIFFÉRENTE : Calculer l'angle final absolu directement
        // On ignore l'angle actuel et on calcule directement l'angle final en fonction du nombre de tours
        let currentAngleNormalized = rotationAngle.truncatingRemainder(dividingBy: 360.0)

        // Calculer la rotation relative nécessaire pour atteindre targetRotation
        var relativeRotation = targetRotation - currentAngleNormalized

        // Si la rotation est négative, ajouter 360° pour tourner dans le sens positif
        if relativeRotation < 0 {
            relativeRotation += 360.0
        }

        // Ajouter les rotations complètes pour l'effet visuel
        relativeRotation += fullRotations * 360.0

        // ✅ ANGLE FINAL ABSOLU : Calculer directement sans dépendre de l'angle actuel
        // On calcule le nombre de tours complets actuels, puis on ajoute la rotation relative
        let currentFullTurns = floor(rotationAngle / 360.0)
        let finalAngle = currentFullTurns * 360.0 + relativeRotation + currentAngleNormalized

        // ✅ CORRECTION CRITIQUE : Forcer l'angle final normalisé à être EXACTEMENT targetRotation
        // On recalcule l'angle final en s'assurant que la partie normalisée est targetRotation
        let finalFullTurns = floor(finalAngle / 360.0)
        let exactFinalAngle = finalFullTurns * 360.0 + targetRotation

        Logger.debug("Rotation: current=\(currentAngleNormalized)°, target=\(targetRotation)°, final_exact=\(exactFinalAngle.truncatingRemainder(dividingBy: 360.0))°", category: "DiscountWheel")

        // Animation avec décélération
        withAnimation(animationCurve) {
            rotationAngle = exactFinalAngle
        }

        // ✅ CORRECTION CRITIQUE : Forcer l'angle exact après l'animation
        // SwiftUI peut ne pas respecter exactement l'angle final à cause de la courbe d'animation
        // On force l'angle exact juste après la fin de l'animation en calculant directement l'angle final
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            // Calculer directement l'angle final exact
            // On veut que l'angle normalisé soit EXACTEMENT targetRotation
            // On calcule le nombre de tours complets qu'on a fait, puis on ajoute targetRotation
            let currentFullTurns = floor(rotationAngle / 360.0)
            let exactFinalAngle = currentFullTurns * 360.0 + targetRotation

            // Forcer l'angle exact SANS animation pour garantir l'alignement parfait
            rotationAngle = exactFinalAngle

            Logger.debug("Angle final forcé immédiatement: \(exactFinalAngle.truncatingRemainder(dividingBy: 360.0))° (cible: \(targetRotation)°)", category: "DiscountWheel")
        }

        // ✅ TRIPLE VÉRIFICATION : Forcer à nouveau après un court délai pour être sûr
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            let currentFullTurns = floor(rotationAngle / 360.0)
            let exactFinalAngle = currentFullTurns * 360.0 + targetRotation
            rotationAngle = exactFinalAngle // Sans animation
            Logger.debug("Vérification 1: angle = \(exactFinalAngle.truncatingRemainder(dividingBy: 360.0))°", category: "DiscountWheel")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.2) {
            let currentFullTurns = floor(rotationAngle / 360.0)
            let exactFinalAngle = currentFullTurns * 360.0 + targetRotation
            rotationAngle = exactFinalAngle // Sans animation
            Logger.debug("Vérification 2: angle = \(exactFinalAngle.truncatingRemainder(dividingBy: 360.0))°", category: "DiscountWheel")
        }

        // Vibrations haptiques améliorées pour une meilleure expérience
        if spinCount == 0 {
            // Premier spin : vibrations progressives qui s'intensifient
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.impact(.light)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                HapticManager.shared.impact(.soft)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                HapticManager.shared.impact(.light)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                HapticManager.shared.impact(.medium)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                HapticManager.shared.impact(.light)
            }
        } else {
            // Deuxième spin : vibrations intenses et rythmées
            for i in 1...12 {
                let delay = Double(i) * 0.35
                let intensity: UIImpactFeedbackGenerator.FeedbackStyle = i <= 6 ? .medium : (i <= 9 ? .heavy : .light)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    HapticManager.shared.impact(intensity)
                }
            }
        }

        // Afficher le résultat après l'animation (avec un petit délai pour l'ajustement final)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.25) {
            // ✅ DERNIÈRE VÉRIFICATION : Forcer l'angle exact une dernière fois
            let currentFullTurns = floor(rotationAngle / 360.0)
            let exactAngle = currentFullTurns * 360.0 + targetRotation
            rotationAngle = exactAngle

            let finalCheck = rotationAngle.truncatingRemainder(dividingBy: 360.0)
            Logger.debug("Angle final vérifié: \(finalCheck)° (cible: \(targetRotation)°)", category: "DiscountWheel")

            // Effet de rebond à la fin du spin
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                wheelScale = 1.05
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    wheelScale = 1.0
                }
            }

            HapticManager.shared.notification(.success)
            isSpinning = false
            spinCount += 1

            // Si premier spin et résultat 0%, afficher le popup de retry
            if spinCount == 1 && result == 0 {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showRetryPopup = true
                }
            } else if result == -100 {
                // Si on obtient le cadeau, afficher la page d'offre limitée
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onDiscountSelected(result)
                    // La page d'offre limitée sera affichée depuis PaywallView
                    dismiss()
                }
            } else {
                // Sinon, afficher le résultat normal
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showResult = true
            }
            }
        }
    }

    // MARK: - Exit Notification

    private func scheduleExitNotificationIfNeeded() {
        // Éviter les doublons
        guard !hasScheduledExitNotification else { return }

        hasScheduledExitNotification = true

        Task {
            // Ne pas vérifier hasPurchased car on est sur la roulette, pas la page de paiement
            await PaywallExitNotificationService.shared.scheduleExitNotification(hasPurchased: false)
            Logger.debug("Notification de sortie programmée depuis la roulette", category: "Paywall")
        }
    }
}
