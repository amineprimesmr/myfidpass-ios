//
//  EventDetailsStepView.swift
//
//  Page personnalisée pour saisir les détails de l'événement selon l'activité
//

import SwiftUI

struct EventDetailsStepView: View {
    @Binding var deadline: GoalDeadline
    var selectedSports: Set<String>  // ✨ Sports sélectionnés pour personnalisation
    var onValidationChanged: ((Bool) -> Void)?

    @State private var selectedDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
    @State private var selectedDetail: DeadlineDetail?
    @State private var distance: Double = 10.0 // Pour les courses (en km)
    @State private var combatType: String? // Pour les combats
    @State private var combatWeight: String? // Pour les combats (poids)

    private let minDate = Date()
    private let maxDate = Calendar.current.date(byAdding: .year, value: 2, to: Date()) ?? Date()
    private let suggestionService = DeadlineSuggestionService.shared

    // ✅ Déterminer le type d'événement selon les sports
    private var eventType: DeadlineType {
        let sportsWithEvents = selectedSports.filter { suggestionService.hasConcreteEvents(sport: $0) }
        guard let firstSport = sportsWithEvents.first else { return .personalEvent }

        let sportLower = firstSport.lowercased()
        if sportLower.contains("course") || sportLower.contains("🏃") {
            return .runningRace
        } else if sportLower.contains("boxe") || sportLower.contains("🥊") ||
                  sportLower.contains("martial") || sportLower.contains("mma") || sportLower.contains("🥋") {
            return .combat
        } else if sportLower.contains("cyclisme") || sportLower.contains("vélo") || sportLower.contains("🚴") {
            return .cyclingRace
        } else if sportLower.contains("natation") || sportLower.contains("🏊") {
            return .swimmingCompetition
        }
        return .personalEvent
    }

    // ✅ Titre personnalisé selon l'activité
    private var personalizedTitle: String {
        switch eventType {
        case .combat:
            return "Détails de ton combat"
        case .runningRace:
            return "Détails de ta course"
        case .cyclingRace:
            return "Détails de ta compétition"
        case .swimmingCompetition:
            return "Détails de ta compétition"
        default:
            return "Détails de ton événement"
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ✅ Contenu personnalisé selon le type d'événement
                        switch eventType {
                        case .combat:
                            combatDetailsView
                        case .runningRace:
                            runningRaceDetailsView
                        case .cyclingRace:
                            cyclingRaceDetailsView
                        case .swimmingCompetition:
                            swimmingCompetitionDetailsView
                        default:
                            EmptyView()
                        }
                    }
                    .padding(.bottom, 100)
                }
            }

            // ✅ Titre en OVERLAY
            VStack {
                OnboardingTitleView(personalizedTitle)
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
        .onAppear {
            // Initialiser avec la deadline existante si disponible
            if let date = deadline.date {
                selectedDate = date
            }
            if let detail = deadline.detail {
                selectedDetail = detail
            }
            updateDeadline()
            onValidationChanged?(true)
        }
    }

    // MARK: - Vues personnalisées par type d'événement

    // ✅ Vue pour les combats (Boxe, MMA, etc.)
    private var combatDetailsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Type de combat
            VStack(alignment: .leading, spacing: 12) {
                Text("Type de combat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                let combatDetails = suggestionService.getAvailableDetails(for: .combat)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(combatDetails) { detail in
                            Button(action: {
                                HapticManager.shared.selection()
                                selectedDetail = detail
                                combatType = detail.rawValue
                                updateDeadline()
                            }) {
                                Text(detail.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDetail == detail ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedDetail == detail ?
                                            Color.purple.opacity(0.3) :
                                            Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedDetail == detail ?
                                                Color.purple.opacity(0.5) :
                                                Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                }
            }

            // Poids de combat (optionnel)
            VStack(alignment: .leading, spacing: 12) {
                Text("Catégorie de poids (optionnel)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                TextField("Ex: Poids moyen, Poids lourd...", text: Binding(
                    get: { combatWeight ?? "" },
                    set: { combatWeight = $0.isEmpty ? nil : $0 }
                ))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .onChange(of: combatWeight) { _, _ in
                    updateDeadline()
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // ✅ Vue pour les courses à pied - Style Liquid Glass comme l'image
    private var runningRaceDetailsView: some View {
        VStack(alignment: .leading, spacing: 24) {
            // ✅ Section Distance de la course
            VStack(alignment: .leading, spacing: 16) {
                Text("Distance de la course")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    // ✅ Bouton 10K
                    Button(action: {
                        HapticManager.shared.selection()
                        selectedDetail = .tenKm
                        distance = 10.0
                        updateDeadline()
                    }) {
                        HStack(spacing: 16) {
                            // Badge avec 10 et KM
                            VStack(spacing: 2) {
                                Text("10")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("KM")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("10K")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedDetail == .tenKm ? Color.white : Color.clear,
                                lineWidth: 1
                            )
                    )

                    // ✅ Bouton Semi-marathon
                    Button(action: {
                        HapticManager.shared.selection()
                        selectedDetail = .halfMarathon
                        distance = 21.0
                        updateDeadline()
                    }) {
                        HStack(spacing: 16) {
                            // Badge avec 21 et KM
                            VStack(spacing: 2) {
                                Text("21")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("KM")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Semi-marathon")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedDetail == .halfMarathon ? Color.white : Color.clear,
                                lineWidth: 1
                            )
                    )

                    // ✅ Bouton Marathon
                    Button(action: {
                        HapticManager.shared.selection()
                        selectedDetail = .marathon
                        distance = 42.0
                        updateDeadline()
                    }) {
                        HStack(spacing: 16) {
                            // Badge avec 42 et KM
                            VStack(spacing: 2) {
                                Text("42")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("KM")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(width: 50, height: 50)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Marathon")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                selectedDetail == .marathon ? Color.white : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
            }

            // ✅ Section Date de la course
            VStack(alignment: .leading, spacing: 16) {
                Text("Date de la course")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Button(action: {
                    // Ouvrir le DatePicker
                    showDatePicker = true
                }) {
                    HStack {
                        Text(formatDate(selectedDate))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .sheet(isPresented: $showDatePicker) {
                    NavigationView {
                        VStack {
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                in: minDate...maxDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.wheel)
                            .colorScheme(.dark)
                            .accentColor(.white)
                            .onChange(of: selectedDate) { _, _ in
                                updateDeadline()
                            }

                            Button("Valider") {
                                showDatePicker = false
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(16)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 40)
                        }
                        .background(Color.black)
                        .navigationTitle("Date de la course")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Fermer") {
                                    showDatePicker = false
                                }
                                .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    @State private var showDatePicker = false

    // ✅ Formater la date comme dans l'image : "2026 févr. 17"
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy MMM d"
        let formatted = formatter.string(from: date)
        // Ajouter un point après le mois abrégé (sauf pour mai et août)
        let monthsWithPoint = ["janv", "févr", "mars", "avr", "juin", "juil", "sept", "oct", "nov", "déc"]
        for month in monthsWithPoint {
            if formatted.contains(month) {
                return formatted.replacingOccurrences(of: month, with: "\(month).")
            }
        }
        return formatted
    }

    // ✅ Vue pour les compétitions de vélo
    private var cyclingRaceDetailsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Type de compétition
            VStack(alignment: .leading, spacing: 12) {
                Text("Type de compétition")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                let cyclingDetails = suggestionService.getAvailableDetails(for: .cyclingRace)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(cyclingDetails) { detail in
                            Button(action: {
                                HapticManager.shared.selection()
                                selectedDetail = detail
                                updateDeadline()
                            }) {
                                Text(detail.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDetail == detail ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedDetail == detail ?
                                            Color.purple.opacity(0.3) :
                                            Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedDetail == detail ?
                                                Color.purple.opacity(0.5) :
                                                Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // ✅ Vue pour les compétitions de natation
    private var swimmingCompetitionDetailsView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Type de compétition
            VStack(alignment: .leading, spacing: 12) {
                Text("Type de compétition")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                let swimmingDetails = suggestionService.getAvailableDetails(for: .swimmingCompetition)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(swimmingDetails) { detail in
                            Button(action: {
                                HapticManager.shared.selection()
                                selectedDetail = detail
                                updateDeadline()
                            }) {
                                Text(detail.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedDetail == detail ? .white : .white.opacity(0.7))
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                    .background(
                                        selectedDetail == detail ?
                                            Color.purple.opacity(0.3) :
                                            Color.white.opacity(0.1)
                                    )
                                    .cornerRadius(16)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(
                                                selectedDetail == detail ?
                                                Color.purple.opacity(0.5) :
                                                Color.clear,
                                                lineWidth: 2
                                            )
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Helpers

    private func updateDeadline() {
        var eventName: String?

        if let detail = selectedDetail {
            eventName = detail.rawValue
            if let weight = combatWeight, !weight.isEmpty {
                eventName = "\(detail.rawValue) - \(weight)"
            }
        } else if eventType == .runningRace {
            eventName = "Course de \(Int(distance)) km"
        }

        deadline = GoalDeadline(
            type: eventType,
            date: selectedDate,
            eventName: eventName,
            detail: selectedDetail
        )

        // Valider si les champs requis sont remplis
        let isValid = selectedDate >= minDate &&
                     (eventType == .runningRace ? distance > 0 : selectedDetail != nil)
        onValidationChanged?(isValid)
    }
}
