//
//  OptimalSleepWindowView.swift
//  Process
//
//  Vue pour afficher la fenêtre de sommeil optimale
//

import SwiftUI

struct OptimalSleepWindowView: View {
    let sleepWindow: OptimalSleepWindow
    var onComplete: () -> Void

    @State private var showAnimation = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Image de fond Sleep
                Image("Sleep")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                // Overlay sombre pour améliorer la lisibilité
                Color.black.opacity(0.5)
                    .ignoresSafeArea(.all)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("🌙")
                                    .font(.system(size: 40))
                                Spacer()
                            }

                            Text("Ta fenêtre de sommeil")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("optimale")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("L'heure idéale pour te coucher et te réveiller pour maximiser ta récupération ⏰")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)

                        VStack(spacing: 30) {
                            // Horloge visuelle
                            ZStack {
                                // Cercle de fond
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                                    .frame(width: 280, height: 280)

                                // Arc de sommeil
                                Circle()
                                    .trim(from: 0, to: showAnimation ? 0.75 : 0)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 280, height: 280)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 1.0, dampingFraction: 0.7), value: showAnimation)

                                // Contenu au centre
                                VStack(spacing: 8) {
                                    Text("\(Int(sleepWindow.sleepDuration / 3600))h")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(.white)

                                    Text("de sommeil")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .padding(.vertical, 20)

                            // Heures recommandées
                            HStack(spacing: 40) {
                                // Heure de coucher
                                VStack(spacing: 12) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.blue)

                                    Text("Coucher")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))

                                    Text(sleepWindow.bedtimeString)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.blue.opacity(0.15))
                                )

                                // Heure de réveil
                                VStack(spacing: 12) {
                                    Image(systemName: "sunrise.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.orange)

                                    Text("Réveil")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))

                                    Text(sleepWindow.wakeTimeString)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.orange.opacity(0.15))
                                )
                            }
                            .padding(.horizontal, 40)

                            // Explication
                            Text(sleepWindow.explanation)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .padding(.vertical, 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.05))
                                )
                                .padding(.horizontal, 40)
                        }

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showAnimation = true
            }
}
}
}
