//
//  IdealWeightStepView.swift
//  Process
//
//  ✨ Saisie du poids idéal avec clavier numérique - UX identique à WeightStepView
//  Avec système de recommandation intelligent basé sur IMC, taille, âge et genre
//

import SwiftUI
import FirebaseFirestore

struct IdealWeightStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @EnvironmentObject var healthManager: HealthManager
    @Binding var idealWeight: Double

    // ✅ Paramètres pour la validation
    let currentWeight: Double
    let height: Double
    let weightGoal: WeightGoal?
    let firstName: String

    var onValidationChanged: ((Bool) -> Void)?

    // ✅ États locaux
    @State private var weightString: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var bodyCompositionFromScan: BodyComposition?

    // ✅ Données du profil
    private var profile: UnifiedUserProfile? {
        profileService.currentProfile
    }

    private var age: Int {
        profile?.age ?? 25
    }

    private var gender: Gender {
        profile?.gender ?? .male
    }

    // ✅ Composition corporelle estimée
    private var currentBodyComposition: BodyComposition {
        if let scanComposition = bodyCompositionFromScan {
            return scanComposition
        }
        return BodyCompositionCalculator.calculate(
            height: height,
            weight: currentWeight,
            age: age,
            gender: gender
        )
    }

    // ✅ Poids recommandé personnalisé
    private var recommendedWeight: Double {
        PersonalizedIdealWeightCalculator.calculatePersonalizedIdealWeight(
            currentWeight: currentWeight,
            height: height,
            age: age,
            gender: gender,
            weightGoal: weightGoal,
            bodyFatPercentage: currentBodyComposition.bodyFatPercentage,
            leanBodyMass: currentBodyComposition.leanMass,
            bodyComposition: currentBodyComposition
        )
    }

    private var displayWeightString: String {
        if weightString.isEmpty {
            return ""
        }
        return weightString
    }

    private var isValidWeight: Bool {
        guard !weightString.isEmpty else { return false }
        guard let weight = Double(weightString), weight > 0 else { return false }

        // Validation selon l'objectif
        if let goal = weightGoal {
            switch goal {
            case .lose:
                return weight < currentWeight && weight >= 35
            case .gain:
                return weight > currentWeight && weight <= 200
            }
        }
        return weight > 0
    }

    init(
        idealWeight: Binding<Double> = .constant(70.0),
        currentWeight: Double = 70.0,
        height: Double = 175.0,
        weightGoal: WeightGoal? = nil,
        firstName: String = "",
        onValidationChanged: ((Bool) -> Void)? = nil
    ) {
        self._idealWeight = idealWeight
        self.currentWeight = currentWeight
        self.height = height
        self.weightGoal = weightGoal
        self.firstName = firstName
        self.onValidationChanged = onValidationChanged
    }

    var body: some View {
        ScrollView {
        ZStack {
            VStack(spacing: 0) {
                    // Espace pour le titre
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // ✅ Sous-titre avec poids recommandé
                    Text("Poids recommandé : \(Int(recommendedWeight)) kg")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 8)

                    // Espacement
                Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

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

                        // Affichage du poids (visible)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(displayWeightString.isEmpty ? "" : displayWeightString)
                                .font(.system(size: 56, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .white.opacity(0.4), radius: 12, x: 0, y: 0)
                                .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: weightString)

                            if !displayWeightString.isEmpty {
                            Text("kg")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 40)
                    .onTapGesture {
                        isTextFieldFocused = true
                    }

                                Spacer()
                }
                .frame(minHeight: UIScreen.main.bounds.height)

                // ✅ Titre en OVERLAY
                VStack {
                    OnboardingTitleView("Quel est ton", "poids idéal ?")
                        .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
                }
            }
        }
        .scrollDisabled(true)
        .scrollDismissesKeyboard(.never)
        .onAppear {
            loadExistingIdealWeight()

            // Charger body scan si disponible
            Task {
                await loadBodyScanDataIfAvailable()
            }

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

            // Mettre à jour idealWeight
            if let weight = Double(newValue), weight > 0 {
                idealWeight = weight

                // Sauvegarder
                Task {
                    await saveIdealWeight(weight)
                }
            }

            // Valider
            onValidationChanged?(isValidWeight)
        }
    }

    // MARK: - Helpers

    private func loadExistingIdealWeight() {
        if let profile = profileService.currentProfile, let ideal = profile.idealWeight, ideal > 0 {
            idealWeight = ideal
            weightString = "\(Int(ideal))"
        } else {
            weightString = ""
        }

        onValidationChanged?(isValidWeight)
    }

    private func saveIdealWeight(_ weight: Double) async {
        guard var profile = profileService.currentProfile else { return }
        profile.idealWeight = weight
        do {
            try await profileService.saveProfile(profile)
            Logger.debug("[IdealWeightStepView] Poids idéal sauvegardé: \(weight) kg", category: "Onboarding")
        } catch {
            Logger.error("Erreur sauvegarde poids idéal: \(error)", category: "Onboarding")
        }
    }

    private func loadBodyScanDataIfAvailable() async {
        guard let userId = profile?.userId else { return }

        do {
            let db = Firestore.firestore()
            let scansRef = db.collection("users")
                .document(userId)
                .collection("bodyScans")
                .order(by: "scanDate", descending: true)
                .limit(to: 1)

            let snapshot = try await scansRef.getDocuments()

            if let document = snapshot.documents.first {
                let scanData = try document.data(as: BodyScanData.self)
                await MainActor.run {
                    if let composition = scanData.composition {
                        self.bodyCompositionFromScan = composition
                    }
                }
            }
        } catch {
            Logger.debug("Aucun body scan trouvé: \(error.localizedDescription)", category: "IdealWeight")
        }
}
}
