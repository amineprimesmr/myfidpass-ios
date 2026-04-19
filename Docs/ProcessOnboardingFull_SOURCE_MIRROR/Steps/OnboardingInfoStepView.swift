//
//  OnboardingInfoStepView.swift
//  Process
//
//  Page d'information avec texte et bouton continuer
//

import SwiftUI

struct OnboardingInfoStepView: View {
    var onComplete: (() -> Void)?

    @State private var showContent = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Fond noir
                Color.black
                    .ignoresSafeArea(.all)

                VStack(spacing: 40) {
                    Spacer()

                    // Contenu texte (à remplir plus tard)
                    VStack(spacing: 24) {
                        Text("Texte à définir")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .opacity(showContent ? 1.0 : 0.0)
                    }
                    .padding(.horizontal, 40)

                    Spacer()

                    // Bouton continuer
                    Button(action: {
                        HapticManager.shared.impact(.medium)
                        onComplete?()
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
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1.0 : 0.0)
                }
            }
        }
        .onAppear {
            // Animation d'apparition progressive
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
}
}
}
