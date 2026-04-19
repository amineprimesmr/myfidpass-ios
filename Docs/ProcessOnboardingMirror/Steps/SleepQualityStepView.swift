//
//  SleepQualityStepView.swift
//  Process
//
//  Vue pour évaluer la qualité perçue du sommeil
//

import SwiftUI

struct SleepQualityStepView: View {
    @Binding var selectedQuality: OnboardingSleepQuality?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var sliderValue: Double = 2.5
    @State private var isDragging = false

    private let minValue: Double = 0.0
    private let maxValue: Double = 5.0

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond Sleep
                Image("Sleep")
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
                            // Affichage de la qualité sélectionnée
                            if let quality = selectedQuality {
                                VStack(spacing: 12) {
                                    Text(quality.emoji)
                                        .font(.system(size: 60))

                                    Text(quality.rawValue)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)

                                    Text(quality.description)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 40)
                                }
                                .padding(.vertical, 20)
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
                                .transition(.opacity.combined(with: .scale))
                            }

                            // Slider
                            VStack(spacing: 16) {
                                Slider(value: $sliderValue, in: minValue...maxValue, step: 0.5)
                                    .accentColor(.blue)
                                    .padding(.horizontal, 30)
                                    .onChange(of: sliderValue) { _, newValue in
                                        if !isDragging {
                                            HapticManager.shared.selection()
                                        }
                                        updateQuality(from: newValue)
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
                                    Text("Très mauvais")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))

                                    Spacer()

                                    Text("Excellent")
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
                    OnboardingTitleView("Comment ressens-tu", "ton sommeil actuellement ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }
            }
        }
        .onAppear {
            sliderValue = 2.5
            updateQuality(from: sliderValue)
            onValidationChanged?(true)
        }
    }

    private func updateQuality(from value: Double) {
        let quality: OnboardingSleepQuality

        switch value {
        case 4.5...5.0:
            quality = .excellent
        case 3.5..<4.5:
            quality = .veryGood
        case 2.5..<3.5:
            quality = .good
        case 1.5..<2.5:
            quality = .average
        case 0.5..<1.5:
            quality = .poor
        default:
            quality = .veryPoor
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedQuality = quality
        }

        onValidationChanged?(true)
    }
}
