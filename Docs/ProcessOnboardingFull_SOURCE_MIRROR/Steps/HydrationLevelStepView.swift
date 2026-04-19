//
//  HydrationLevelStepView.swift
//  Process
//
//  Vue pour évaluer le niveau d'hydratation
//

import SwiftUI

struct HydrationLevelStepView: View {
    @Binding var selectedLevel: HydrationLevel?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var sliderValue: Double = 5.0
    @State private var isDragging = false
    @State private var glassesOfWater: Int = 5

    private let minValue: Double = 0.0
    private let maxValue: Double = 10.0

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
                    // Espace pour le titre en overlay (150pt)
                    Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 30) {
                            // Affichage du nombre de verres
                            VStack(spacing: 12) {
                                Text("\(glassesOfWater)")
                                    .font(.system(size: 72, weight: .bold))
                                    .foregroundColor(.blue)
                                    .contentTransition(.numericText(value: Double(glassesOfWater)))

                                Text(glassesOfWater == 1 ? "verre" : "verres")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))

                                // Estimation en litres (1 verre ≈ 0.25L)
                                HStack(spacing: 4) {
                                    Text("≈ \(String(format: "%.1f", Double(glassesOfWater) * 0.25))")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                    Text("L/jour")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .padding(.top, 4)
                            }
                            .padding(.vertical, 30)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 40)

                            // Slider
                            VStack(spacing: 16) {
                                Slider(value: $sliderValue, in: minValue...maxValue, step: 1.0)
                                    .accentColor(.blue)
                                    .padding(.horizontal, 30)
                                    .onChange(of: sliderValue) { _, newValue in
                                        if !isDragging {
                                            HapticManager.shared.selection()
                                        }
                                        updateGlasses(from: newValue)
                                    }
                                    .gesture(
                                        DragGesture(minimumDistance: 0)
                                            .onChanged { _ in
                                                if !isDragging {
                                                    isDragging = true
                                                    HapticManager.shared.impact(.light)
                                                }
                                            }
                                            .onEnded { _ in
                                                isDragging = false
                                                HapticManager.shared.impact(.light)
                                            }
                                    )

                                // Labels des extrémités
                                HStack {
                                    Text("0 verre")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))

                                    Spacer()

                                    Text("10 verres")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(.horizontal, 30)
                            }
                        }

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Combien de verres d'eau", "penses-tu boire chaque jour ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }
            }
        }
        .onAppear {
            // Initialiser avec 5 verres
            sliderValue = 5.0
            glassesOfWater = 5
            updateGlasses(from: sliderValue)
            onValidationChanged?(true)
        }
    }

    private func updateGlasses(from value: Double) {
        let glasses = Int(value)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            glassesOfWater = glasses
        }

        // Mapper vers HydrationLevel pour la compatibilité
        let level: HydrationLevel
        switch glasses {
        case 8...10:
            level = .excellent
        case 6..<8:
            level = .veryGood
        case 4..<6:
            level = .good
        case 2..<4:
            level = .average
        case 1:
            level = .poor
        default:
            level = .veryPoor
        }

        selectedLevel = level
        onValidationChanged?(true)
    }
}
