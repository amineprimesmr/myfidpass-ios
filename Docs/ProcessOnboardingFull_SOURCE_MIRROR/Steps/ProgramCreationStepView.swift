//
//  ProgramCreationStepView.swift
//  Process
//
//  Page de création du programme avec animations
//

import SwiftUI

struct ProgramCreationStepView: View {
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?
    let onValidationChanged: ((Bool) -> Void)?

    @State private var allAnimationsComplete = false

    // États pour les animations
    @State private var overallProgress: Double = 0.0
    @State private var displayedPercentage: Int = 0
    @State private var showCreationText = false
    @State private var showObjectives = false
    @State private var currentObjectiveIndex = 0
    @State private var objectiveProgresses: [Double] = [0.0, 0.0, 0.0]
    @State private var showPopup = false
    @State private var popupQuestion = ""
    @State private var popupObjectiveIndex = -1
    @State private var selectedAnswer: Bool?
    @State private var isAnimationPaused = false
    @State private var popupOffset: CGFloat = 200

    // ✅ NOUVEAU: État pour le défilement des images scienceaprouve
    @State private var currentImageIndex: Int = 0
    @State private var imageTimer: Timer?

    // Images scienceapprouve (avec deux 'p')
    private let scienceImages = ["scienceapprouve", "scienceapprouve2", "scienceapprouve3"]

    // Objectifs
    private let objectives = ["Analyse des habitudes", "Generation du plan de 13 semaines", "Objectifs personnalisés quotidien"]

    // Questions pour chaque objectif à 50%
    private let questions = [
        "Es-tu prêt à terminer ce que tu commences?",
        "Sais-tu ce qui impact réellement ta récupération ?",
        "As-tu déjà téléchargé une application de tracking personnalisé ?"
    ]

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil, onValidationChanged: ((Bool) -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
        self.onValidationChanged = onValidationChanged
    }

    var body: some View {
        ZStack {
            // Fond noir
            Color.black
                .ignoresSafeArea(.all)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Espacement en haut
                    Spacer()
                        .frame(height: 120)

                    // Pourcentage qui défile (même style que les scores des cartes)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("\(displayedPercentage)")
                            .font(.system(size: 72, weight: .bold, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95),
                                        Color.gray.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: displayedPercentage)

                        Text("%")
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.white,
                                        Color.white.opacity(0.95),
                                        Color.gray.opacity(0.6)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    }
                    .padding(.bottom, 40)

                    // Section "Creation du programme"
                    if showCreationText {
                        creationSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.bottom, 5)
                    }

                    // Section témoignage utilisateur (image sous Creation du programme)
                    if showCreationText {
                        testimonialSection
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            .padding(.top, 5)
                            .padding(.bottom, 20)
                    }

                    // Section objectifs
                    if showObjectives {
                        objectivesSection
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .padding(.top, 10)
                            .padding(.bottom, 40)
                    }

                    Spacer()
                        .frame(height: 100)
                }
            }

            // Popup avec question (style roulette)
            if showPopup {
                popupView
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .onAppear {
                        // ✅ Animation d'apparition améliorée
                        popupOffset = 100
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.75, blendDuration: 0.1)) {
                            popupOffset = 0
                        }
                    }
            }
        }
        .onAppear {
            // Désactiver le bouton au début
            onValidationChanged?(false)
            startAnimations()
            startImageCarousel()
        }
        .onDisappear {
            // Arrêter le timer quand la vue disparaît
            imageTimer?.invalidate()
            imageTimer = nil
        }
    }

    // MARK: - Testimonial Section (remplacée par image scienceapprouve avec défilement automatique)

    private var testimonialSection: some View {
        Group {
            Image(scienceImages[currentImageIndex])
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: LayoutConstants.isIPad ? 300 : 200) // ✅ Plus grande sur iPad mais limitée
                .id(currentImageIndex) // Force le re-render lors du changement
        }
        .frame(height: LayoutConstants.isIPad ? 300 : 200) // ✅ Plus de hauteur sur iPad
        .adaptiveHorizontalPadding() // ✅ Padding adaptatif pour iPad
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.5), value: currentImageIndex)
    }

    // MARK: - Creation Section

    private var creationSection: some View {
        VStack(spacing: 20) {
            Text("Creation du programme")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
        }
    }

    // MARK: - Objectives Section

    private var objectivesSection: some View {
        VStack(alignment: .leading, spacing: 30) {
            ForEach(0..<objectives.count, id: \.self) { index in
                if index <= currentObjectiveIndex {
                    objectiveRow(index: index)
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
        }
        .padding(.horizontal, 40)
    }

    private func objectiveRow(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Nom de l'objectif
            Text(objectives[index])
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            // Barre de progression (même taille que "Creation du programme")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 10)

                    // Progression
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.7, green: 0.55, blue: 0.85),
                                    Color(red: 0.5, green: 0.3, blue: 0.7)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * objectiveProgresses[index], height: 10)
                        .animation(.easeInOut(duration: 0.2), value: objectiveProgresses[index])
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - Popup View (Style RetryPopupView de la roulette - EXACTEMENT PAREIL)

    private var popupView: some View {
        VStack {
            Spacer()
            Spacer() // ✅ Double Spacer pour descendre la popup

            Button(action: {}) {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        // Texte d'instruction
                        Text("Pour pouvoir continuer, précise")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))

                        // Question
                        Text(popupQuestion)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }

                    // Boutons Oui/Non
                    HStack(spacing: 16) {
                        // Bouton Non
                        Button(action: {
                            hapticManager.impact(.medium)
                            selectedAnswer = false
                            handlePopupAnswer(false)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Non")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.98),
                                    Color(red: 0.92, green: 0.95, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)

                        // Bouton Oui
                        Button(action: {
                            hapticManager.impact(.medium)
                            selectedAnswer = true
                            handlePopupAnswer(true)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Oui")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                        }
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.92, blue: 0.98),
                                    Color(red: 0.92, green: 0.95, blue: 0.98)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 40)
                .frame(maxWidth: .infinity)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 30))
            .controlSize(.large)
            .padding(.horizontal, 20)
            .offset(y: popupOffset)
            .scaleEffect(popupOffset == 0 ? 1.0 : 0.9) // ✅ Animation scale
            .opacity(popupOffset == 0 ? 1.0 : 0.0) // ✅ Animation opacité
        }
        .padding(.bottom, 40) // ✅ Popup plus basse
    }

    // MARK: - Image Carousel

    private func startImageCarousel() {
        // Démarrer le timer pour changer l'image toutes les 5 secondes
        imageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                currentImageIndex = (currentImageIndex + 1) % scienceImages.count
            }
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Afficher immédiatement le texte de création et les objectifs
        Task {
            await MainActor.run {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showCreationText = true
                    showObjectives = true
                }
            }

            // Le pourcentage sera synchronisé avec la progression des objectifs
            // Plus besoin d'une tâche séparée pour le pourcentage
            let overallProgressTask = Task {
                // Cette tâche est vide, le pourcentage sera mis à jour dans animateObjectiveProgress
            }

            // Afficher et animer les objectifs un par un EN PARALLÈLE
            let objectivesTask = Task {
                // Petit délai avant de commencer les objectifs
                try? await Task.sleep(nanoseconds: 800_000_000)

                for index in 0..<objectives.count {
                    await MainActor.run {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentObjectiveIndex = index
                        }
                    }

                    // Animer la barre de progression de l'objectif
                    await animateObjectiveProgress(index: index)
                }
            }

            // Attendre que tout soit terminé
            await overallProgressTask.value
            await objectivesTask.value

            // Activer le bouton quand toutes les animations sont terminées
            await MainActor.run {
                allAnimationsComplete = true
                onValidationChanged?(true)
            }
        }
    }

    private func animateObjectiveProgress(index: Int) async {
        // Animer jusqu'à 50% progressivement (PLUS LENT)
        var currentProgress: Double = 0.0
        while currentProgress < 0.5 {
            // Pause si le popup est affiché
            while isAnimationPaused {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            try? await Task.sleep(nanoseconds: 40_000_000) // ~40ms par étape (plus lent)
            currentProgress += 0.005 // Plus petit incrément pour plus de fluidité
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    objectiveProgresses[index] = min(currentProgress, 0.5)
                    // Mettre à jour le pourcentage en fonction de la progression de cet objectif
                    // Chaque objectif représente 100/3% du total (33.333...)
                    let percentagePerObjective = 100.0 / Double(objectives.count)
                    let basePercentage = Double(index) * percentagePerObjective
                    let progressPercentage = currentProgress * percentagePerObjective
                    let totalPercentage = Int(basePercentage + progressPercentage)
                    displayedPercentage = min(totalPercentage, 100)
                }
            }
        }

        // Afficher le popup à 50% et PAUSER l'animation
        await MainActor.run {
            // PAUSER toutes les animations
            isAnimationPaused = true

            popupQuestion = questions[index]
            popupObjectiveIndex = index
            // Réinitialiser l'offset avant d'afficher
            popupOffset = 200
            showPopup = true
            // L'animation sera déclenchée par onAppear de la popup
        }

        // Attendre que l'utilisateur réponde (géré par handlePopupAnswer qui reprendra l'animation)
        // On attend que isAnimationPaused redevienne false
        while isAnimationPaused {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // Continuer jusqu'à 100% (PLUS LENT)
        while currentProgress < 1.0 {
            // Pause si le popup est affiché
            while isAnimationPaused {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            try? await Task.sleep(nanoseconds: 40_000_000) // ~40ms par étape (plus lent)
            currentProgress += 0.005 // Plus petit incrément pour plus de fluidité
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    objectiveProgresses[index] = min(currentProgress, 1.0)
                    // Mettre à jour le pourcentage en fonction de la progression de cet objectif
                    // Chaque objectif représente 100/3% du total (33.333...)
                    let percentagePerObjective = 100.0 / Double(objectives.count)
                    let basePercentage = Double(index) * percentagePerObjective
                    let progressPercentage = currentProgress * percentagePerObjective
                    let totalPercentage = Int(basePercentage + progressPercentage)
                    // S'assurer que le dernier objectif complété force le total à 100%
                    if index == objectives.count - 1 && currentProgress >= 1.0 {
                        displayedPercentage = 100
                    } else {
                    displayedPercentage = min(totalPercentage, 100)
                    }
                }
            }
        }
    }

    private func handlePopupAnswer(_ answer: Bool) {
        // Fermer le popup avec animation depuis le bas
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            popupOffset = 200
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showPopup = false
            popupOffset = 200 // Réinitialiser pour la prochaine fois
        }

        // REPRENDRE l'animation
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                // Reprendre toutes les animations
                isAnimationPaused = false

                // Continuer la progression jusqu'à 100%
                withAnimation(.easeInOut(duration: 1.0)) {
                    objectiveProgresses[popupObjectiveIndex] = 1.0
                    // Mettre à jour le pourcentage quand l'objectif est complété
                    let percentagePerObjective = 100.0 / Double(objectives.count)
                    let basePercentage = Double(popupObjectiveIndex) * percentagePerObjective
                    let totalPercentage = Int(basePercentage + percentagePerObjective)
                    // S'assurer que le dernier objectif complété force le total à 100%
                    if popupObjectiveIndex == objectives.count - 1 {
                        displayedPercentage = 100
                    } else {
                    displayedPercentage = min(totalPercentage, 100)
                    }
                }
}
}
}
}
