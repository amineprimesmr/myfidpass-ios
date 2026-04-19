//
//  DeadlineSelectionStepView.swift
//
//  Vue pour sélectionner une deadline d'objectif
//

import SwiftUI

struct DeadlineSelectionStepView: View {
    @Binding var deadline: GoalDeadline
    var selectedSports: Set<String>  // ✨ Sports sélectionnés pour personnalisation
    var onValidationChanged: ((Bool) -> Void)?
    var onComplete: (() -> Void)? // ✅ Callback pour naviguer directement vers la page suivante

    @State private var hasEvent: Bool? // ✅ État pour savoir si l'utilisateur a un événement
    @State private var personalizedTitle: String = "As-tu une deadline en tête ?"
    @State private var eventButtonText: String = "Oui, j'ai un événement"
    @State private var buttonScale: CGFloat = 1.0

    private let suggestionService = DeadlineSuggestionService.shared

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Espace pour le titre en overlay
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et réponses
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // ✅ Deux boutons simples : Oui / Non
                VStack(spacing: 20) {
                    // Bouton "Oui, j'ai un événement"
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            buttonScale = 0.95
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                buttonScale = 1.0
                            }
                        }

                        hasEvent = true
                        // ✅ Définir un type de deadline temporaire pour que la navigation fonctionne
                        let sportsWithEvents = selectedSports.filter { suggestionService.hasConcreteEvents(sport: $0) }
                        if let firstSport = sportsWithEvents.first {
                            let sportLower = firstSport.lowercased()
                            if sportLower.contains("boxe") || sportLower.contains("🥊") ||
                               sportLower.contains("martial") || sportLower.contains("mma") || sportLower.contains("🥋") {
                                deadline = GoalDeadline(type: .combat)
                            } else if sportLower.contains("course") || sportLower.contains("🏃") {
                                deadline = GoalDeadline(type: .runningRace)
                            } else if sportLower.contains("cyclisme") || sportLower.contains("vélo") || sportLower.contains("🚴") {
                                deadline = GoalDeadline(type: .cyclingRace)
                            } else if sportLower.contains("natation") || sportLower.contains("🏊") {
                                deadline = GoalDeadline(type: .swimmingCompetition)
                            } else {
                                deadline = GoalDeadline(type: .personalEvent)
                            }
                        } else {
                            deadline = GoalDeadline(type: .personalEvent)
                        }
                        onValidationChanged?(true)
                        // ✅ Naviguer directement vers la page suivante (détails de l'événement)
                        onComplete?()
                    }) {
                        HStack(spacing: 12) {
                            Text(eventButtonText)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .scaleEffect(buttonScale)
                    .opacity(hasEvent == true ? 1.0 : 0.8)

                    // Bouton "Non, pas de deadline"
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        hasEvent = false
                        deadline = GoalDeadline(type: .noDeadline)
                        onValidationChanged?(true)
                        // ✅ Naviguer directement vers la page suivante
                        onComplete?()
                    }) {
                        HStack(spacing: 12) {
                            Text("Non, pas de deadline")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 20))
                    .opacity(hasEvent == false ? 1.0 : 0.8)
                }
                .padding(.horizontal, 40)

                Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView(personalizedTitle)
                    .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal)
                Spacer()
            }
        }
        .onAppear {
            // ✨ Personnaliser le titre et le texte du bouton selon les sports
            personalizedTitle = suggestionService.getPersonalizedTitle(for: selectedSports)

            // ✨ Personnaliser le texte du bouton selon le sport
            let sportsWithEvents = selectedSports.filter { suggestionService.hasConcreteEvents(sport: $0) }
            if let firstSport = sportsWithEvents.first {
                let sportLower = firstSport.lowercased()
                if sportLower.contains("boxe") || sportLower.contains("🥊") ||
                   sportLower.contains("martial") || sportLower.contains("mma") || sportLower.contains("🥋") {
                    eventButtonText = "Oui, j'ai un combat"
                } else if sportLower.contains("course") || sportLower.contains("🏃") {
                    eventButtonText = "Oui, j'ai une course"
                } else if sportLower.contains("cyclisme") || sportLower.contains("vélo") || sportLower.contains("🚴") {
                    eventButtonText = "Oui, j'ai une compétition"
                } else if sportLower.contains("natation") || sportLower.contains("🏊") {
                    eventButtonText = "Oui, j'ai une compétition"
                } else {
                    eventButtonText = "Oui, j'ai un événement"
                }
            }

            // Initialiser avec la deadline existante si disponible
            if deadline.type != .noDeadline {
                hasEvent = true
            }
        }
    }

}
