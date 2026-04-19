//
//  HeightStepView.swift
//  Process
//
//  Page de sélection de la taille : toggle CM/FT + TickPicker (graduations).
//

import SwiftUI
import FirebaseAuth

struct HeightStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @StateObject private var hapticManager = HapticManager.shared

    @Binding var selectedHeight: Double  // en cm
    var onValidationChanged: ((Bool) -> Void)?

    @State private var unit: HeightUnit = .cm
    /// Index 0 = 140 cm, index `tickIndexMax` = 220 cm (pas de 1 cm). Utilisé avec `TickPicker` (iOS 18+).
    @State private var tickSelection: Int = 36
    /// Repli iOS 17 : slider 0…1 mappé sur la plage cm.
    @State private var sliderValue: Double = 0.5
    @State private var lastHapticHeight: Int = -1

    private let minHeightCM: Double = 140
    private let maxHeightCM: Double = 220
    /// Nombre d’intervalles : 140…220 cm → 81 valeurs, indices 0…80.
    private let tickIndexMax: Int = 80

    enum HeightUnit {
        case cm
        case ft

        var displayName: String {
            switch self {
            case .cm: return "CM"
            case .ft: return "FT"
            }
        }
    }

    private var displayHeight: String {
        switch unit {
        case .cm:
            return "\(Int(selectedHeight))"
        case .ft:
            let totalInches = selectedHeight / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(totalInches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(inches)\""
        }
    }

    private var displayUnit: String {
        unit == .cm ? "cm" : ""
    }

    var body: some View {
        ZStack {
            // Fond noir géré par OnboardingView (comme page âge)

            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Contenu principal
                VStack(spacing: 0) {
                    // ✅ Toggle CM/FT (pill-shaped) - EXACTEMENT comme l'image avec effets neumorphism
                    HStack(spacing: 0) {
                    // CM - Section active avec effet "enfoncé/allumé"
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            unit = .cm
                        }
                        hapticManager.selection()
                    }) {
                        ZStack {
                            if unit == .cm {
                                // ✅ Section ACTIVE - Effet "allumé" avec dégradé radial
                                ZStack {
                                    // Fond de base avec dégradé linéaire (haut moins clair → bas très foncé)
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 35/255, green: 35/255, blue: 37/255), // ✅ Encore plus foncé en haut (#232325)
                                                    Color(red: 25/255, green: 25/255, blue: 27/255), // ✅ Encore plus foncé au milieu (#19191B)
                                                    Color(red: 18/255, green: 18/255, blue: 20/255)  // ✅ Très très foncé en bas (#121214)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )

                                    // ✅ Dégradé radial supplémentaire venant du haut-gauche (effet lumière)
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.white.opacity(0.08), // Lueur très subtile en haut-gauche
                                                    Color.clear
                                                ],
                                                center: .topLeading,
                                                startRadius: 5,
                                                endRadius: 30
                                            )
                                        )

                                    // ✅ Fine ligne/ombre interne le long du bord supérieur (effet "enfoncé")
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2), // Ligne claire en haut
                                                    Color.white.opacity(0.05), // Ligne moyenne au milieu
                                                    Color.clear // Transparent en bas
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.5
                                        )
                                }
                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1.5) // Ombre interne subtile
                            } else {
                                // Section inactive - fond encore plus foncé
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color(red: 18/255, green: 18/255, blue: 20/255)) // ✅ Encore plus noir (#121214)
                            }

                            Text("CM")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }

                    // FT - Section inactive
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            unit = .ft
                        }
                        hapticManager.selection()
                    }) {
                        ZStack {
                            if unit == .ft {
                                // ✅ Section ACTIVE - Effet "allumé" avec dégradé radial
                                ZStack {
                                    // Fond de base avec dégradé linéaire (haut moins clair → bas très foncé)
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: 35/255, green: 35/255, blue: 37/255), // ✅ Encore plus foncé en haut (#232325)
                                                    Color(red: 25/255, green: 25/255, blue: 27/255), // ✅ Encore plus foncé au milieu (#19191B)
                                                    Color(red: 18/255, green: 18/255, blue: 20/255)  // ✅ Très très foncé en bas (#121214)
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )

                                    // ✅ Dégradé radial supplémentaire venant du haut-gauche (effet lumière)
                                    RoundedRectangle(cornerRadius: 28)
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    Color.white.opacity(0.08), // Lueur très subtile en haut-gauche
                                                    Color.clear
                                                ],
                                                center: .topLeading,
                                                startRadius: 5,
                                                endRadius: 30
                                            )
                                        )

                                    // ✅ Fine ligne/ombre interne le long du bord supérieur (effet "enfoncé")
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2), // Ligne claire en haut
                                                    Color.white.opacity(0.05), // Ligne moyenne au milieu
                                                    Color.clear // Transparent en bas
                                                ],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            ),
                                            lineWidth: 1.5
                                        )
                                }
                                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1.5) // Ombre interne subtile
                            } else {
                                // Section inactive - fond encore plus foncé
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color(red: 18/255, green: 18/255, blue: 20/255)) // ✅ Encore plus noir (#121214)
                            }

                            Text("FT")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(
                    // ✅ Fond global de la pilule (encore plus noir)
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color(red: 18/255, green: 18/255, blue: 20/255)) // ✅ Encore plus noir (#121214)
                        .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3) // Ombre externe pour effet de profondeur
                )
                .frame(width: UIScreen.main.bounds.width - 80) // ✅ Beaucoup plus large comme l'image
                .frame(height: 56) // ✅ Plus haut aussi
                .padding(.bottom, 60)

                // ✅ Grand nombre avec effet blur/glow (comme l'image)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayHeight)
                        .font(.system(size: 56, weight: .bold, design: .default)) // ✅ Plus petit (de 72 à 56)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0) // ✅ Glow effect plus visible
                        .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0) // ✅ Glow externe
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: selectedHeight)

                    Text(displayUnit)
                        .font(.system(size: 20, weight: .medium)) // ✅ Plus petit aussi (de 24 à 20)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 32)

                Group {
                    if #available(iOS 18.0, *) {
                        ZStack {
                            TickPicker(
                                count: tickIndexMax,
                                config: TickConfig(
                                    tickWidth: 2,
                                    tickHeight: 32,
                                    tickHPadding: 3,
                                    inActiveHeightProgress: 0.55,
                                    interactionHeight: 72,
                                    activeTint: .white,
                                    inActiveTint: .white.opacity(0.35),
                                    alignment: .bottom,
                                    animation: .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
                                ),
                                selection: $tickSelection
                            )
                            .onChange(of: tickSelection) { _, newValue in
                                updateHeightFromTickIndex(newValue)
                            }

                            Rectangle()
                                .fill(Color.white.opacity(0.65))
                                .frame(width: 2, height: 44)
                                .allowsHitTesting(false)
                        }
                    } else {
                        Slider(value: $sliderValue, in: 0...1)
                            .tint(.white)
                            .onChange(of: sliderValue) { _, _ in
                                updateHeightFromSliderLegacy()
                            }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 56)

                Spacer()
                }
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Quelle est ta taille ?")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }
        }
        .onAppear {
            // Charger les valeurs existantes
            if let profile = profileService.currentProfile, profile.height > 0 {
                selectedHeight = profile.height
            } else {
                selectedHeight = 176.0 // Valeur par défaut
            }

            let cmRounded = Int(selectedHeight.rounded())
            let clampedCm = min(max(cmRounded, Int(minHeightCM)), Int(maxHeightCM))
            selectedHeight = Double(clampedCm)
            tickSelection = clampedCm - Int(minHeightCM)
            sliderValue = (selectedHeight - minHeightCM) / (maxHeightCM - minHeightCM)
            lastHapticHeight = clampedCm

            // ✅ Valider immédiatement car on a toujours une taille (même par défaut 176cm)
            // La taille par défaut est 176cm, donc toujours valide
            Logger.debug("[HeightStepView] onAppear - Validation immédiate avec taille: \(selectedHeight)", category: "Onboarding")

            // ✅ Forcer la validation avec un petit délai pour s'assurer que le ViewModel est prêt
            DispatchQueue.main.async {
                self.onValidationChanged?(self.selectedHeight > 0)
            }
        }
        .onChange(of: selectedHeight) { _, newValue in
            Logger.debug("[HeightStepView] selectedHeight changed: \(newValue)", category: "Onboarding")
            onValidationChanged?(newValue > 0)
            let cmRounded = Int(newValue.rounded())
            let clampedCm = min(max(cmRounded, Int(minHeightCM)), Int(maxHeightCM))
            let newIndex = clampedCm - Int(minHeightCM)
            if #available(iOS 18.0, *) {
                if newIndex != tickSelection {
                    tickSelection = newIndex
                }
            } else {
                let s = (newValue - minHeightCM) / (maxHeightCM - minHeightCM)
                if abs(sliderValue - s) > 0.001 {
                    sliderValue = min(max(s, 0), 1)
                }
            }
        }
        .onChange(of: unit) { _, _ in
            let cmRounded = Int(selectedHeight.rounded())
            let clampedCm = min(max(cmRounded, Int(minHeightCM)), Int(maxHeightCM))
            tickSelection = clampedCm - Int(minHeightCM)
        }
    }

    private func updateHeightFromSliderLegacy() {
        let rawCM = minHeightCM + sliderValue * (maxHeightCM - minHeightCM)
        let newHeightCM = Double(Int(rawCM.rounded()))
        selectedHeight = min(max(newHeightCM, minHeightCM), maxHeightCM)

        let currentHeightCm = Int(selectedHeight)
        if currentHeightCm != lastHapticHeight {
            lastHapticHeight = currentHeightCm
            hapticManager.selection()
        }

        Logger.debug("[HeightStepView] updateHeightFromSliderLegacy - taille: \(selectedHeight)", category: "Onboarding")

        Task {
            await saveHeight()
        }
    }

    private func updateHeightFromTickIndex(_ index: Int) {
        let safe = min(max(index, 0), tickIndexMax)
        let newHeightCM = Double(Int(minHeightCM) + safe)
        if Int(selectedHeight.rounded()) == Int(newHeightCM) {
            return
        }
        selectedHeight = newHeightCM

        let currentHeightCm = Int(newHeightCM)
        if currentHeightCm != lastHapticHeight {
            lastHapticHeight = currentHeightCm
            hapticManager.selection()
        }

        Logger.debug("[HeightStepView] updateHeightFromTickIndex - taille: \(newHeightCM)", category: "Onboarding")

        Task {
            await saveHeight()
        }
    }

    private func saveHeight() async {
        guard var profile = profileService.currentProfile else {
            if let userId = Auth.auth().currentUser?.uid {
                let tempProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: "Utilisateur",
                    birthDate: Date(),
                    gender: .male,
                    height: selectedHeight,
                    weight: 0
                )
                do {
                    try await profileService.saveProfile(tempProfile)
                } catch {
                    Logger.error("Erreur sauvegarde taille: \(error)", category: "Onboarding")
                }
            }
            return
        }

        profile.height = selectedHeight
        do {
            try await profileService.saveProfile(profile)
        } catch {
            Logger.error("Erreur sauvegarde taille: \(error)", category: "Onboarding")
        }
    }
}
