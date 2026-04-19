//
//  BodyScanModels.swift
//  Process
//
//  Modèles de données pour le scan corporel
//

import Foundation
import SwiftUI
import Vision

// MARK: - État du scan
enum BodyScanState {
    case idle           // État initial
    case preparing      // Préparation (instructions)
    case positioning    // Positionnement dans la silhouette
    case scanning       // Scan en cours (rotation)
    case analyzing      // Analyse des données
    case completed      // Scan terminé
    case error(String)  // Erreur
}

// MARK: - Analyse de posture
struct PostureAnalysis: Codable {
    // Alignements
    var shoulderAlignment: AlignmentStatus = .unknown
    var hipAlignment: AlignmentStatus = .unknown
    var spineAlignment: AlignmentStatus = .unknown

    // Angles
    var headAngle: Double?          // Angle de la tête (degrés)
    var shoulderAngle: Double?      // Angle des épaules (degrés)
    var hipAngle: Double?           // Angle du bassin (degrés)
    var kneeAngle: Double?          // Angle des genoux (degrés)

    // Déséquilibres détectés
    var imbalances: [PostureImbalance] = []

    // Score global de posture (0-100)
    var overallScore: Double = 0.0

    // Recommandations
    var recommendations: [String] = []
}

enum AlignmentStatus: String, Codable {
    case aligned       = "aligned"
    case misaligned    = "misaligned"
    case slightlyOff   = "slightly_off"
    case unknown       = "unknown"
}

struct PostureImbalance: Codable, Identifiable {
    var id: String = UUID().uuidString
    var type: ImbalanceType
    var severity: PostureSeverity
    var description: String
    var recommendation: String
}

enum ImbalanceType: String, Codable {
    case forwardHead       = "forward_head"
    case roundedShoulders  = "rounded_shoulders"
    case tiltedHips        = "tilted_hips"
    case unevenShoulders   = "uneven_shoulders"
    case swayBack          = "sway_back"
    case anteriorPelvis    = "anterior_pelvis"
    case kyphosis          = "kyphosis"
    case lordosis          = "lordosis"
}

enum PostureSeverity: String, Codable {
    case mild      = "mild"
    case moderate  = "moderate"
    case severe    = "severe"
}

// MARK: - Mensurations
struct BodyMeasurements: Codable {
    // Mensurations principales (en cm)
    var chest: Double?          // Tour de poitrine/torse
    var waist: Double?          // Tour de taille
    var hips: Double?           // Tour de hanches
    var neck: Double?           // Tour de cou
    var shoulders: Double?      // Largeur épaules

    // Membres supérieurs
    var biceps: Double?         // Tour de biceps
    var forearms: Double?       // Tour d'avant-bras
    var wrists: Double?         // Tour de poignets

    // Membres inférieurs
    var thighs: Double?         // Tour de cuisses
    var calves: Double?         // Tour de mollets
    var ankles: Double?         // Tour de chevilles

    // Proportions (ratios)
    var waistToHipRatio: Double?        // Ratio taille/hanches
    var shoulderToWaistRatio: Double?   // Ratio épaules/taille
    var armToTorsoRatio: Double?        // Ratio bras/torse

    // Longueurs (estimations relatives)
    var armLength: Double?      // Longueur bras (relatif)
    var legLength: Double?      // Longueur jambes (relatif)
    var torsoLength: Double?    // Longueur torse (relatif)
}

// MARK: - Composition corporelle
struct BodyComposition: Codable {
    // Pourcentages (estimés via formules)
    var bodyFatPercentage: Double?      // Pourcentage masse grasse
    var muscleMassPercentage: Double?   // Pourcentage masse musculaire
    var boneMassPercentage: Double?     // Pourcentage masse osseuse
    var waterPercentage: Double?        // Pourcentage eau

    // Masses (en kg, calculées si poids disponible)
    var bodyFatMass: Double?            // Masse grasse (kg)
    var muscleMass: Double?             // Masse musculaire (kg)
    var boneMass: Double?               // Masse osseuse (kg)
    var waterMass: Double?              // Masse eau (kg)
    var leanMass: Double?               // Masse maigre (kg)

    // Indices
    var bmi: Double?                    // IMC (si poids et taille disponibles)
    var bmr: Double?                    // Métabolisme de base (kcal/jour)
    var metabolicAge: Int?              // Âge métabolique estimé
}

// MARK: - Données complètes du scan
struct BodyScanData: Codable {
    var id: String = UUID().uuidString
    var scanDate: Date = Date()

    // Données sources
    var height: Double?                 // Taille en cm (pour calibration)
    var weight: Double?                 // Poids en kg (pour composition)
    var age: Int?                       // Âge (pour calculs)
    var gender: Gender?                 // Genre (pour calculs)

    // Analyses
    var postureAnalysis: PostureAnalysis?
    var measurements: BodyMeasurements?
    var composition: BodyComposition?

    // Images de scan (optionnel, sauvegardées en base64 ou URL)
    var frontImageData: Data?
    var sideImageData: Data?

    // Métadonnées
    var scanQuality: ScanQuality = .unknown
    var calibrationSuccessful: Bool = false
}

enum ScanQuality: String, Codable {
    case excellent    = "excellent"
    case good         = "good"
    case fair         = "fair"
    case poor         = "poor"
    case unknown      = "unknown"
}

// MARK: - Points de pose Vision
struct BodyPosePoints {
    // Points clés du squelette (33 points de MediaPipe/Vision)
    var nose: CGPoint?
    var leftEye: CGPoint?
    var rightEye: CGPoint?
    var leftEar: CGPoint?
    var rightEar: CGPoint?

    var leftShoulder: CGPoint?
    var rightShoulder: CGPoint?
    var leftElbow: CGPoint?
    var rightElbow: CGPoint?
    var leftWrist: CGPoint?
    var rightWrist: CGPoint?

    var leftHip: CGPoint?
    var rightHip: CGPoint?
    var leftKnee: CGPoint?
    var rightKnee: CGPoint?
    var leftAnkle: CGPoint?
    var rightAnkle: CGPoint?

    // Points supplémentaires pour analyse
    var neck: CGPoint?         // Point du cou (moyenne épaules)
    var centerHip: CGPoint?    // Centre du bassin
    var centerShoulder: CGPoint? // Centre des épaules
}
