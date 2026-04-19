//
//  AlarmConfigurationStepView.swift
//  Process
//
//  Page de configuration de la première alarme pour déterminer la fenêtre de récupération
//

import SwiftUI

struct AlarmConfigurationStepView: View {
    var onComplete: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?
    var onBack: (() -> Void)?

    @State private var showText: Bool = false
    @StateObject private var hapticManager = HapticManager.shared

    // Texte complet
    private var fullText: String {
        "Faisons le premier pas : découvre ton heure de coucher idéale selon ton réveil."
    }

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Contenu principal
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 40)

                    // Message principal avec animation d'apparition
                    VStack(spacing: 20) {
                        Text(fullText)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 20)
                            .opacity(showText ? 1.0 : 0.0)
                            .offset(y: showText ? 0 : 20)
                    }
                    .padding(.horizontal, 20)

                    Spacer()
                }
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("", "")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                    .opacity(0) // Titre invisible mais garde l'espace
                Spacer()
            }

            // ✅ BOUTON DEBUG : Passer la page (uniquement en mode développement)
            #if DEBUG
            VStack {
                HStack {
                    Spacer()

                    Button(action: {
                        hapticManager.impact(.medium)
                        Logger.debug("[DEBUG] Passage forcé de la page alarme", category: "Onboarding")
                        onComplete?()
                    }) {
                        Text("🔧 Passer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.orange.opacity(0.9))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()
            }
            #endif
        }
        .onAppear {
            // Valider automatiquement
            onValidationChanged?(true)

            // Animation d'apparition fluide du texte
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showText = true
            }

            // Vibration légère
            hapticManager.impact(.light)
        }
}
}
