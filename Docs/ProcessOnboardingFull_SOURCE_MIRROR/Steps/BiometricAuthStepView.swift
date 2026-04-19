//
//  BiometricAuthStepView.swift
//  Process
//
//  Page d'authentification biométrique (empreinte digitale)
//

import SwiftUI
import LocalAuthentication
import FirebaseAuth

struct BiometricAuthStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?
    let onAuthenticationComplete: ((Bool) -> Void)?

    @State private var isAuthenticating = false
    @State private var isAuthenticated = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var progress: Double = 0.0
    @State private var authenticationContext: LAContext?
    @State private var userFirstName = "Utilisateur"
    @State private var isPressed = false
    @State private var pressStartTime: Date?
    @State private var pressDuration: TimeInterval = 0.0
    @State private var showFingerprint = true
    private let requiredPressDuration: TimeInterval = 10.0 // 10 secondes d'appui requis

    // ✅ États pour animation simple - TOUS LES TEXTES RESTENT VISIBLES
    @State private var commitmentOpacities: [Double] = [0.0, 0.0, 0.0, 0.0]

    private let commitments = [
        "Suivre mes données chaque jour",
        "Adapter mon effort à ma récupération",
        "Construire ma régularité",
        "M'investir pleinement dans Process"
    ]

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil, onAuthenticationComplete: ((Bool) -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
        self.onAuthenticationComplete = onAuthenticationComplete
    }

    var body: some View {
        ZStack {
            // Fond noir simple
            Color.black
                .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                // Espacement en haut
                    Spacer()
                    .frame(height: 100)

                    // Titre avec prénom (aligné à gauche)
                    Text("\(userFirstName), établissons un contrat")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                    .padding(.bottom, 20)

                    // Texte d'introduction
                    Text("À partir de ce jour, je m'engage à :")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)

                // TOUS LES TEXTES D'ENGAGEMENT qui apparaissent progressivement et restent visibles
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<commitments.count, id: \.self) { index in
                        animatedCommitmentText(text: commitments[index], index: index)
                    }
                }
                        .padding(.horizontal, 40)
                .padding(.bottom, 40)

                Spacer()

                // Zone d'empreinte digitale avec animation EN BAS
                        fingerprintZone
                            .padding(.horizontal, 40)
                    .padding(.bottom, 50)
            }
        }
        .alert("Erreur", isPresented: $showError) {
            Button("OK") {
                // Permettre de réessayer
                isAuthenticating = false
                progress = 0.0
            }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadUserFirstName()
            // Ne plus skip automatiquement - l'utilisateur doit voir la page du contrat
        }
        .onChange(of: profileService.currentProfile?.firstName) { newValue in
            if let newFirstName = newValue, !newFirstName.isEmpty {
                userFirstName = newFirstName
            }
        }
    }

    // MARK: - Animated Commitment Text

    @ViewBuilder
    private func animatedCommitmentText(text: String, index: Int) -> some View {
        HStack(spacing: 16) {
            // Checkmark qui apparaît avec le texte - Animation simple
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                .opacity(commitmentOpacities[index])
                .transition(.opacity)

            // Texte légèrement plus petit avec animation simple
            Text(text)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .opacity(commitmentOpacities[index])
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // ✅ Fonction pour mettre à jour les animations - Animation simple comme "Cette nuit" -> "Besoin du sommeil"
    private func updateCommitmentAnimations(progress: Double) {
        for index in 0..<commitments.count {
            // Chaque engagement apparaît dans une tranche de 25% de progression et RESTE VISIBLE
            let startProgress = Double(index) * 0.25

            if progress >= startProgress && commitmentOpacities[index] < 1.0 {
                // Animation simple avec transition opacity (comme contentTransition)
                withAnimation(.easeInOut(duration: 0.3)) {
                    commitmentOpacities[index] = 1.0
                }
            }
        }
    }

    // MARK: - Fingerprint Zone

    private var fingerprintZone: some View {
        // Zone d'appui avec image fingerprint et cercle de progression
        ZStack {
            // Image fingerprint - ENCORE PLUS GROSSE
            if let fingerprintImage = UIImage(named: "fingerprint") {
                Image(uiImage: fingerprintImage)
                    .resizable()
                    .renderingMode(.original)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 380, height: 380)
                    .scaleEffect(isPressed ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            } else {
                // Fallback si l'image n'existe pas
                Image(systemName: "touchid")
                    .font(.system(size: 200, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(isPressed ? 1.05 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            }

            // Cercle de progression - Lueur subtile autour de l'image (ENCORE PLUS PETIT)
            ZStack {
                // Lueur de progression - Cercle beaucoup plus petit avec ombre douce
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.6),
                                Color(red: 0.20, green: 0.85, blue: 0.60).opacity(0.4),
                                Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 210, height: 210)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.5), radius: 8, x: 0, y: 0)
                    .blur(radius: 1)
                    .animation(.easeInOut(duration: 0.1), value: progress)
            }
            }
        .frame(width: 380, height: 380)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            startPress()
                        }
                    }
                    .onEnded { _ in
                        endPress()
                    }
            )
    }

    // MARK: - Actions

    private func loadUserFirstName() {
        if let user = Auth.auth().currentUser {
            // 1. Priorité 1: Récupérer depuis le profil utilisateur (le plus fiable)
            if let profile = profileService.currentProfile,
               !profile.firstName.isEmpty {
                userFirstName = profile.firstName
            }
            // 2. Priorité 2: Récupérer depuis displayName de Firebase Auth
            else if let displayName = user.displayName, !displayName.isEmpty {
                userFirstName = displayName
            }
            // 3. Fallback: Utiliser un nom générique
            else {
                userFirstName = "Utilisateur"
            }
        }
    }

    private func startPress() {
        guard !isPressed && !isAuthenticated else { return }

        isPressed = true
        pressStartTime = Date()
        progress = 0.0
        isAuthenticating = true

        // Vibration initiale forte
        hapticManager.impact(.heavy)

        // Animer la progression du cercle avec vibrations ULTRA CRESCENDO
        Task {
            let startTime = Date()
            var lastVibrationProgress: Double = -0.05
            var vibrationIntensity: Double = 0.0

            while isPressed && !isAuthenticated {
                let elapsed = Date().timeIntervalSince(startTime)
                let newProgress = min(elapsed / requiredPressDuration, 1.0)

                await MainActor.run {
                    progress = newProgress

                    // ✅ ANIMATION ULTRA FLUIDE DES ENGAGEMENTS - Apparition progressive
                    updateCommitmentAnimations(progress: newProgress)

                    // ✅ DÉTECTION AUTOMATIQUE : Quand on atteint 100%, compléter automatiquement
                    if newProgress >= 1.0 && !isAuthenticated {
                        completeAuthentication()
                        return
                    }

                    // VIBRATIONS CONTINUES EN CRESCENDO - VRAIMENT CONTINUES
                    // Vibrations à CHAQUE frame avec intensité qui augmente progressivement
                    // Calcul du nombre de vibrations basé sur la progression (crescendo continu)

                    // Calculer le nombre de vibrations basé sur la progression (de 1 à 8 vibrations)
                    let vibrationCount = Int(1 + (newProgress * 7)) // 1 vibration à 0%, 8 vibrations à 100%

                    // Calculer l'intervalle entre les vibrations (diminue progressivement)
                    let vibrationInterval = max(0.002, 0.015 - (newProgress * 0.013)) // De 15ms à 2ms

                    // Déclencher les vibrations en rafale
                    for i in 0..<vibrationCount {
                        let delay = Double(i) * vibrationInterval
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            // Intensité qui augmente avec la progression
                            if newProgress < 0.3 {
                                self.hapticManager.impact(.medium)
                            } else {
                                self.hapticManager.impact(.heavy)
                            }
                        }
                    }

                    // Vibrations spéciales aux milestones (encore plus fortes)
                    if newProgress > 0.25 && newProgress < 0.26 {
                        for i in 0..<3 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                                self.hapticManager.impact(.heavy)
                            }
                        }
                    } else if newProgress > 0.5 && newProgress < 0.51 {
                        for i in 0..<5 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.04) {
                                self.hapticManager.impact(.heavy)
                            }
                        }
                    } else if newProgress > 0.75 && newProgress < 0.76 {
                        for i in 0..<7 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.03) {
                                self.hapticManager.impact(.heavy)
                            }
                        }
                    } else if newProgress > 0.9 && newProgress < 0.91 {
                        // Finale : explosion de vibrations
                        for i in 0..<10 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.02) {
                                self.hapticManager.impact(.heavy)
                            }
                        }
                    }
                }

                try? await Task.sleep(nanoseconds: 16_666_666) // ~60 FPS
            }
        }
    }

    private func endPress() {
        guard isPressed else { return }

        isPressed = false
        pressStartTime = nil

        // Si l'authentification n'est pas complète, réinitialiser
        if !isAuthenticated {
            isAuthenticating = false
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                progress = 0.0
            }

            // Réinitialiser les animations des engagements
            withAnimation(.easeInOut(duration: 0.2)) {
                commitmentOpacities = [0.0, 0.0, 0.0, 0.0]
            }
        }
    }

    private func completeAuthentication() {
        guard !isAuthenticated else { return }

        // Arrêter l'appui
        isPressed = false
        isAuthenticated = true
        progress = 1.0

        // Vibration de succès finale
        hapticManager.notification(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.hapticManager.notification(.success)
        }

        // Notifier que l'authentification est complète et continuer directement
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.onComplete()
        }
}
}
