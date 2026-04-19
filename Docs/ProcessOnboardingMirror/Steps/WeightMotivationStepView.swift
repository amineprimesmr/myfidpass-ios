//
//  WeightMotivationStepView.swift
//  Process
//
//  Page de motivation après la sélection du poids idéal
//

import SwiftUI

struct WeightMotivationStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @ObservedObject var viewModel: OnboardingViewModel // ✅ Accès au ViewModel pour mettre à jour la validation

    let currentWeight: Double
    let idealWeight: Double
    let weightGoal: WeightGoal?

    var onComplete: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var animationProgress: CGFloat = 0.0
    @State private var displayedText: String = ""
    @StateObject private var hapticManager = HapticManager.shared
    @State private var typewriterTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler

    // Calculer le nombre de kg à perdre/prendre
    private var weightDifference: Double {
        abs(idealWeight - currentWeight)
    }

    private var actionText: String {
        guard let goal = weightGoal else { return "atteindre" }
        return goal == .lose ? "perdre" : "prendre"
    }

    // Texte complet à animer
    private var fullText: String {
        "\(actionText.capitalized) \(Int(weightDifference)) kg est un objectif réalisable. Ce n'est pas du tout difficile"
    }

    // Texte de statistique adapté selon l'objectif
    private var statisticsText: String {
        if let goal = weightGoal {
            switch goal {
            case .lose:
                return "91% des utilisateurs de Process maintiennent leur perte de poids même 6 mois plus tard."
            case .gain:
                return "91% des utilisateurs de Process maintiennent leur prise de poids même 6 mois plus tard."
            }
        }
        return "91% des utilisateurs de Process maintiennent leur objectif de poids même 6 mois plus tard."
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

                    // Message principal avec animation machine à écrire
                    VStack(spacing: 20) {
                        // Texte animé lettre par lettre avec couleur dynamique
                        TypewriterTextView(
                            text: fullText,
                            displayedText: displayedText,
                            fontSize: 28,
                            fontWeight: .semibold,
                            defaultColor: .white.opacity(0.9),
                            highlightColor: Color(red: 0.13, green: 0.98, blue: 0.47),
                            highlightStart: "Ce n'est pas"
                        )
                            .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                    }
                    .padding(.horizontal, 40)

                    // Statistique
                    Text(statisticsText)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                        .padding(.top, 20)
                    .opacity(animationProgress)

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
        }
        .onAppear {
            // ✅ Ne pas valider immédiatement - attendre que tous les textes soient apparus
            onValidationChanged?(false)
            // ✅ CRITIQUE: Réinitialiser le flag de validation dans le ViewModel
            viewModel.isWeightMotivationCompleted = false

            // Animation machine à écrire lettre par lettre
            startTypewriterAnimation()
        }
        .onDisappear {
            // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
            typewriterTask?.cancel()
            typewriterTask = nil
        }
    }

    // MARK: - Animation Machine à Écrire

    private func startTypewriterAnimation() {
        displayedText = ""
        let text = fullText
        let characters = Array(text)

        // ✅ Annuler la Task précédente si elle existe
        typewriterTask?.cancel()

        // Utiliser Task pour animation asynchrone plus fluide
        typewriterTask = Task {
            for (index, character) in characters.enumerated() {
                // ✅ Vérifier si la Task a été annulée
                if Task.isCancelled {
                    return
                }

                // Délai variable pour effet plus naturel
                let delay: TimeInterval
                if character == " " {
                    delay = 0.02 // Espaces plus rapides
                } else if character == "." || character == "!" {
                    delay = 0.08 // Pause plus longue pour ponctuation
                } else {
                    delay = 0.04 // Vitesse normale
                }

                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                // ✅ Vérifier à nouveau après le sleep
                if Task.isCancelled {
                    return
                }

                await MainActor.run {
                    // ✅ Vérifier une dernière fois avant de mettre à jour l'UI et déclencher les vibrations
                    guard !Task.isCancelled else { return }

                    displayedText += String(character)

                    // Vibration stylée
                    if character != " " {
                        // Vibration légère pour chaque lettre
                        hapticManager.impact(.soft)
                    }

                    // Vibration plus forte pour ponctuation
                    if character == "!" || character == "." {
                        hapticManager.impact(.light)
                    }
                }
            }

            // ✅ Vérifier avant la vibration finale
            guard !Task.isCancelled else { return }

            // Animation terminée - Vibration finale de succès
            await MainActor.run {
                // ✅ Vérifier une dernière fois avant la vibration finale
                guard !Task.isCancelled else { return }

                hapticManager.notification(.success)

                // Animation d'apparition pour les autres éléments
                withAnimation(.easeInOut(duration: 0.8)) {
                    animationProgress = 1.0
                }

                // ✅ Attendre que l'animation de la statistique soit complètement terminée avant de valider
                // L'animation dure 0.8s, donc on attend un peu plus pour être sûr que tout est visible
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    // ✅ CRITIQUE: Mettre à jour le ViewModel AVANT d'appeler onValidationChanged
                    viewModel.isWeightMotivationCompleted = true
                    onValidationChanged?(true) // ✅ Valider seulement maintenant pour afficher le bouton
                }
            }
        }
    }
}

// MARK: - Typewriter Text View Component

struct TypewriterTextView: View {
    let text: String
    let displayedText: String
    let fontSize: CGFloat
    let fontWeight: Font.Weight
    let defaultColor: Color
    let highlightColor: Color
    let highlightStart: String

    var body: some View {
        ZStack {
            // ✅ Texte complet invisible en arrière-plan pour fixer la mise en page
            // Cela empêche le texte de changer de ligne pendant l'animation
            Text(text)
                .font(.system(size: fontSize, weight: fontWeight))
                .foregroundColor(.clear)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)

            // ✅ Texte animé visible par-dessus
            Text(attributedDisplayText)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .frame(maxWidth: .infinity)
        }
    }

    // ✅ Computed property pour créer l'AttributedString avec couleurs dynamiques
    private var attributedDisplayText: AttributedString {
        var attributedString = AttributedString(displayedText)

        // Appliquer la couleur par défaut à tout le texte
        attributedString.foregroundColor = defaultColor
        attributedString.font = .system(size: fontSize, weight: fontWeight)

        // Appliquer la couleur highlight à la partie spécifiée
        // Utiliser range(of:) directement sur l'AttributedString pour trouver la partie à mettre en vert
        if let highlightRange = attributedString.range(of: highlightStart) {
            // Appliquer la couleur verte à partir de highlightStart jusqu'à la fin
            let endRange = highlightRange.lowerBound..<attributedString.endIndex
            attributedString[endRange].foregroundColor = highlightColor
        }

        return attributedString
    }
}
