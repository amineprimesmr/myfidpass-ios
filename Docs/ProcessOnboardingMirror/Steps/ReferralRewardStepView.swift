//
//  ReferralRewardStepView.swift
//  Process
//
//  Page de parrainage avec slider pour voir les gains potentiels
//

import SwiftUI

struct ReferralRewardStepView: View {
    @StateObject private var hapticManager = HapticManager.shared

    @State private var numberOfFriends: Double = 1
    @State private var isDragging: Bool = false

    var onComplete: () -> Void
    var onBack: (() -> Void)?

    private let minFriends: Double = 1
    private let maxFriends: Double = 100
    private let rewardPerFriend: Double = 13.0 // 13€ par ami parrainé

    private var totalReward: Double {
        numberOfFriends * rewardPerFriend
    }

    private var formattedReward: String {
        String(format: "%.0f", totalReward)
    }

    var body: some View {
            ZStack {
                // Fond noir
                Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Espace pour le titre
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement pour le contenu
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    // Texte principal
                    VStack(spacing: 20) {
                        Text("Offrez un essai gratuit de 3 jours à vos amis.")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 20)

                        Text("Et obtenez 13 euros.")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 20)

                        Text("Tu bénéficieras de 13 euros pour chaque ami que tu parraines.")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                    }
                    .padding(.top, 40)

                    Spacer()
                        .frame(height: 60)

                    // Slider avec affichage du gain
                    VStack(spacing: 24) {
                        // Affichage du gain total
                        VStack(spacing: 8) {
                            Text("Gains potentiels")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(formattedReward)")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                                    .contentTransition(.numericText())

                                Text("€")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            Text("\(Int(numberOfFriends)) ami\(Int(numberOfFriends) > 1 ? "s" : "") parrainé\(Int(numberOfFriends) > 1 ? "s" : "")")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(
                            RoundedRectangle(cornerRadius: 28)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)

                        // Slider Liquid Glass
                        HStack(alignment: .center, spacing: 32) {
                            // Bouton LiquidGlass pour afficher le nombre d'amis
                            Button(action: {}) {
                                HStack(alignment: .firstTextBaseline, spacing: 0) {
                                    Text("\(Int(numberOfFriends))")
                                        .font(.system(size: 22, weight: .bold, design: .default))
                                        .contentTransition(.numericText())
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5)

                                    Text(" amis")
                                        .font(.system(size: 14, weight: .bold, design: .default))
                                        .foregroundColor(.white.opacity(0.9))
                                        .shadow(color: .black.opacity(0.3), radius: 1, x: 0.5, y: 0.5)
                                }
                                .frame(width: 100, height: 44)
                            }
                            .frame(width: 100, height: 44)
                            .glassStyle()
                            .buttonBorderShape(.roundedRectangle(radius: 20))
                            .controlSize(.large)

                            // Slider horizontal - Style Liquid Glass
                            GeometryReader { sliderGeometry in
                                let sliderWidth = sliderGeometry.size.width
                                let sliderHeight: CGFloat = 44
                                let friendsProgress = (numberOfFriends - minFriends) / (maxFriends - minFriends)

                                ZStack(alignment: .leading) {
                                    // Bouton LiquidGlass comme fond
                                    Button(action: {}) {
                                        Text("")
                                            .frame(maxWidth: .infinity)
                                            .frame(height: sliderHeight)
                                    }
                                    .glassStyle()
                                    .buttonBorderShape(.roundedRectangle(radius: 16))
                                    .controlSize(.large)
                                    .allowsHitTesting(false)

                                    // Barre de progression (blanc)
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white)
                                        .frame(width: max(0, sliderWidth * friendsProgress), height: sliderHeight)
                                        .opacity(1.0)
                                        .zIndex(2)

                                    // Zone de gesture invisible sur tout le slider
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: sliderWidth, height: sliderHeight)
                                        .contentShape(Rectangle())
                                        .gesture(
                                            DragGesture(minimumDistance: 0)
                                                .onChanged { value in
                                                    if !isDragging {
                                                        isDragging = true
                                                        hapticManager.impact(.light)
                                                    }

                                                    let newProgress = max(0, min(1, value.location.x / sliderWidth))
                                                    let newFriends = minFriends + (newProgress * (maxFriends - minFriends))

                                                    let roundedFriends = round(newFriends)
                                                    if abs(roundedFriends - numberOfFriends) >= 1 {
                                                        withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                                            numberOfFriends = roundedFriends
                                                        }
                                                        hapticManager.selection()
                                                    }
                                                }
                                                .onEnded { _ in
                                                    isDragging = false
                                                    hapticManager.impact(.light)
                                                }
                                        )
                                }
                            }
                            .frame(height: 44)
                        }
                        .padding(.horizontal, 20)

                        // Espacement avant le bouton
                        Spacer()
                            .frame(height: 60)
                    }
                }
                    }
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)

            // Titre en overlay
            VStack {
                OnboardingTitleView("Offrez un essai gratuit", "de 3 jours à vos amis")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

            // ✅ BOUTON RETOUR TEMPORAIRE EN MODE DEBUG
            #if DEBUG
            if let onBack = onBack {
                VStack {
                    HStack {
                        Button(action: {
                            hapticManager.impact(.light)
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 34, height: 34)
                        }
                        .glassStyle()
                        .buttonBorderShape(.circle)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }
                .zIndex(1000)
            }
            #endif

            // Bouton continuer en bas - FIXE
                VStack {
                    Spacer()

                    Button(action: {
                    Logger.debug("Bouton CONTINUER cliqué sur ReferralRewardStepView", category: "Onboarding")
                        hapticManager.impact(.medium)

                    // Appeler onComplete immédiatement
                        onComplete()

                    Logger.debug("onComplete() appelé sur ReferralRewardStepView", category: "Onboarding")
                    }) {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                .controlSize(.large)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
            }
        }
        .onAppear {
            Logger.debug("ReferralRewardStepView apparaît", category: "Onboarding")
            numberOfFriends = 1
        }
}
}
