//
//  OnboardingStep.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import Foundation

enum OnboardingStep: Int, CaseIterable {
    case videoIntroduction = 0
    case genderSelection = 1
    case ageSelection = 2
    case height = 3                         // ✨ Taille (nouvelle page séparée)
    case weight = 67                         // ✨ Poids (nouvelle page séparée)
    case heightWeight = 68                   // ✨ Ancienne page combinée (dépréciée, gardée pour compatibilité)
    case bodyScan = 63                      // ✨ Scan corporel (après weight pour avoir taille/poids)
    case firstNameInput = 4
    case personalizedWelcome = 5             // ✨ Page de bienvenue personnalisée après prénom
    case processResultsDurability = 6       // ✨ Process génère des résultats durables (graphique performance)
    case primaryGoal = 7                    // ✨ Objectif principal (4 choix)

    // Questions spécifiques selon l'objectif (tous les utilisateurs passent par au moins une)
    case weightGoal = 8                    // Si primaryGoal = manageWeight
    case weightGoalIncompatible = 9        // ✨ Objectif incompatible avec IMC (blocage)
    case idealWeight = 10                   // Si weightGoal = perdre/prendre
    case weightMotivation = 11                // ✨ Page de motivation après poids idéal
    case hasSportActivity = 12              // ✨ Pratiques-tu une activité sportive ? (Oui/Non)
    case sportSelection = 13                // Si primaryGoal = improvePerformance / betterRecovery / moreEnergy
    case sportClub = 14                     // ✨ Fais-tu de [sport] en club actuellement ? (Oui/Non)
    case experienceLevel = 15               // Si primaryGoal = improvePerformance / betterRecovery / moreEnergy
    /// Conservé pour compatibilité sauvegarde — écran supprimé.
    case yearsOfExperience = 16

    // Questions générales (TOUS les utilisateurs passent par là)
    case deadlineSelection = 17              // ✨ Sélection de deadline (si poids non sélectionné)
    case eventDetails = 18                    // ✨ Détails de l'événement (date, type, etc.) - après deadlineSelection si "Oui"
    case goalProjection = 19                  // ✨ Projection dynamique avec courbe (après deadline)
    case goalPace = 20                        // ✨ Vitesse d'atteinte d'objectif poids (si objectif poids sélectionné)
    case potentialPace = 21                   // ✨ Vitesse d'atteinte de 100% du potentiel (si objectif poids NON sélectionné)
    case weightEstimation = 22                // ✨ Estimation de la date d'atteinte du poids idéal
    case trainingFrequency = 23                // ✨ Fréquence d'entraînement (pour tous)

    // Nutrition (TOUS les utilisateurs passent par là)
    case nutritionQuality = 24                // ✨ Qualité de l'alimentation actuelle
    /// Conservé pour compatibilité sauvegarde — écran supprimé, saut automatique.
    case nutritionScanFeature = 25
    case hasDietaryRestrictions = 26          // ✨ As-tu des restrictions alimentaires ? (Oui/Non)
    case whichRestrictions = 27               // ✨ Quelles restrictions as-tu ? (détails)
    case nutritionObstacles = 28              // ✨ Obstacles à une bonne nutrition
    case weightManagementExperience = 29      // ✨ Expérience avec perte/prise de poids (si objectif poids)
    case weightFailureReasons = 30            // ✨ Qu'est-ce qui t'a empêché de réussir ? (si triedMultiple ou currentlyTrying)
    case perfectNutritionBelief = 31          // ✨ Croyance en une alimentation parfaite
    case hardestMeal = 32                     // ✨ Repas le plus difficile pour manger sainement
    case nutritionPotential = 33              // ✨ Vous avez un grand potentiel pour atteindre votre objectif
    case hasSufficientHydration = 34          // ✨ Penses-tu t'hydrater suffisamment ? (Oui/Non)
    case hydrationLevel = 35                  // ✨ Niveau d'hydratation

    // Sommeil (TOUS les utilisateurs passent par là)
    case sleepInfo = 36                       // ✨ Information sur l'importance du sommeil
    case sleepQuality = 37                    // ✨ Qualité perçue du sommeil
    case fatigueFrequency = 38                // ✨ Fréquence de fatigue
    case fatiguePeaks = 39                    // ✨ Pics de fatigue
    case sleepNeed = 40                       // ✨ Découvre ton besoin de sommeil réel

    // Finalisation
    case healthKitPermissions = 41            // ✨ Autoriser l'accès HealthKit
    case faceAnalysis = 42                    // ✨ Analyse faciale (cernes, rétention d'eau, sommeil)
    case planGeneration = 43                  // ✨ Créons ton plan personnalisé
    case sleepDataRecovery = 44                // ✨ Animation récupération données HealthKit
    /// Valeurs conservées pour la compatibilité des sauvegardes — écrans supprimés, saut automatique vers `alarmConfiguration`.
    case newsStep = 45
    case sleepNeedReveal = 46
    case sleepDebtInfo = 47
    case alarmConfiguration = 48                // ✨ Page de configuration de la première alarme
    case sleepWindowReveal = 49                // ✨ Page révélant la fenêtre de sommeil personnalisée
    case planReady = 50                        // ✨ Ton programme personnalisé est prêt
    case onboardingInfo = 51                   // ✨ Page d'information (texte + bouton continuer)
    case appleSignIn = 52
    case referralCode = 53                     // ✨ Entrez le code de parrainage (facultatif)
    case appRating = 54                        // ✨ Donnez-nous une note
    case caloriesGoal = 55                     // ✨ Ajouter les calories brûlées à votre objectif quotidien ?
    case carryOverCalories = 56                // ✨ Reportez-vous aux calories supplémentaires au lendemain ?
    case programCreation = 57                  // ✨ Création de votre programme avec animations
    case biometricAuth = 58                    // ✨ Authentification biométrique (empreinte digitale)
    case notificationPermission = 59           // ✨ Demande de permission notifications
    case payment = 60
    case processWelcome = 61                   // ✨ Page de bienvenue "Bienvenue dans PROCESS"
    case referralReward = 62                   // ✨ Page de parrainage avec slider de gains
    case featuresUnlock = 65                   // ✨ Page de déblocage progressif des fonctionnalités
    case complete = 66
    // Note: bodyScan = 63 est placé après heightWeight mais avant firstNameInput pour logique de flow

    var isStoryPage: Bool {
        return false
    }

    var hasButton: Bool {
        switch self {
        case .videoIntroduction, .goalProjection, .sleepDataRecovery, .faceAnalysis, .sleepInfo, .weightEstimation, .planReady, .notificationPermission, .biometricAuth, .caloriesGoal, .carryOverCalories, .referralCode, .appRating, .processWelcome, .referralReward, .featuresUnlock, .processResultsDurability, .weightMotivation, .nutritionPotential, .programCreation, .sleepWindowReveal, .personalizedWelcome, .weightGoalIncompatible, .bodyScan:
            return false  // Auto-avancement ou page avec navigation interne
        default:
            return true
        }
    }

    static var totalSteps: Int { 69 } // height=3, weight=67, heightWeight=68 (déprécié), bodyScan=63, featuresUnlock=65, complete=66
}
