//
//  SleepInfoStepView.swift
//
//  Vue d'information sur l'importance du sommeil dans la récupération
//

import SwiftUI

struct SleepInfoStepView: View {
    var onComplete: (() -> Void)?

    @State private var showContent = false

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

                    VStack(spacing: 24) {

                        // Texte informatif
                        VStack(spacing: 16) {
                            SleepInfoRow(
                                icon: "brain.head.profile",
                                text: "Régénération cellulaire et réparation musculaire"
                            )

                            SleepInfoRow(
                                icon: "heart.fill",
                                text: "Optimisation de la récupération cardiovasculaire"
                            )

                            SleepInfoRow(
                                icon: "chart.line.uptrend.xyaxis",
                                text: "Amélioration des performances et de la concentration"
                            )

                            SleepInfoRow(
                                icon: "shield.fill",
                                text: "Renforcement du système immunitaire"
                            )
                        }
                        .padding(.horizontal, 40)
                        .opacity(showContent ? 1.0 : 0.0)
                    }

                    Spacer()

                    // Bouton continuer
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onComplete?()
                    }) {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1.0 : 0.0)
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Le sommeil joue", "le rôle le plus important", "dans ta récupération")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut (plus haut)
                        .opacity(showContent ? 1.0 : 0.0)
                    Spacer()
                }
            }
            .onAppear {
                // Animation d'apparition progressive
                withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Info Row Component
private struct SleepInfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.blue)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)

            Spacer()
        }
        .padding(.vertical, 8)
    }
}
