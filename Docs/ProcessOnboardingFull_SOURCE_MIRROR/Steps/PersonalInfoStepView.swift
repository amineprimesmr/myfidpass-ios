//
//  PersonalInfoStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth
import HealthKit

// Struct pour les animations des questions
struct QuestionAnimation: Equatable {
    var scale: CGFloat
    var opacity: Double
    var blur: CGFloat
    var offset: CGFloat

    static let `default` = QuestionAnimation(scale: 1.0, opacity: 1.0, blur: 0, offset: 0)
}

struct PersonalInfoStepView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var currentQuestion = 0
    @State private var birthDate = Date()
    @State private var height: Double = 170.0 // en cm
    @State private var weight: Double = 70.0 // en kg
    @State private var idealWeight: Double = 70.0 // en kg
    @State private var confirmedAnswers: [String] = []
    @State private var isLoadingData = true
    @State private var allQuestionsCompleted = false

    // États pour les animations distinctes
    @State private var isAnimatingCurrentToBackground = false
    @State private var isAnimatingNewQuestion = false
    @State private var currentQuestionOffset: CGFloat = 0
    @State private var currentQuestionScale: CGFloat = 1.0
    @State private var currentQuestionOpacity: Double = 1.0
    @State private var currentQuestionBlur: CGFloat = 0

    // États d'animation pour chaque question individuellement
    @State private var questionAnimations: [Int: QuestionAnimation] = [:]

    // Callback pour passer à la page suivante
    var onComplete: (() -> Void)?

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    private let questions = [
        "Quand es-tu né ?",
        "Combien mesures-tu ?",
        "Quel est ton poids ?",
        "Quel est ton poids idéal ?"
    ]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Questions précédentes (petites et floues en haut)
                if currentQuestion > 0 {
                    VStack(spacing: 24) {
                        ForEach(0..<currentQuestion, id: \.self) { index in
                            Button(action: {
                                // Vibration pour la sélection
                                HapticManager.shared.impact(.light)

                                // Revenir à la question sélectionnée
                                withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                                    currentQuestion = index
                                    // Supprimer les réponses suivantes
                                    confirmedAnswers = Array(confirmedAnswers.prefix(index))
                                }
                            }) {
                                VStack(spacing: 6) {
                                    Text(questions[index])
                                        .font(.system(size: 18, weight: .medium)) // Plus gros que 14
                                        .foregroundColor(.white.opacity(0.3)) // Plus flou que 0.4
                                        .blur(radius: 2) // Plus flou que 1

                                    Text(confirmedAnswers[index])
                                        .font(.system(size: 16, weight: .regular)) // Plus gros que 12
                                        .foregroundColor(.white.opacity(0.2)) // Plus flou que 0.3
                                        .blur(radius: 1.5) // Plus flou que 0.5
                                }
                                .scaleEffect(0.9) // Plus gros que 0.8
                                .opacity(0.6)
                                .animation(
                                    .spring(response: 1.2, dampingFraction: 0.8, blendDuration: 0.3)
                                    .delay(Double(index) * 0.1),
                                    value: currentQuestion
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.top, 20)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.7))
                                .combined(with: .move(edge: .top))
                                .animation(.spring(response: 1.0, dampingFraction: 0.7)),
                            removal: .opacity.combined(with: .scale(scale: 1.2))
                                .combined(with: .move(edge: .bottom))
                                .animation(.spring(response: 0.8, dampingFraction: 0.6))
                        )
                    )
                }

                Spacer()

                // Question actuelle (grande et centrée) - position fixe
                VStack(spacing: 10) { // Petit espacement entre titre et contenu
                    if isLoadingData {
                        // Indicateur de chargement
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)

                            Text("Récupération de tes données...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Titre de la question avec animations distinctes
                        Text(questions[currentQuestion])
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .scaleEffect(getQuestionAnimation(for: currentQuestion).scale)
                            .opacity(getQuestionAnimation(for: currentQuestion).opacity)
                            .blur(radius: getQuestionAnimation(for: currentQuestion).blur)
                            .offset(y: getQuestionAnimation(for: currentQuestion).offset)
                            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: questionAnimations[currentQuestion])

                        // Contenu selon la question (toujours à la même hauteur)
                        VStack(spacing: 0) {
                            if currentQuestion == 0 {
                                // Sélecteur de date
                                DatePicker("Date de naissance", selection: $birthDate, displayedComponents: .date)
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .labelsHidden()
                                    .colorScheme(.dark)
                                    .accentColor(.white)
                                    .onChange(of: birthDate) { _ in
                                        HapticManager.shared.selection()
                                    }
                                    .frame(height: 200)
                            } else if currentQuestion == 1 {
                                // Slider pour la taille
                                HStack(spacing: 16) {
                                    // Slider raccourci
                                    Slider(value: $height, in: 140...210, step: 1)
                                        .accentColor(.white)
                                        .frame(height: 20)
                                        .onChange(of: height) { _ in
                                            HapticManager.shared.selection()
                                        }

                                    // Bouton glass avec la réponse
                                    Button(action: {}) {
                                        Text("\(Int(height)) cm")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 20)
                                    }
                                    .glassStyle()
                                    .buttonBorderShape(.roundedRectangle(radius: 10))
                                    .disabled(true)
                                }
                                .frame(height: 60) // Hauteur spécifique pour le slider taille
                            } else if currentQuestion == 2 {
                                // Slider pour le poids
                                HStack(spacing: 16) {
                                    // Slider raccourci
                                    Slider(value: $weight, in: 50...130, step: 0.5)
                                        .accentColor(.white)
                                        .frame(height: 20)
                                        .onChange(of: weight) { _ in
                                            HapticManager.shared.selection()
                                        }

                                    // Bouton glass avec la réponse
                                    Button(action: {}) {
                                        Text("\(Int(weight)) kg")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 20)
                                    }
                                    .glassStyle()
                                    .buttonBorderShape(.roundedRectangle(radius: 10))
                                    .disabled(true)
                                }
                                .frame(height: 60) // Hauteur spécifique pour le slider poids
                            } else if currentQuestion == 3 {
                                // Slider pour le poids idéal
                                HStack(spacing: 16) {
                                    // Slider raccourci
                                    Slider(value: $idealWeight, in: 50...130, step: 0.5)
                                        .accentColor(.white)
                                        .frame(height: 20)
                                        .onChange(of: idealWeight) { _ in
                                            HapticManager.shared.selection()
                                        }

                                    // Bouton glass avec la réponse
                                    Button(action: {}) {
                                        Text("\(Int(idealWeight)) kg")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                            .frame(width: 80, height: 20)
                                    }
                                    .glassStyle()
                                    .buttonBorderShape(.roundedRectangle(radius: 10))
                                    .disabled(true)
                                }
                                .frame(height: 60) // Hauteur spécifique pour le slider poids idéal
                            }
                        }
                        .padding(.horizontal, 40)
                        .scaleEffect(getQuestionAnimation(for: currentQuestion).scale)
                        .opacity(getQuestionAnimation(for: currentQuestion).opacity)
                        .blur(radius: getQuestionAnimation(for: currentQuestion).blur)
                        .offset(y: getQuestionAnimation(for: currentQuestion).offset)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7), value: questionAnimations[currentQuestion])
                    }
                }

                Spacer()
                    .frame(height: 60) // Un peu moins bas que 100

                // Bouton continuer (seulement si toutes les questions ne sont pas terminées)
                if !allQuestionsCompleted {
                    Button(action: {
                        HapticManager.shared.impact(.medium)

                        // Ajouter la réponse actuelle aux réponses confirmées
                        let currentAnswer: String
                        switch currentQuestion {
                        case 0:
                            currentAnswer = "Né le \(dateFormatter.string(from: birthDate))"
                        case 1:
                            currentAnswer = "\(Int(height)) cm"
                        case 2:
                            currentAnswer = "\(Int(weight)) kg"
                        case 3:
                            currentAnswer = "\(Int(idealWeight)) kg"
                        default:
                            currentAnswer = ""
                        }

                        confirmedAnswers.append(currentAnswer)

                        // ANIMATION 1: Question actuelle se déplace vers le haut (en arrière-plan)
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                            setQuestionAnimation(for: currentQuestion, scale: 0.9, opacity: 0.3, blur: 2, offset: -300)
                        }

                        // ANIMATION 2: Nouvelle question apparaît en bas après un délai
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            // Passer à la question suivante
                            if currentQuestion < questions.count - 1 {
                                currentQuestion += 1

                                // La nouvelle question apparaît directement en bas (valeurs par défaut)
                                // Pas besoin de réinitialiser car elle n'a pas encore d'animation
                            } else {
                                // Dernière question terminée
                                savePersonalData()
                                allQuestionsCompleted = true

                                // Notifier la validation
                                onValidationChanged?(true)

                                onComplete?()
                            }
                        }
                    }) {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .scaleEffect(1.0)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.8)
                        .delay(0.2),
                        value: currentQuestion
                    )
                }
            }
        }
        .onAppear {
            loadPersonalDataFromHealthKit()
        }
    }

    private func loadPersonalDataFromHealthKit() {
        Task {
            // PersonalInfo - Chargement des données personnelles depuis le profil utilisateur...

            await MainActor.run {
                // Récupérer les données depuis le profil utilisateur
                if let profile = profileService.currentProfile {
                    // Utiliser les données du profil si disponibles
                    if profile.height > 0 {
                        height = profile.height
                        // PersonalInfo - Taille récupérée du profil: \(height) cm
                    } else {
                        // PersonalInfo - Aucune taille dans le profil
                    }

                    if profile.weight > 0 {
                        weight = profile.weight
                        // PersonalInfo - Poids récupéré du profil: \(weight) kg
                    } else {
                        // PersonalInfo - Aucun poids dans le profil
                    }

                    if profile.birthDate != Date(timeIntervalSince1970: 0) {
                        birthDate = profile.birthDate
                        // PersonalInfo - Date de naissance récupérée du profil: \(birthDate)
                    } else {
                        // PersonalInfo - Aucune date de naissance dans le profil
                    }
                } else {
                    // PersonalInfo - Aucun profil utilisateur trouvé
                }

                // Fallback vers HealthKit si pas de données dans le profil
                if height == 170.0 && weight == 70.0 {
                    // PersonalInfo - Fallback vers HealthKit...
                    if healthManager.height > 0 {
                        height = healthManager.height * 100 // Convertir de mètres en cm
                        // PersonalInfo - Taille récupérée de HealthKit: \(height) cm
                    }

                    if healthManager.bodyMass > 0 {
                        weight = healthManager.bodyMass
                        // PersonalInfo - Poids récupéré de HealthKit: \(weight) kg
                    }
                }

                // Fallback pour la date de naissance
                if birthDate == Date() {
                    let calendar = Calendar.current
                    if let defaultBirthDate = calendar.date(byAdding: .year, value: -25, to: Date()) {
                        birthDate = defaultBirthDate
                    }
                }

                isLoadingData = false
                // PersonalInfo - Données chargées - Taille: \(height)cm, Poids: \(weight)kg, Naissance: \(birthDate)
            }
        }
    }

    // MARK: - Animation Functions

    private func getQuestionAnimation(for questionIndex: Int) -> QuestionAnimation {
        return questionAnimations[questionIndex] ?? QuestionAnimation.default
    }

    private func setQuestionAnimation(for questionIndex: Int, scale: CGFloat, opacity: Double, blur: CGFloat, offset: CGFloat) {
        questionAnimations[questionIndex] = QuestionAnimation(scale: scale, opacity: opacity, blur: blur, offset: offset)
    }

    private func resetQuestionAnimation() {
        currentQuestionScale = 1.0
        currentQuestionOpacity = 1.0
        currentQuestionBlur = 0
        currentQuestionOffset = 0
    }

    private func savePersonalData() {
        Task {
            // PersonalInfo - Sauvegarde des données personnelles...

            // Sauvegarder dans le profil utilisateur
            if let profile = profileService.currentProfile {
                // Calculer l'âge à partir de la date de naissance
                let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0

                let updates: [String: Any] = [
                    "height": height,
                    "weight": weight,
                    "birthDate": birthDate,
                    "age": age,
                    "idealWeight": idealWeight
                ]

                do {
                    if var currentProfile = profileService.currentProfile {
                        currentProfile.height = height
                        currentProfile.weight = weight
                        currentProfile.idealWeight = idealWeight
                        try await profileService.saveProfile(currentProfile)
                        Logger.debug("Données personnelles sauvegardées dans le profil", category: "General")
                    }
                } catch {
                    Logger.error("Erreur sauvegarde données personnelles: \(error)", category: "General")
                }
}
}
}
}
