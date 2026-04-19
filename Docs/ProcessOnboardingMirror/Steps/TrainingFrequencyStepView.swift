//
//  TrainingFrequencyStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct TrainingFrequencyStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var selectedFrequency: String?

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    // ✅ NOUVEAU: Jours de la semaine + "Ça dépend"
    @State private var selectedDays: Set<DayOfWeek> = []
    @State private var isVariable: Bool = false  // "Ça dépend"
    @State private var showingDayPicker = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var buttonOffset: CGFloat = 0

    private let weekDays: [DayOfWeek] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    private var displayText: String {
        if isVariable {
            return "Ça dépend"
        } else if !selectedDays.isEmpty {
            let sortedDays = selectedDays.sorted { $0.rawValue < $1.rawValue }
            if selectedDays.count == 1 {
                return sortedDays.first?.displayName ?? ""
            } else if selectedDays.count <= 3 {
                return sortedDays.map { $0.displayName }.joined(separator: ", ")
            } else {
                return "\(selectedDays.count) jours"
            }
        } else {
            return "Sélectionner les jours"
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // ✅ UN SEUL GRAND BOUTON LIQUID GLASS
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        buttonScale = 0.95
                        showingDayPicker = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            buttonScale = 1.0
                        }
                    }
                }) {
                    HStack(spacing: 16) {
                        Image(systemName: selectedDays.isEmpty && !isVariable ? "calendar.badge.plus" : "calendar")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(displayText)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            if !selectedDays.isEmpty && !isVariable {
                                Text("\(selectedDays.count) jour\(selectedDays.count > 1 ? "s" : "")")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            } else if !isVariable {
                                Text("Appuyer pour sélectionner")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                }
                .frame(maxWidth: .infinity)
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 20))
                .controlSize(.large)
                .scaleEffect(buttonScale)
                .offset(y: buttonOffset)
                .padding(.horizontal, 40)

                Spacer()
            }

            // ✅ Titre en OVERLAY
            VStack {
                OnboardingTitleView("Quels jours", "as-tu entraînement ?")
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
        .sheet(isPresented: $showingDayPicker, onDismiss: {
            updateSelectedFrequency()
            onValidationChanged?(!selectedDays.isEmpty || isVariable)
            saveTrainingDays()
        }) {
            DayPickerSheet(
                selectedDays: $selectedDays,
                isVariable: $isVariable
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Animation d'entrée
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                buttonOffset = 0
            }

            // Charger les jours sélectionnés depuis le profil si disponibles
            loadTrainingDays()

            // Valider si déjà sélectionné
            if !selectedDays.isEmpty || isVariable {
                onValidationChanged?(true)
            }
        }
    }

    // ✅ Mettre à jour selectedFrequency avec les jours sélectionnés
    private func updateSelectedFrequency() {
        if isVariable {
            selectedFrequency = "variable"
        } else if !selectedDays.isEmpty {
            // Créer une chaîne avec les jours sélectionnés (ex: "Lundi,Mardi,Mercredi")
            let daysString = selectedDays.sorted { $0.rawValue < $1.rawValue }
                .map { $0.displayName }
                .joined(separator: ",")
            selectedFrequency = daysString
        } else {
            selectedFrequency = nil
        }
    }

    // ✅ Sauvegarder les jours d'entraînement
    private func saveTrainingDays() {
        Task {
            if var profile = profileService.currentProfile {
                // Convertir les jours sélectionnés en format sauvegardable
                let daysArray = Array(selectedDays).map { $0.rawValue }

                // Sauvegarder dans le profil (on peut utiliser un champ personnalisé ou sessionsPerWeek)
                // Pour l'instant, on sauvegarde dans selectedFrequency comme avant
                if isVariable {
                    profile.sessionsPerWeek = nil // Variable
                } else {
                    profile.sessionsPerWeek = selectedDays.count
                }

                try? await profileService.saveProfile(profile)

                // Aussi sauvegarder via OnboardingProgressService pour compatibilité
                if let frequency = selectedFrequency {
                    await OnboardingProgressService.shared.saveTrainingFrequency(frequency, to: profileService)
                }
            }
        }
    }

    // ✅ Charger les jours d'entraînement depuis le profil
    private func loadTrainingDays() {
        // Si selectedFrequency contient déjà des jours, les charger
        if let frequency = selectedFrequency {
            if frequency == "variable" {
                isVariable = true
            } else {
                // Parser les jours depuis la chaîne
                let days = frequency.components(separatedBy: ",")
                for dayString in days {
                    if let day = DayOfWeek.allCases.first(where: { $0.displayName == dayString.trimmingCharacters(in: .whitespaces) }) {
                        selectedDays.insert(day)
                    }
                }
            }
        }
    }
}

// MARK: - Day Picker Sheet

struct DayPickerSheet: View {
    @Binding var selectedDays: Set<DayOfWeek>
    @Binding var isVariable: Bool
    @Environment(\.dismiss) var dismiss
    @StateObject private var hapticManager = HapticManager.shared

    @State private var animationOffsets: [DayOfWeek: CGFloat] = [:]
    @State private var animationScales: [DayOfWeek: CGFloat] = [:]
    @State private var variableOffset: CGFloat = 30
    @State private var variableOpacity: Double = 0

    private let weekDays: [DayOfWeek] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]

    var body: some View {
        ZStack {
            // Fond noir
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Header avec bouton fermer
                HStack {
                    Button(action: {
                        hapticManager.impact(.light)
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                    }
                    .glassStyle()
                    .buttonBorderShape(.circle)

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                Spacer()

                // Titre
                Text("Sélectionner les jours")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 40)

                // Jours de la semaine
                VStack(spacing: 12) {
                    ForEach(weekDays, id: \.self) { day in
                        TrainingDayButton(
                            day: day,
                            isSelected: selectedDays.contains(day),
                            offset: animationOffsets[day] ?? 30,
                            scale: animationScales[day] ?? 0.9,
                            opacity: animationScales[day] == 1.0 ? 1.0 : 0.0
                        ) {
                            hapticManager.selection()

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedDays.contains(day) {
                                    selectedDays.remove(day)
                                } else {
                                    selectedDays.insert(day)
                                    // Si on sélectionne un jour, désélectionner "Ça dépend"
                                    if isVariable {
                                        isVariable = false
                                    }
                                }
                            }
                        }
                    }

                    // Option "Ça dépend"
                    Button(action: {
                        hapticManager.selection()

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVariable.toggle()

                            // Si on sélectionne "Ça dépend", désélectionner tous les jours
                            if isVariable {
                                selectedDays.removeAll()
                            }
                        }
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)

                            Text("Ça dépend")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)

                            Spacer()

                            if isVariable {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.3))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                    }
                    .frame(maxWidth: .infinity)
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .opacity(variableOpacity)
                    .offset(y: variableOffset)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)

                Spacer()
            }
        }
        .onAppear {
            // Animations d'entrée échelonnées
            for (index, day) in weekDays.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.05) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        animationOffsets[day] = 0
                        animationScales[day] = 1.0
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + Double(weekDays.count) * 0.05 + 0.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    variableOffset = 0
                    variableOpacity = 1.0
                }
            }
        }
    }
}

// MARK: - Day Button Component

struct TrainingDayButton: View {
    let day: DayOfWeek
    let isSelected: Bool
    var offset: CGFloat = 0
    var scale: CGFloat = 1.0
    var opacity: Double = 1.0
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Text(day.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity)
        .glassStyle()
        .buttonBorderShape(.roundedRectangle(radius: 20))
        .opacity(opacity)
        .offset(y: offset)
        .scaleEffect(scale)
    }
}
