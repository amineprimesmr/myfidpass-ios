//
//  OnboardingDataModel.swift
//  Process
//
//  Modèle centralisé pour toutes les données de l'onboarding
//

import Foundation
import Combine

/// Modèle centralisé pour gérer toutes les données de l'onboarding
/// Remplace tous les @State dispersés dans OnboardingView
@MainActor
class OnboardingDataModel: ObservableObject {
    static let shared = OnboardingDataModel()

    // MARK: - Données personnelles
    @Published var selectedGender: Gender?
    @Published var selectedAge: Int = 25
    @Published var firstName: String = ""

    // MARK: - Objectifs et préférences
    @Published var optimizationGoals: Set<String> = []
    @Published var trainingFrequency: String?
    @Published var selectedSports: Set<String> = []
    @Published var selectedMainGoal: MainGoal?
    @Published var selectedExperienceLevel: ExperienceLevel?
    @Published var yearsOfExperience: Int = 0
    @Published var selectedWeightGoal: WeightGoal?

    // MARK: - Contraintes d'entraînement
    @Published var sessionsPerWeek: Int = 3
    @Published var sessionDuration: Int = 60
    @Published var selectedTrainingLocation: TrainingLocation = .mixed
    @Published var selectedEquipment: Set<PlanEquipment> = []

    // MARK: - Informations personnelles complètes
    @Published var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @Published var height: Double = 170.0 // en cm
    @Published var weight: Double = 70.0 // en kg
    @Published var idealWeight: Double = 70.0 // en kg
    @Published var bodyScanData: BodyScanData? // ✨ Données du scan corporel

    // MARK: - Sommeil
    @Published var sleepProfile: SleepProfile = SleepProfile()
    @Published var isSleepQualitySelected = false
    @Published var isFatigueFrequencySelected = false
    @Published var isFatiguePeaksSelected = false

    // MARK: - États de validation
    @Published var isGenderSelected = false
    @Published var isAgeSelected = false
    @Published var isFirstNameEntered = false
    @Published var isOptimizationGoalsSelected = false
    @Published var isTrainingFrequencySelected = false
    @Published var isSportsSelected = false
    @Published var isMainGoalSelected = false
    @Published var isExperienceLevelSelected = false
    @Published var isTrainingConstraintsSelected = false
    @Published var isPersonalInfoCompleted = false
    @Published var isWeightGoalSelected = false

    // MARK: - Progression
    @Published var currentStep: Int = 0
    @Published var lastCompletedStep: Int = -1

    private let userDefaults = UserDefaults.standard
    private let onboardingProgressKey = "onboarding_current_step"
    private let onboardingDataKey = "onboarding_data_cache"
    private let selectedSportsKey = "onboarding_selected_sports"

    private init() {
        loadProgress()
        loadSelectedSports()
    }

    /// Charge les sports sélectionnés depuis UserDefaults (persistance pour ne pas les perdre au redémarrage)
    private func loadSelectedSports() {
        if let saved = userDefaults.array(forKey: selectedSportsKey) as? [String], !saved.isEmpty {
            selectedSports = Set(saved)
            Logger.debug("[OnboardingDataModel] Sports chargés depuis persistance: \(saved)", category: "Onboarding")
        }
    }

    /// Persiste les sports sélectionnés pour qu'ils survivent au redémarrage et soient pris en compte par syncProfileWithViewModel
    func persistSelectedSports() {
        let array = Array(selectedSports)
        userDefaults.set(array, forKey: selectedSportsKey)
        Logger.debug("[OnboardingDataModel] Sports persistés: \(array)", category: "Onboarding")
    }

    // MARK: - Sauvegarde de progression

    /// Sauvegarde l'étape actuelle pour reprise après crash
    func saveProgress() {
        userDefaults.set(currentStep, forKey: onboardingProgressKey)
        userDefaults.set(lastCompletedStep, forKey: "onboarding_last_completed_step")
        Logger.debug("Progression sauvegardée: étape \(currentStep)", category: "Onboarding")
    }

    /// Charge la progression sauvegardée
    func loadProgress() {
        currentStep = userDefaults.integer(forKey: onboardingProgressKey)
        lastCompletedStep = userDefaults.integer(forKey: "onboarding_last_completed_step")
        Logger.debug("Progression chargée: étape \(currentStep)", category: "Onboarding")
    }

    /// Réinitialise la progression (après completion)
    func resetProgress() {
        currentStep = 0
        lastCompletedStep = -1
        selectedSports = []
        userDefaults.removeObject(forKey: onboardingProgressKey)
        userDefaults.removeObject(forKey: "onboarding_last_completed_step")
        userDefaults.removeObject(forKey: onboardingDataKey)
        userDefaults.removeObject(forKey: selectedSportsKey)
        Logger.debug("Progression réinitialisée", category: "Onboarding")
    }

    // MARK: - Validation croisée

    /// Valide la cohérence des données entre les étapes
    func validateConsistency() -> [String] {
        var warnings: [String] = []

        // Vérifier cohérence fréquence vs sessions
        if let frequency = trainingFrequency {
            if frequency == "0-2" && sessionsPerWeek > 2 {
                warnings.append("Tu as sélectionné 0-2 entraînements/semaine mais \(sessionsPerWeek) sessions")
            } else if frequency == "3-5" && (sessionsPerWeek < 3 || sessionsPerWeek > 5) {
                warnings.append("Tu as sélectionné 3-5 entraînements/semaine mais \(sessionsPerWeek) sessions")
            } else if frequency == "6+" && sessionsPerWeek < 6 {
                warnings.append("Tu as sélectionné 6+ entraînements/semaine mais \(sessionsPerWeek) sessions")
            }
        }

        // Vérifier cohérence expérience
        if let level = selectedExperienceLevel {
            if level == .debutant && yearsOfExperience > 2 {
                warnings.append("Tu as sélectionné Débutant mais \(yearsOfExperience) années d'expérience")
            } else if level == .intermediaire && (yearsOfExperience < 1 || yearsOfExperience > 5) {
                warnings.append("Cohérence à vérifier entre niveau et années d'expérience")
            }
        }

        return warnings
    }

    // MARK: - Helpers

    /// Vérifie si toutes les données critiques sont présentes
    func hasAllCriticalData() -> Bool {
        return isGenderSelected &&
               isAgeSelected &&
               isFirstNameEntered &&
               isMainGoalSelected &&
               isExperienceLevelSelected &&
               isTrainingConstraintsSelected &&
               isPersonalInfoCompleted &&
               isWeightGoalSelected
    }
}
