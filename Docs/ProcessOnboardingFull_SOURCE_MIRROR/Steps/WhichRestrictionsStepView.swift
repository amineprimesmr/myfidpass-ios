//
//  WhichRestrictionsStepView.swift
//
//  Vue pour sélectionner les restrictions alimentaires (détails)
//

import SwiftUI

struct WhichRestrictionsStepView: View {
    @Binding var selectedRestrictions: Set<DietaryRestriction>
    @Binding var otherRestriction: String
    var onValidationChanged: ((Bool) -> Void)?

    @State private var showOtherInput = false

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
                        VStack(spacing: 16) {
                            // Afficher seulement les options actuelles, exclure les anciennes options
                            ForEach(DietaryRestriction.allCases.filter { restriction in
                                restriction != .none &&
                                restriction != .halal &&
                                restriction != .kosher &&
                                restriction != .nutAllergy &&
                                restriction != .eggAllergy &&
                                restriction != .soyAllergy
                            }) { restriction in
                                Button(action: {
                                    HapticManager.shared.selection()

                                    if selectedRestrictions.contains(restriction) {
                                        selectedRestrictions.remove(restriction)
                                    } else {
                                        selectedRestrictions.insert(restriction)
                                    }

                                    // Afficher l'input pour "Autre"
                                    if restriction == .other {
                                        showOtherInput = true
                                    } else {
                                        showOtherInput = false
                                    }

                                    onValidationChanged?(!selectedRestrictions.isEmpty)
                                }) {
                                    HStack(spacing: 12) {
                                        Text(restriction.rawValue)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Spacer()

                                        if selectedRestrictions.contains(restriction) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.white.opacity(0.3))
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .glassStyle()
                                .buttonBorderShape(.roundedRectangle(radius: 16))
                                .opacity(selectedRestrictions.contains(restriction) ? 1.0 : 0.6)
                            }
                        }
                        .padding(.horizontal, 40)

                        // Input pour "Autre"
                        if showOtherInput {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Précise ta restriction")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)

                                TextField("Ex: Allergie aux arachides, intolérance au fructose...", text: $otherRestriction)
                                    .textFieldStyle(.plain)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(16)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 40)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("Quelles", "restrictions as-tu ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut
                    Spacer()
                }

                // ✅ Fond noir progressif en bas pour belle UX (dégradé fluide)
                VStack {
                    Spacer()

                    // Gradient progressif pour effet de transition fluide
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.8)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: showOtherInput)
        .onAppear {
            onValidationChanged?(!selectedRestrictions.isEmpty)
        }
}
}
