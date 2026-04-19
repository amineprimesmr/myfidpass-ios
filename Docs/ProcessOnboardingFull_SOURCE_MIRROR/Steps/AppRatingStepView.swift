//
//  AppRatingStepView.swift
//
//  Page : Donnez-nous une note
//

import SwiftUI

struct AppRatingStepView: View {
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    // États pour les animations
    @State private var imageOpacity: Double = 0.0
    @State private var testimonialOpacity: Double = 0.0
    @State private var testimonialOffset: CGFloat = 50
    @State private var quoteOpacity: Double = 0.0
    @State private var quoteOffset: CGFloat = 30

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        GeometryReader { geometry in
            let screenHeight = UIScreen.main.bounds.height
            let screenWidth = UIScreen.main.bounds.width

            ZStack {
                // ✅ Image review1 en plein fond - couvre TOUT l'écran (haut et bas)
                // ✅ N'interfère pas avec le layout grâce à allowsHitTesting(false)
                Image("review1")
                    .resizable()
                    .scaledToFill()
                    .frame(width: screenWidth, height: screenHeight)
                    .clipped()
                    .ignoresSafeArea(.all, edges: .all)
                    .allowsHitTesting(false) // ✅ Ne bloque pas les interactions
                    .opacity(imageOpacity)
                    .animation(.easeIn(duration: 0.8), value: imageOpacity)

                // ✅ Dégradé noir progressif en bas - affiché directement
                VStack {
                    Spacer()

                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.black.opacity(0.3),
                            Color.black.opacity(0.6),
                            Color.black.opacity(0.85),
                            Color.black.opacity(0.95),
                            Color.black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.5)
                }
                .ignoresSafeArea(.all)
                .allowsHitTesting(false) // ✅ Ne bloque pas les interactions

                // ✅ Avis par-dessus le dégradé
                VStack {
                    Spacer()

                    VStack(spacing: 20) {
                        // Guillemets d'ouverture
                        Text("\"")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                            .opacity(quoteOpacity)
                            .offset(y: quoteOffset)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: quoteOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.6), value: quoteOffset)

                        // Texte de l'avis
                        Text("Surement la meilleure app de mon iPhone...")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 40)
                            .opacity(testimonialOpacity)
                            .offset(y: testimonialOffset)
                            .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.8), value: testimonialOpacity)
                            .animation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.8), value: testimonialOffset)

                        // Guillemets de fermeture
                        Text("\"")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                            .opacity(quoteOpacity)
                            .offset(y: -quoteOffset)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0), value: quoteOpacity)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0), value: quoteOffset)
                    }
                    .padding(.bottom, 100)
                }
                .ignoresSafeArea(.all)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .onAppear {
            // ✅ Démarrer les animations de manière séquentielle et fluide
            withAnimation(.easeIn(duration: 0.8)) {
                imageOpacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    quoteOpacity = 1.0
                    quoteOffset = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                    testimonialOpacity = 1.0
                    testimonialOffset = 0
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                    // Animation complète pour les guillemets de fermeture
                }
            }
        }
    }
}
