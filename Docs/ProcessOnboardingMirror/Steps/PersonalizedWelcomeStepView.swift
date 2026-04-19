//
//  PersonalizedWelcomeStepView.swift
//
//  Page de bienvenue personnalisée après la saisie du prénom
//  Même UX et animations que WeightMotivationStepView
//

import SwiftUI

struct PersonalizedWelcomeStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @ObservedObject var viewModel: OnboardingViewModel // ✅ Accès au ViewModel pour mettre à jour la validation

    // ✅ CRITIQUE: Accepter le prénom en paramètre depuis le ViewModel
    let firstName: String

    var onComplete: (() -> Void)?
    var onValidationChanged: ((Bool) -> Void)?

    @State private var animationProgress: CGFloat = 0.0
    @State private var displayedText: String = "" // Texte affiché avec machine à écrire
    @State private var allTextsAppeared: Bool = false // ✅ État pour savoir si tous les textes sont apparus
    @StateObject private var hapticManager = HapticManager.shared
    @State private var typewriterTask: Task<Void, Never>? // ✅ Task pour pouvoir l'annuler
    @State private var fullTextToAnimate: String = "" // ✅ Texte complet capturé pour l'animation

    // ✅ CORRIGÉ: Récupérer le prénom depuis PLUSIEURS sources (ViewModel en priorité)
    private var userFirstName: String {
        // 1. Priorité au ViewModel (source de vérité pour l'onboarding)
        let viewModelFirstName = viewModel.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !viewModelFirstName.isEmpty && viewModelFirstName != "Utilisateur" {
            return viewModelFirstName
        }

        // 2. Paramètre passé
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "Utilisateur" {
            return trimmed
        }

        // 3. Fallback: essayer depuis le profil
        if let profileFirstName = profileService.currentProfile?.firstName,
           !profileFirstName.isEmpty,
           profileFirstName != "Utilisateur" {
            return profileFirstName
        }
        return "toi"
    }

    // ✅ CRITIQUE: Propriété calculée pour obtenir le texte complet avec le prénom
    // Utilisée pour garantir que le texte est toujours disponible, même au premier rendu
    private var completeTextWithName: String {
        "Ravi de te rencontrer \(userFirstName), découvrons ensemble comment optimiser ton potentiel"
    }

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement réduit entre titre et contenu pour remonter le texte
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing - 60)

                // Contenu principal
                VStack(spacing: 40) {
                    Spacer()
                        .frame(height: 20)

                    // Message principal avec animation machine à écrire
                    // ✅ Texte complet : "Ravi de te rencontrer [nom]. Découvrons comment optimiser ton potentiel"
                    TypewriterTextView(
                        text: fullTextToAnimate.isEmpty ? completeTextWithName : fullTextToAnimate,
                        displayedText: displayedText,
                        fontSize: 28,
                        fontWeight: .semibold,
                        defaultColor: .white.opacity(0.9),
                        highlightColor: .white.opacity(0.9),
                        highlightStart: ""
                    )
                    .multilineTextAlignment(.center)
                    .lineSpacing(8)
                    .padding(.horizontal, 50) // ✅ Plus de marge à gauche et à droite

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
            viewModel.isPersonalizedWelcomeCompleted = false

            // ✅ CORRIGÉ: Petit délai pour s'assurer que le ViewModel est à jour
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // ✅ CRITIQUE: Initialiser le texte complet avec le prénom ACTUEL du ViewModel
                let currentFirstName = userFirstName
                fullTextToAnimate = "Ravi de te rencontrer \(currentFirstName), découvrons ensemble comment optimiser ton potentiel"
                Logger.debug("[PersonalizedWelcome] Démarrage animation avec prénom: '\(currentFirstName)'", category: "Onboarding")

                // Animation machine à écrire lettre par lettre
                startTypewriterAnimation()
            }
        }
        .onDisappear {
            // ✅ Annuler la Task pour arrêter les vibrations quand on quitte la page
            typewriterTask?.cancel()
            typewriterTask = nil
        }
        .onChange(of: viewModel.firstName) { oldValue, newValue in
            // ✅ Si le prénom change après l'apparition de la vue, relancer l'animation
            let newTrimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newTrimmed.isEmpty && newTrimmed != oldValue && displayedText.isEmpty {
                fullTextToAnimate = "Ravi de te rencontrer \(newTrimmed), découvrons ensemble comment optimiser ton potentiel"
                startTypewriterAnimation()
            }
        }
    }

    // MARK: - Animation Machine à Écrire

    private func startTypewriterAnimation() {
        displayedText = ""
        // ✅ CRITIQUE: Utiliser le texte complet avec le prénom pour l'animation
        // fullTextToAnimate a été initialisé dans onAppear, mais on s'assure qu'il est à jour
        let textToAnimate = fullTextToAnimate.isEmpty ? completeTextWithName : fullTextToAnimate
        fullTextToAnimate = textToAnimate // ✅ Mettre à jour pour garantir la cohérence
        let characters = Array(textToAnimate)

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

            // ✅ Vérifier que l'animation est terminée
            guard !Task.isCancelled else { return }

            // ✅ Délai court après la fin de l'animation machine à écrire
            try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))

            // ✅ Vérifier à nouveau après le délai
            guard !Task.isCancelled else { return }

            // ✅ Valider après que tout le texte soit apparu
            await MainActor.run {
                // ✅ Vérifier une dernière fois
                guard !Task.isCancelled else { return }

                hapticManager.notification(.success)

                // ✅ Marquer que tous les textes sont apparus
                allTextsAppeared = true

                // ✅ CRITIQUE: Mettre à jour le ViewModel AVANT d'appeler onValidationChanged
                viewModel.isPersonalizedWelcomeCompleted = true
                onValidationChanged?(true) // ✅ Valider seulement maintenant pour afficher le bouton

                // Animation d'apparition pour les autres éléments
                withAnimation(.easeInOut(duration: 0.8)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}
