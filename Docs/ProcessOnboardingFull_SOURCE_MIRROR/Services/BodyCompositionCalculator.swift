//
//  BodyCompositionCalculator.swift
//  Process
//
//  Calculateur de composition corporelle basé sur formules validées
//

import Foundation

@MainActor
class BodyCompositionCalculator {

    /// Calcule la composition corporelle à partir des données disponibles
    static func calculate(
        height: Double,      // en cm
        weight: Double,      // en kg
        age: Int,
        gender: Gender,
        measurements: BodyMeasurements? = nil
    ) -> BodyComposition {
        var composition = BodyComposition()

        let heightInMeters = height / 100.0
        let bmi = weight / (heightInMeters * heightInMeters)
        composition.bmi = bmi

        // Calcul du pourcentage de masse grasse (formule de Deurenberg)
        let bodyFatPercentage = calculateBodyFatPercentage(
            bmi: bmi,
            age: age,
            gender: gender
        )
        composition.bodyFatPercentage = bodyFatPercentage

        // Calcul des masses
        composition.bodyFatMass = (bodyFatPercentage / 100.0) * weight
        composition.leanMass = weight - (composition.bodyFatMass ?? 0)

        // Calcul de la masse musculaire (estimation basée sur formule)
        let musclePercentage = calculateMusclePercentage(
            gender: gender,
            age: age,
            bodyFatPercentage: bodyFatPercentage
        )
        composition.muscleMassPercentage = musclePercentage
        composition.muscleMass = (musclePercentage / 100.0) * weight

        // Calcul de la masse osseuse (formule simple)
        let bonePercentage = calculateBonePercentage(
            gender: gender,
            weight: weight
        )
        composition.boneMassPercentage = bonePercentage
        composition.boneMass = (bonePercentage / 100.0) * weight

        // Calcul de l'eau corporelle (estimation)
        let waterPercentage = calculateWaterPercentage(
            gender: gender,
            age: age
        )
        composition.waterPercentage = waterPercentage
        composition.waterMass = (waterPercentage / 100.0) * weight

        // Calcul du BMR (formule de Mifflin-St Jeor)
        composition.bmr = calculateBMR(
            weight: weight,
            height: height,
            age: age,
            gender: gender
        )

        // Calcul de l'âge métabolique (estimation basée sur BMR)
        composition.metabolicAge = calculateMetabolicAge(
            bmr: composition.bmr ?? 0,
            age: age,
            gender: gender
        )

        return composition
    }

    // MARK: - Calculs individuels

    /// Pourcentage de masse grasse (formule de Deurenberg)
    private static func calculateBodyFatPercentage(
        bmi: Double,
        age: Int,
        gender: Gender
    ) -> Double {
        let base = (1.20 * bmi) + (0.23 * Double(age))
        let adjustment = gender == .male ? -16.2 : -5.4
        let bodyFat = base + Double(adjustment)
        return max(5.0, min(50.0, bodyFat)) // Limites réalistes
    }

    /// Pourcentage de masse musculaire (estimation)
    private static func calculateMusclePercentage(
        gender: Gender,
        age: Int,
        bodyFatPercentage: Double
    ) -> Double {
        // Estimation basique : 100% - graisse - os - eau - organes
        // Pourcentage moyen selon genre et âge
        let baseMuscle: Double = gender == .male ? 45.0 : 36.0
        let ageAdjustment = max(0, Double(age - 25)) * 0.1 // Réduction avec l'âge
        let bodyFatAdjustment = (bodyFatPercentage - 20.0) * 0.3 // Moins de muscle si plus de graisse

        return max(30.0, min(55.0, baseMuscle - ageAdjustment - bodyFatAdjustment))
    }

    /// Pourcentage de masse osseuse (estimation simple)
    private static func calculateBonePercentage(
        gender: Gender,
        weight: Double
    ) -> Double {
        // Formule basique basée sur le poids
        let baseBone: Double = gender == .male ? 3.5 : 2.5
        let weightAdjustment = (weight - 70.0) * 0.01
        return max(2.0, min(5.0, baseBone + weightAdjustment))
    }

    /// Pourcentage d'eau corporelle
    private static func calculateWaterPercentage(
        gender: Gender,
        age: Int
    ) -> Double {
        // Pourcentage moyen selon genre et âge
        let baseWater: Double = gender == .male ? 60.0 : 50.0
        let ageAdjustment = max(0, Double(age - 25)) * 0.05 // Réduction avec l'âge
        return max(45.0, min(65.0, baseWater - ageAdjustment))
    }

    /// BMR (Métabolisme de base) - Formule de Mifflin-St Jeor
    private static func calculateBMR(
        weight: Double,    // kg
        height: Double,    // cm
        age: Int,
        gender: Gender
    ) -> Double {
        let heightInCm = height
        let base = (10.0 * weight) + (6.25 * heightInCm) - (5.0 * Double(age))
        let adjustment = gender == .male ? 5.0 : -161.0
        return base + adjustment
    }

    /// Âge métabolique (estimation basée sur BMR)
    private static func calculateMetabolicAge(
        bmr: Double,
        age: Int,
        gender: Gender
    ) -> Int {
        // Estimation basée sur le BMR moyen pour l'âge réel
        // Si BMR plus élevé → âge métabolique plus jeune
        let averageBMR = calculateAverageBMRForAge(age: age, gender: gender)
        let difference = bmr - averageBMR
        let ageAdjustment = Int(difference / 10.0) // ~10 kcal par an de différence
        return max(18, min(80, age - ageAdjustment))
    }

    /// BMR moyen pour un âge donné (pour calcul âge métabolique)
    private static func calculateAverageBMRForAge(
        age: Int,
        gender: Gender
    ) -> Double {
        // Poids moyen pour l'âge (estimation)
        let averageWeight: Double = gender == .male ? 75.0 : 65.0
        let averageHeight: Double = gender == .male ? 175.0 : 165.0

        return calculateBMR(
            weight: averageWeight,
            height: averageHeight,
            age: age,
            gender: gender
        )
    }
}
