//
//  NutritionQualityStepView.swift
//  Process
//
//  Vue pour évaluer la qualité de l'alimentation actuelle
//

import SwiftUI

struct NutritionQualityStepView: View {
    @Binding var selectedQuality: NutritionQuality?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var sliderValue: Double = 1.0  // Position par défaut : Améliorable (index 1)
    @State private var isDragging = false
    @State private var showImages = false
    @State private var imageScale: [CGFloat] = [0.0, 0.0, 0.0]
    @State private var imageRotation: [Double] = [0.0, 0.0, 0.0]
    @State private var imageOpacity: [Double] = [0.0, 0.0, 0.0]
    @State private var imagePulse: [CGFloat] = [1.0, 1.0, 1.0]
    @State private var currentQualityIndex: Int = 1  // Pour suivre la qualité actuelle

    // ✅ 3 positions fixes : 0, 1, 2
    private let minValue: Double = 0.0
    private let maxValue: Double = 2.0

    // ✅ Les 3 qualités nutritionnelles
    private let nutritionQualities: [NutritionQuality] = [
        .poor,      // 0 : Mauvaise
        .average,   // 1 : Améliorable
        .excellent  // 2 : Excellente
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond nutri
                Image("nutri")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                // ✅ Overlay très réduit pour permettre à la lueur d'être visible
                Color.black.opacity(0.1)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Espace pour le titre en overlay + espacement uniforme
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    VStack(spacing: 0) {
                        // Espacement uniforme entre titre et contenu
                        Spacer()
                            .frame(height: OnboardingConstants.titleToContentSpacing)

                        VStack(spacing: 30) {
                            // ✅ Affichage simple de la qualité sélectionnée avec description
                            if let quality = selectedQuality {
                                VStack(spacing: 12) {
                                    Text(quality.comment)
                                        .font(.system(size: 38, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: gradientColors(for: quality),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .id(quality.comment) // Force la réanimation lors du changement

                                    Text(quality.description)
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundColor(.white.opacity(0.6))
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(6)
                                        .padding(.horizontal, 40)
                                        .id(quality.description) // Force la réanimation lors du changement
                                }
                                .padding(.vertical, 20)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .top))
                                ))
                            }

                            // ✅ Slider épais horizontal avec 3 positions (style comme vitesse de perte de poids)
                            GeometryReader { geometry in
                                let sliderWidth = geometry.size.width - 80
                                let sliderHeight: CGFloat = 50
                                let qualityProgress = sliderValue / maxValue

                            VStack(spacing: 0) {
                                    // Slider épais horizontal
                                    ZStack(alignment: .leading) {
                                        // Barre de fond (gris foncé)
                                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                                            .fill(Color(red: 0.08, green: 0.08, blue: 0.08))
                                            .frame(width: sliderWidth, height: sliderHeight)

                                        // Barre de progression avec dégradé dynamique selon la qualité
                                        if let quality = selectedQuality {
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: gradientColors(for: quality),
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: sliderWidth * qualityProgress, height: sliderHeight)
                                                .animation(.easeInOut(duration: 0.4), value: selectedQuality)
                                        } else {
                                            RoundedRectangle(cornerRadius: 25, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            Color(red: 0.13, green: 0.98, blue: 0.47),
                                                            Color(red: 0.65, green: 1.0, blue: 0.95)
                                                        ],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: sliderWidth * qualityProgress, height: sliderHeight)
                                        }

                                        // Zones cliquables pour les 3 positions
                                        HStack(spacing: 0) {
                                            // Zone gauche (Mauvaise)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: sliderWidth / 3)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 0
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 0.0
                                                    }
                                                    updateQualitySmoothly(to: 0)
                                                    HapticManager.shared.selection()
                                                }

                                            // Zone centre (Améliorable)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: sliderWidth / 3)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 1
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 1.0
                                                    }
                                                    updateQualitySmoothly(to: 1)
                                                    HapticManager.shared.selection()
                                                }

                                            // Zone droite (Excellente)
                                            Rectangle()
                                                .fill(Color.clear)
                                                .frame(width: sliderWidth / 3)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    currentQualityIndex = 2
                                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                                        sliderValue = 2.0
                                                    }
                                                    updateQualitySmoothly(to: 2)
                                                    HapticManager.shared.selection()
                                                }
                                        }
                                        .frame(width: sliderWidth, height: sliderHeight)
                                    }
                                    .frame(width: sliderWidth, height: sliderHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                                    .padding(.horizontal, 40)
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { value in
                                                if !isDragging {
                                                    isDragging = true
                                                    HapticManager.shared.impact(.light)
                                                }

                                                let location = value.location.x - 40
                                                let normalizedProgress = max(0, min(1, location / sliderWidth))

                                                // Snap direct aux 3 positions (0, 1, 2) - plus réactif
                                                let snappedIndex: Int
                                                if normalizedProgress < 0.33 {
                                                    snappedIndex = 0
                                                } else if normalizedProgress < 0.67 {
                                                    snappedIndex = 1
                                                } else {
                                                    snappedIndex = 2
                                                }

                                                // Mise à jour IMMÉDIATE et ultra fluide pendant le slide
                                                if currentQualityIndex != snappedIndex {
                                                    currentQualityIndex = snappedIndex

                                                    // Animation ultra fluide et rapide pour le slider - snap direct
                                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                                        sliderValue = Double(snappedIndex)
                                                    }

                                                    // Mise à jour INSTANTANÉE de la qualité avec animation ultra fluide
                                                    // Pas de délai - tout change en temps réel pendant le slide
                                                    updateQualitySmoothly(to: snappedIndex)
                                                    HapticManager.shared.selection()
                                                }
                                            }
                                            .onEnded { _ in
                                                isDragging = false
                                                HapticManager.shared.impact(.light)
                                            }
                                    )
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 60)
                        }
                        .padding(.horizontal, 0)

                        Spacer()
                    }
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Comment décrirais-tu", "ton alimentation ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                    Spacer()
                }

                // ✅ Images animées dispersées dans tout l'écran selon la qualité
                if let quality = selectedQuality {
                    GeometryReader { geo in
                        ZStack {
                            // ========== MAUVAISE (Poor) ==========
                            // Pizza2 - plus proche du texte, haut gauche
                            if quality == .poor {
                                Image("pizza2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 65, height: 65)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: .orange.opacity(0.6), radius: 20, x: 3, y: 8)
                                    .position(
                                        x: geo.size.width * 0.25,
                                        y: geo.size.height * 0.38
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Coca - plus proche du texte, droite
                            if quality == .poor {
                                Image("coca")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 58, height: 58)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: .red.opacity(0.6), radius: 20, x: -3, y: 8)
                                    .position(
                                        x: geo.size.width * 0.82,
                                        y: geo.size.height * 0.40
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Nutella - plus proche du slider, bas gauche
                            if quality == .poor {
                                Image("nutella")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 62, height: 62)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: .brown.opacity(0.6), radius: 20, x: 4, y: -5)
                                    .position(
                                        x: geo.size.width * 0.28,
                                        y: geo.size.height * 0.68
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // ========== AMÉLIORABLE (Average) ==========
                            // Pate2 - plus proche du texte, haut droite
                            if quality == .average {
                                Image("pate2")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 63, height: 63)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: .yellow.opacity(0.6), radius: 20, x: -2, y: 6)
                                    .position(
                                        x: geo.size.width * 0.72,
                                        y: geo.size.height * 0.32
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Croissant - plus proche du texte, gauche
                            if quality == .average {
                                Image("croissant")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: .orange.opacity(0.6), radius: 20, x: 2, y: 7)
                                    .position(
                                        x: geo.size.width * 0.18,
                                        y: geo.size.height * 0.42
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Pouletcuisse - plus proche du slider, bas droite
                            if quality == .average {
                                Image("pouletcuisse")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: .brown.opacity(0.6), radius: 20, x: -4, y: -6)
                                    .position(
                                        x: geo.size.width * 0.70,
                                        y: geo.size.height * 0.67
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // ========== EXCELLENTE (Excellent) ==========
                            // Viandeplato - plus proche du texte, gauche
                            if quality == .excellent {
                                Image("viandeplato")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 66, height: 66)
                                    .scaleEffect(imageScale[0] * imagePulse[0])
                                    .rotationEffect(.degrees(imageRotation[0]))
                                    .opacity(imageOpacity[0] * 0.75)
                                    .shadow(color: .green.opacity(0.6), radius: 20, x: 3, y: 5)
                                    .position(
                                        x: geo.size.width * 0.20,
                                        y: geo.size.height * 0.32
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Brocoli - plus proche du slider, droite
                            if quality == .excellent {
                                Image("brocoli")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 61, height: 61)
                                    .scaleEffect(imageScale[1] * imagePulse[1])
                                    .rotationEffect(.degrees(imageRotation[1]))
                                    .opacity(imageOpacity[1] * 0.75)
                                    .shadow(color: .green.opacity(0.6), radius: 20, x: -3, y: -4)
                                    .position(
                                        x: geo.size.width * 0.74,
                                        y: geo.size.height * 0.70
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }

                            // Banane - plus proche du texte, droite
                            if quality == .excellent {
                                Image("banane")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 59, height: 59)
                                    .scaleEffect(imageScale[2] * imagePulse[2])
                                    .rotationEffect(.degrees(imageRotation[2]))
                                    .opacity(imageOpacity[2] * 0.75)
                                    .shadow(color: .yellow.opacity(0.6), radius: 20, x: 2, y: 9)
                                    .position(
                                        x: geo.size.width * 0.68,
                                        y: geo.size.height * 0.36
                                    )
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
        }
        .onAppear {
            // Initialiser avec la position "Améliorable" (index 1)
            sliderValue = 1.0
            currentQualityIndex = 1
            updateQualitySmoothly(to: 1)
            onValidationChanged?(true)

            // Démarrer l'animation après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showImages = true
            }
        }
    }

    // ✅ Couleurs du dégradé selon la qualité
    private func gradientColors(for quality: NutritionQuality) -> [Color] {
        switch quality {
        case .poor:
            // Dégradé rouge-orange
            return [
                Color(red: 1.0, green: 0.3, blue: 0.2),      // Rouge pétant
                Color(red: 1.0, green: 0.5, blue: 0.0),      // Orange vif
                Color(red: 1.0, green: 0.65, blue: 0.2)     // Orange clair
            ]
        case .average:
            // Dégradé vert pétant clair (comme le slider)
            return [
                Color(red: 0.13, green: 0.98, blue: 0.47),   // Vert Process
                Color(red: 0.65, green: 1.0, blue: 0.95),    // Turquoise clair
                Color(red: 0.4, green: 1.0, blue: 0.7)       // Vert clair
            ]
        case .excellent:
            // Dégradé violet pétant presque rose (comme la carte nutrition)
            return [
                Color(red: 0.7, green: 0.4, blue: 0.94),     // Violet pétant
                Color(red: 0.94, green: 0.7, blue: 1.0),    // Rose-violet
                Color(red: 0.85, green: 0.5, blue: 0.98)     // Violet-rose
            ]
        default:
            return [.white]
        }
    }

    // ✅ Mapper la valeur du slider (0-2) aux 3 qualités nutritionnelles
    private func updateQuality(from value: Double) {
        let index = Int(value.clamped(to: 0...2))
        updateQualitySmoothly(to: index)
    }

    // ✅ Mise à jour ultra fluide de la qualité avec animations synchronisées
    private func updateQualitySmoothly(to index: Int) {
        let quality = nutritionQualities[index]

        // Animation simultanée et ultra fluide pour le texte - changement immédiat
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            selectedQuality = quality
        }

        // Faire disparaître les images actuelles très rapidement
        withAnimation(.easeOut(duration: 0.15)) {
            imageScale = [0.0, 0.0, 0.0]
            imageOpacity = [0.0, 0.0, 0.0]
            imagePulse = [1.0, 1.0, 1.0]
            imageRotation = [0.0, 0.0, 0.0]
        }

        // Animer les nouvelles images IMMÉDIATEMENT - pas de délai
            animateImages(for: quality)

        onValidationChanged?(true)
    }

    // ✅ Animation ultra fluide des images selon la qualité - INSTANTANÉE
    private func animateImages(for quality: NutritionQuality) {
        let baseDelay: Double = 0.05  // Délai minimal pour fluidité

        switch quality {
        case .poor:
            // Toutes les 3 images apparaissent pour "Mauvaise" avec animation en cascade ultra fluide
            // Pizza2 - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }

            // Pulsation continue pour pizza2
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.08
            }

            // Coca - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }

            // Pulsation continue pour coca
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.08
            }

            // Nutella - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }

            // Pulsation continue pour nutella
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.08
            }

        case .average:
            // 3 images pour "Améliorable" : pate2, croissant, pouletcuisse
            // Pate2 - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }

            // Pulsation douce pour pate2
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.05
            }

            // Croissant - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }

            // Pulsation douce pour croissant
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.05
            }

            // Pouletcuisse - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }

            // Pulsation douce pour pouletcuisse
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.05
            }

        case .excellent:
            // 3 images pour "Excellente" : viandeplato, brocoli, banane
            // Viandeplato - apparaît immédiatement
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay)) {
                imageScale[0] = 1.0
                imageOpacity[0] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay)) {
                imageRotation[0] = 360.0
            }

            // Pulsation douce pour viandeplato
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.3)) {
                imagePulse[0] = 1.05
            }

            // Brocoli - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.08)) {
                imageScale[1] = 1.0
                imageOpacity[1] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.08)) {
                imageRotation[1] = -360.0
            }

            // Pulsation douce pour brocoli
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.38)) {
                imagePulse[1] = 1.05
            }

            // Banane - apparaît presque immédiatement après
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8).delay(baseDelay + 0.15)) {
                imageScale[2] = 1.0
                imageOpacity[2] = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(baseDelay + 0.15)) {
                imageRotation[2] = 360.0
            }

            // Pulsation douce pour banane
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(baseDelay + 0.45)) {
                imagePulse[2] = 1.05
            }

        default:
            break
        }
    }
}

// ✅ Extension pour clamp
extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
