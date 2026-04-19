//
//  OnboardingViewModel.swift
//  Process
//
//  ViewModel unifié pour remplacer tous les @State dispersés dans OnboardingView
//

import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class OnboardingViewModel: ObservableObject {
    // MARK: - Progression
    @Published var currentStep: Int = 0
    @Published var visitedSteps: [Int] = [] // Historique des étapes visitées pour navigation retour
    @Published var isCompleting: Bool = false
    @Published var isLoading: Bool = false
    @Published var isRequestingHealthKit: Bool = false
    @Published var healthKitGranted: Bool = false
    @Published var errorMessage: String?

    // MARK: - Informations personnelles
    @Published var selectedGender: Gender?
    @Published var selectedAge: Int = 25
    @Published var selectedHeight: Double = 175 // cm
    @Published var selectedWeight: Double = 70 // kg
    @Published var firstName: String = ""
    @Published var idealWeightValue: Double = 70.0
    @Published var bodyScanData: BodyScanData?

    // MARK: - Objectifs
    @Published var selectedPrimaryGoals: Set<PrimaryGoal> = []
    @Published var selectedWeightGoal: WeightGoal?
    @Published var goalDeadline: GoalDeadline = GoalDeadline()
    @Published var selectedGoalPace: GoalPace?

    // MARK: - Sport et expérience
    @Published var hasSportActivity: Bool?  // ✨ Pratiques-tu une activité sportive ?
    @Published var isInClub: Bool?  // ✨ Fais-tu du sport en club ?
    @Published var selectedExperienceLevel: ExperienceLevel?
    @Published var selectedYearsOfExperience: Int = 0
    @Published var selectedTrainingFrequency: String?
    @Published var selectedSessionsPerWeek: Int = 3
    @Published var selectedSessionDuration: Int = 60
    @Published var selectedTrainingLocation: TrainingLocation = .mixed
    @Published var selectedEquipment: Set<PlanEquipment> = []

    // MARK: - Nutrition
    @Published var nutritionProfile = NutritionProfile()
    @Published var hasDietaryRestrictions: Bool?
    @Published var otherDietaryRestriction: String = ""

    // MARK: - Navigation
    @Published var pendingSpecificSteps: [OnboardingStep] = []
    @Published var hasDoneFirstGoalPace: Bool = false

    // MARK: - États de validation
    @Published var isGenderSelected: Bool = false
    @Published var isAgeSelected: Bool = false
    @Published var isHeightWeightSelected: Bool = false {
        didSet {
            Logger.debug("[OnboardingViewModel] isHeightWeightSelected changed to: \(isHeightWeightSelected)", category: "Onboarding")
        }
    }
    @Published var isBodyScanCompleted: Bool = false
    @Published var isFirstNameEntered: Bool = false
    @Published var isPrimaryGoalSelected: Bool = false
    @Published var isWeightGoalSelected: Bool = false
    @Published var isIdealWeightEntered: Bool = false
    @Published var isSportsSelected: Bool = false
    @Published var isExperienceLevelSelected: Bool = false
    @Published var isTrainingFrequencySelected: Bool = false
    @Published var isDeadlineSelected: Bool = false
    @Published var isGoalPaceSelected: Bool = false
    @Published var isNutritionQualitySelected: Bool = false
    @Published var isHasDietaryRestrictionsSelected: Bool = false
    @Published var isWhichRestrictionsSelected: Bool = false
    @Published var isNutritionObstaclesSelected: Bool = false
    @Published var isWeightManagementExperienceSelected: Bool = false
    @Published var isHardestMealSelected: Bool = false
    @Published var isHasSufficientHydrationSelected: Bool = false
    @Published var isHydrationLevelSelected: Bool = false
    @Published var isPersonalizedWelcomeCompleted: Bool = false // ✅ Validation pour personalizedWelcome
    @Published var isWeightMotivationCompleted: Bool = false // ✅ Validation pour weightMotivation
    @Published var isWeightEstimationCompleted: Bool = false // ✅ Validation pour weightEstimation (après animation du compteur)
    @Published var isSleepQualitySelected: Bool = false
    @Published var isFatigueFrequencySelected: Bool = false
    @Published var isFatiguePeaksSelected: Bool = false
    @Published var isFaceAnalysisCompleted: Bool = false
    @Published var isProgramCreationCompleted: Bool = false

    // MARK: - Sleep Profile (migré complètement vers ViewModel)
    @Published var sleepProfile = SleepProfile()

    // MARK: - Referral
    @Published var referralCode: String? // Code de parrainage utilisé à l'inscription

    private let totalSteps = 48

    // MARK: - Initialization

    init() {
        // Charger la progression sauvegardée
        let savedStep = OnboardingProgressService.shared.loadCurrentStep()

        // ✅ CORRECTION: Charger l'historique complet des étapes visitées depuis UserDefaults
        let savedVisitedSteps = OnboardingProgressService.shared.loadVisitedSteps()

        if savedStep > 0 && savedStep < totalSteps {
            currentStep = savedStep

            // ✅ Si on a un historique sauvegardé, l'utiliser
            if !savedVisitedSteps.isEmpty {
                visitedSteps = savedVisitedSteps
                // ✅ S'assurer que l'étape actuelle est dans l'historique
                if !visitedSteps.contains(savedStep) {
                    visitedSteps.append(savedStep)
                }
            } else {
                // ✅ Si pas d'historique, reconstruire depuis l'étape sauvegardée
                // On reconstruit un historique minimal : toutes les étapes de 0 à savedStep
                visitedSteps = Array(0...savedStep)
            }
        } else {
            // Commencer avec la première étape
            if !savedVisitedSteps.isEmpty {
                visitedSteps = savedVisitedSteps
            } else {
                visitedSteps = [0]
            }
        }

        Logger.debug("Historique restauré: \(visitedSteps), Étape actuelle: \(currentStep)", category: "Onboarding")

        // ✅ La synchronisation avec le profil se fait dans OnboardingView.onAppear et onChange
        // car le profil n'est pas encore chargé à ce stade
    }

    // MARK: - Synchronization

    /// ✅ CORRECTION: Synchroniser le ViewModel avec le profil existant
    func syncWithExistingProfile(_ profile: UnifiedUserProfile?) {
        guard let profile = profile else { return }

        // ✅ CRITIQUE: Charger toutes les données du profil dans le ViewModel
        // Ne mettre à jour que si le ViewModel n'a pas encore de valeur ou si le profil a une valeur valide
        // ✅ NE JAMAIS charger "Utilisateur" qui est une valeur par défaut
        if !profile.firstName.isEmpty && profile.firstName != "Utilisateur" {
            // Ne pas écraser si l'utilisateur a déjà saisi un prénom différent
            if firstName.isEmpty || firstName == "Utilisateur" {
                firstName = profile.firstName
            }
        } else {
            // Si le profil a "Utilisateur" ou est vide, vider le champ pour forcer la saisie
            if firstName == "Utilisateur" {
                firstName = ""
            }
        }

        // L'âge doit être saisi manuellement par l'utilisateur lors de l'onboarding
        // Cela évite les problèmes de valeurs par défaut erronées (13, 16, etc.)
        // L'âge sera sauvegardé quand l'utilisateur le sélectionne dans AgeSelectionStepView

        // ✅ Si l'utilisateur a déjà validé un âge valide (différent de 25), le garder
        // Mais ne pas charger depuis le profil pour éviter les valeurs erronées

        // ✅ CRITIQUE: Charger la taille et le poids
        if profile.height > 0 {
            selectedHeight = profile.height
        }
        if profile.weight > 0 {
            selectedWeight = profile.weight
        }
        if profile.idealWeight != nil && profile.idealWeight! > 0 {
            idealWeightValue = profile.idealWeight!
            isIdealWeightEntered = true
        }

        // ✅ CRITIQUE: Charger le genre
        if profile.gender != .preferNotToSay {
            selectedGender = profile.gender
            isGenderSelected = true
        }

        Logger.debug("ViewModel synchronisé avec le profil - Âge: \(selectedAge), Taille: \(selectedHeight), Poids: \(selectedWeight)", category: "Onboarding")
    }

    // MARK: - Validation

    func isCurrentStepValidated() -> Bool {
        switch OnboardingStep(rawValue: currentStep) {
        case .genderSelection:
            return isGenderSelected && selectedGender != nil
        case .ageSelection:
            return isAgeSelected && selectedAge > 0 && selectedAge <= 120
        case .height:
            let isValid = isHeightWeightSelected && selectedHeight > 0
            Logger.debug("[OnboardingViewModel] Validation height: isValid=\(isValid), isHeightWeightSelected=\(isHeightWeightSelected), selectedHeight=\(selectedHeight)", category: "Onboarding")
            return isValid
        case .weight:
            let isValid = isHeightWeightSelected && selectedWeight > 0
            Logger.debug("[OnboardingViewModel] Validation weight: isValid=\(isValid), isHeightWeightSelected=\(isHeightWeightSelected), selectedWeight=\(selectedWeight)", category: "Onboarding")
            return isValid
        case .heightWeight:
            return isHeightWeightSelected && selectedHeight > 0 && selectedWeight > 0
        case .bodyScan:
            // Le scan corporel est optionnel - toujours valide pour continuer
            return true // L'utilisateur peut passer le scan
        case .firstNameInput:
            return isFirstNameEntered && !firstName.trimmingCharacters(in: .whitespaces).isEmpty
        case .appleSignIn:
            // ✅ CRITIQUE: L'étape Apple Sign In est validée si l'utilisateur est authentifié
            return Auth.auth().currentUser != nil
        case .primaryGoal:
            return isPrimaryGoalSelected && !selectedPrimaryGoals.isEmpty
        case .weightGoal:
            return isWeightGoalSelected && selectedWeightGoal != nil
        case .idealWeight:
            return isIdealWeightEntered && idealWeightValue > 0
        case .sportSelection:
            return isSportsSelected
        case .hasSportActivity:
            // ✅ Le bouton n'apparaît que si l'utilisateur a sélectionné Oui ou Non
            return hasSportActivity != nil
        case .sportClub:
            // ✅ Le bouton n'apparaît que si l'utilisateur a sélectionné Oui ou Non
            return isInClub != nil
        case .experienceLevel:
            return isExperienceLevelSelected && selectedExperienceLevel != nil
        case .deadlineSelection, .eventDetails, .newsStep, .sleepNeedReveal, .sleepDebtInfo, .nutritionScanFeature, .yearsOfExperience:
            // Pages retirées du flux — auto-skip si ancienne sauvegarde
            return true
        case .goalPace:
            return isGoalPaceSelected && selectedGoalPace != nil
        case .potentialPace:
            // ✅ CORRIGÉ: potentialPace est une page vide (EmptyView) qui passe automatiquement
            // Elle doit TOUJOURS être validée pour que nextStep() puisse fonctionner
            return true
        case .trainingFrequency:
            // ✅ CORRIGÉ: trainingFrequency est une page vide (EmptyView) qui passe automatiquement
            // Elle doit TOUJOURS être validée pour que nextStep() puisse fonctionner
            return true
        case .nutritionQuality:
            return isNutritionQualitySelected && nutritionProfile.nutritionQuality != nil
        case .hasDietaryRestrictions:
            return isHasDietaryRestrictionsSelected && hasDietaryRestrictions != nil
        case .whichRestrictions:
            return isWhichRestrictionsSelected || hasDietaryRestrictions == false
        case .hardestMeal:
            return isHardestMealSelected
        case .hasSufficientHydration:
            // ✅ CORRIGÉ: Page vide (EmptyView) qui passe automatiquement
            return true
        case .hydrationLevel:
            // ✅ CORRIGÉ: Page vide (EmptyView) qui passe automatiquement
            return true
        case .sleepQuality:
            return isSleepQualitySelected
        case .fatigueFrequency:
            return isFatigueFrequencySelected
        case .fatiguePeaks:
            return isFatiguePeaksSelected
        case .sleepNeed:
            // ✅ Page informative, toujours validée
            return true
        case .faceAnalysis:
            // ✅ CORRIGÉ: Page vide (EmptyView) qui passe automatiquement
            return true
        case .programCreation:
            return isProgramCreationCompleted
        case .weightManagementExperience:
            // Si pas d'objectif poids, on skip cette étape
            if !selectedPrimaryGoals.contains(.manageWeight) {
                return true
            }
            return isWeightManagementExperienceSelected
        case .personalizedWelcome:
            // ✅ Le bouton n'apparaît qu'après que tous les textes soient complètement affichés
            return isPersonalizedWelcomeCompleted
        case .weightMotivation:
            // ✅ Le bouton n'apparaît qu'après que tous les textes soient complètement affichés
            return isWeightMotivationCompleted
        case .weightEstimation:
            // ✅ Le bouton n'apparaît qu'après que l'animation du compteur soit terminée
            return isWeightEstimationCompleted
        default:
            return true
        }
    }

    // MARK: - Cross-step Validation

    func validateCrossStepConsistency() -> [String] {
        var warnings: [String] = []

        // Années d'expérience non collectées dans l'onboarding — pas de cohérence niveau / années

        // Cohérence poids idéal
        if let weightGoal = selectedWeightGoal {
            if weightGoal == .lose && idealWeightValue >= selectedWeight {
                warnings.append("Poids idéal supérieur ou égal au poids actuel pour perte de poids")
            } else if weightGoal == .gain && idealWeightValue <= selectedWeight {
                warnings.append("Poids idéal inférieur ou égal au poids actuel pour prise de poids")
            }
        }

        return warnings
    }

    // MARK: - Progress Management

    func saveProgress() {
        OnboardingProgressService.shared.saveCurrentStep(currentStep)
        OnboardingProgressService.shared.saveLastCompletedStep(currentStep)
        // ✅ CORRECTION: Sauvegarder l'historique des étapes visitées
        OnboardingProgressService.shared.saveVisitedSteps(visitedSteps)
    }

    func resetProgress() {
        OnboardingProgressService.shared.resetProgress()
        // ✅ FINALISATION: Réinitialiser sleepProfile dans le ViewModel
        sleepProfile = SleepProfile()
        currentStep = 0
    }
}
