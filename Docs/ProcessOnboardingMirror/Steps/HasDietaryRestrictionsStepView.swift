//
//  HasDietaryRestrictionsStepView.swift
//
//  Vue pour demander si l'utilisateur a des restrictions alimentaires (Oui/Non)
//

import SwiftUI

struct HasDietaryRestrictionsStepView: View {
    @Binding var hasDietaryRestrictions: Bool?
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond nutri
                Image("nutri")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                // ✅ Overlay très réduit pour permettre à la lueur d'être visible
                Color.black.opacity(0.1)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Espace pour le titre en overlay (150pt)
                    Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                    // Espacement uniforme entre titre et réponses
                    Spacer()
                        .frame(height: OnboardingConstants.titleToContentSpacing)

                    // Le contenu est maintenant vide car les boutons sont en bas
                                Spacer()
                }

                // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
                VStack {
                    OnboardingTitleView("As-tu des", "restrictions alimentaires ?")
                        .padding(.top, OnboardingConstants.titleTopPaddingAfterPrimaryGoal) // Position ABSOLUE : 55pt depuis le haut (plus haut)
                    Spacer()
                }
            }
            .onAppear {
                if hasDietaryRestrictions != nil {
                    onValidationChanged?(true)
                }
}
}
}
}
