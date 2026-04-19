//
//  WeightStepView.swift
//
//  ✨ Page de saisie du poids avec clavier numérique natif et toggle KG/LBS
//  Structure IDENTIQUE à FirstNameInputStepView pour éviter les mouvements avec le clavier
//

import SwiftUI
import FirebaseAuth

struct WeightStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @StateObject private var hapticManager = HapticManager.shared

    @Binding var selectedWeight: Double  // en kg
    var onValidationChanged: ((Bool) -> Void)?
    var onContinue: (() -> Void)?

    @State private var unit: WeightUnit = .kg
    @State private var weightString: String = ""
    @FocusState private var isTextFieldFocused: Bool

    enum WeightUnit {
        case kg
        case lbs

        var displayName: String {
            switch self {
            case .kg: return "KG"
            case .lbs: return "LBS"
            }
        }
    }

    private var displayWeight: Double {
        if weightString.isEmpty {
            return 0
        }
        let value = Double(weightString) ?? 0
        return unit == .kg ? value : value * 0.453592
    }

    private var displayWeightString: String {
        if weightString.isEmpty {
            return "" // Pas de 0 par défaut, champ vide
        }
        return weightString
    }

    private var isValidWeight: Bool {
        !weightString.isEmpty && (Double(weightString) ?? 0) > 0
    }

    var body: some View {
        // ✅ ScrollView désactivée = empêche le scroll automatique quand le clavier apparaît
        ScrollView {
            ZStack {
                // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

                // ✅ Structure FIXE - Les éléments ne bougent pas avec le clavier
                VStack(spacing: 0) {
                    // Espace pour le titre en overlay
                    Spacer()
                        .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement entre titre et contenu (aligné avec HeightStepView)
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    // ✅ Toggle KG/LBS
                    unitToggle
                        .padding(.bottom, 60)

                    // ✅ Affichage du poids avec TextField invisible
                    ZStack {
                        // TextField transparent pour la saisie
                        TextField("", text: $weightString)
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.clear)
                            .multilineTextAlignment(.center)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(PlainTextFieldStyle())
                            .focused($isTextFieldFocused)
                            .onSubmit {
                                handleContinue()
                            }

                        // Affichage du poids (visible)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(displayWeightString)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
                                .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weightString)

                            Text(unit == .kg ? "kg" : "lbs")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 40)
                    .onTapGesture {
                        isTextFieldFocused = true
                    }

                    // ✅ Le bouton CONTINUER est maintenant géré globalement par OnboardingView
                    Spacer()
                }
                .frame(minHeight: UIScreen.main.bounds.height)

                // ✅ Titre en OVERLAY - Position ABSOLUE
                VStack {
                    OnboardingTitleView("Quel est ton poids ?")
                        .padding(.top, OnboardingConstants.titleTopPadding)
                    Spacer()
                }
            }
        }
        .scrollDisabled(true) // ✅ CRITIQUE: Désactiver le scroll = pas de mouvement avec le clavier
        .scrollDismissesKeyboard(.never) // ✅ Ne pas fermer le clavier en scrollant
        .onAppear {
            loadExistingWeight()
            // Activer le clavier automatiquement
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
        .onChange(of: weightString) { _, newValue in
            // Filtrer pour n'accepter que les chiffres et un point décimal
            let filtered = newValue.filter { $0.isNumber || $0 == "." }
            if filtered != newValue {
                weightString = filtered
                return
            }

            // Valider quand le poids change
            let weightValue = Double(newValue) ?? 0
            onValidationChanged?(!newValue.isEmpty && weightValue > 0)
            selectedWeight = displayWeight
        }
        .onChange(of: unit) { _, _ in
            convertWeight()
        }
    }

    // MARK: - Toggle KG/LBS

    private var unitToggle: some View {
        HStack(spacing: 0) {
            // KG
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    unit = .kg
                    convertWeight()
                }
                hapticManager.selection()
            }) {
                ZStack {
                    if unit == .kg {
                        activeToggleBackground
                    } else {
                        inactiveToggleBackground
                    }

                    Text("KG")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }

            // LBS
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    unit = .lbs
                    convertWeight()
                }
                hapticManager.selection()
            }) {
                ZStack {
                    if unit == .lbs {
                        activeToggleBackground
                    } else {
                        inactiveToggleBackground
                    }

                    Text("LBS")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 18/255, green: 18/255, blue: 20/255))
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 3)
        )
        .frame(width: UIScreen.main.bounds.width - 80)
        .frame(height: 56)
    }

    private var activeToggleBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 35/255, green: 35/255, blue: 37/255),
                            Color(red: 25/255, green: 25/255, blue: 27/255),
                            Color(red: 18/255, green: 18/255, blue: 20/255)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 28)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear
                        ],
                        center: .topLeading,
                        startRadius: 5,
                        endRadius: 30
                    )
                )

            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.white.opacity(0.05),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
        }
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1.5)
    }

    private var inactiveToggleBackground: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(Color(red: 18/255, green: 18/255, blue: 20/255))
    }

    // MARK: - Actions

    private func handleContinue() {
        let trimmed = weightString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, Double(trimmed) ?? 0 > 0 else { return }

        hapticManager.impact(.medium)

        // Fermer le clavier
        isTextFieldFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

        // Passer à l'étape suivante IMMÉDIATEMENT
        onContinue?()

        // Sauvegarder en arrière-plan
        selectedWeight = displayWeight
        Task.detached(priority: .background) {
            await saveWeight()
        }
    }

    private func loadExistingWeight() {
        if let profile = profileService.currentProfile, profile.weight > 0 {
            selectedWeight = profile.weight
            if unit == .kg {
                weightString = "\(Int(selectedWeight))"
            } else {
                weightString = "\(Int(selectedWeight * 2.20462))"
            }
        } else {
            weightString = ""
        }

        let isValid = !weightString.isEmpty && (Double(weightString) ?? 0) > 0
        Logger.debug("[WeightStepView] onAppear - Validation: \(isValid)", category: "Onboarding")
        onValidationChanged?(isValid)
    }

    private func convertWeight() {
        if selectedWeight > 0 {
            if unit == .kg {
                weightString = "\(Int(selectedWeight))"
            } else {
                let lbs = selectedWeight * 2.20462
                weightString = "\(Int(lbs))"
            }
        } else if !weightString.isEmpty {
            let currentValue = Double(weightString) ?? 0
            if unit == .kg {
                let kg = currentValue * 0.453592
                weightString = "\(Int(kg))"
                selectedWeight = kg
            } else {
                let lbs = currentValue * 2.20462
                weightString = "\(Int(lbs))"
                selectedWeight = currentValue
            }
        }
    }

    private func saveWeight() async {
        Logger.debug("[WeightStepView] Sauvegarde poids: \(selectedWeight) kg", category: "Onboarding")

        guard var profile = profileService.currentProfile else {
            if let userId = Auth.auth().currentUser?.uid {
                let tempProfile = UnifiedUserProfile(
                    userId: userId,
                    firstName: "Utilisateur",
                    birthDate: Date(),
                    gender: .male,
                    height: 0,
                    weight: selectedWeight
                )
                do {
                    try await profileService.saveProfile(tempProfile)
                    await profileService.loadProfile()
                    Logger.success("✅ [WeightStepView] Poids sauvegardé: \(selectedWeight) kg", category: "Onboarding")
                } catch {
                    Logger.error("Erreur sauvegarde poids: \(error)", category: "Onboarding")
                }
            }
            return
        }

        profile.weight = selectedWeight
        do {
            try await profileService.saveProfile(profile)
            await profileService.loadProfile()
            Logger.success("✅ [WeightStepView] Poids sauvegardé: \(selectedWeight) kg", category: "Onboarding")
        } catch {
            Logger.error("Erreur sauvegarde poids: \(error)", category: "Onboarding")
        }
    }
}
