//
//  OnboardingStepContainer.swift
//  Process
//
//  Container qui positionne TOUJOURS le titre à la même hauteur absolue
//  depuis le haut de l'écran, indépendamment de la structure du contenu
//

import SwiftUI

struct OnboardingStepContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let subtitle2: String?
    let content: Content

    @State private var titleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 20
    @State private var contentOpacity: Double = 0
    @State private var contentOffset: CGFloat = 30

    init(
        title: String,
        subtitle: String? = nil,
        subtitle2: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.subtitle2 = subtitle2
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Contenu de la page avec animation d'entrée
            VStack(spacing: 0) {
                // Espace pour le titre (150pt pour laisser place au titre)
                Spacer()
                    .frame(height: 150)

                // Contenu de la page avec animation fluide
                content
                    .opacity(contentOpacity)
                    .offset(y: contentOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran avec animation
            VStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(white: 0.98))
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(white: 0.98))
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                    }

                    if let subtitle2 = subtitle2 {
                        Text(subtitle2)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(white: 0.98))
                            .opacity(titleOpacity)
                            .offset(y: titleOffset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .padding(.top, 100) // ✅ Position ABSOLUE : 100pt depuis le haut de l'écran

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false) // Permet de cliquer à travers le titre
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // ✅ Animation ultra fluide d'entrée avec effet cascade
            // Titre apparaît en premier avec animation douce
            withAnimation(.onboardingEntrance) {
                titleOpacity = 1.0
                titleOffset = 0
            }

            // Contenu apparaît ensuite avec un léger délai pour effet cascade
            withAnimation(.onboardingEntrance.delay(0.12)) {
                contentOpacity = 1.0
                contentOffset = 0
            }
        }
        .onDisappear {
            // Réinitialiser les animations pour la prochaine apparition
            titleOpacity = 0
            titleOffset = 20
            contentOpacity = 0
            contentOffset = 30
        }
}
}
