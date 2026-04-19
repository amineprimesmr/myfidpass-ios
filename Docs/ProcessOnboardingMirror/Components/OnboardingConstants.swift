//
//  OnboardingConstants.swift
//  Process
//
//  Constantes pour l'espacement uniforme dans l'onboarding
//

import SwiftUI

struct OnboardingConstants {
    // Espacement uniforme entre le titre et les premières réponses
    static let titleToContentSpacing: CGFloat = 60

    // Hauteur réservée pour le titre (position originale)
    static let titleAreaHeight: CGFloat = 150

    // Position du titre depuis le haut de l'écran (position originale)
    static let titleTopPadding: CGFloat = 110

    // Position du titre depuis le haut pour les pages après primaryGoal (juste sous le bouton retour)
    static let titleTopPaddingAfterPrimaryGoal: CGFloat = 60  // Réduit de 90 à 60 pour remonter les titres
}
