//
//  CalculatedSleepNeedView.swift
//  Process
//
//  Vue pour afficher le besoin de sommeil calculé
//

import SwiftUI

struct CalculatedSleepNeedView: View {
    let sleepNeed: CalculatedSleepNeed
    var onComplete: () -> Void

    @State private var showDetails = false

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
                                Text("💤")
                                    .font(.system(size: 40))
                                Spacer()
                            }

                            Text("Ton besoin de sommeil")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("personnalisé")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("Basé sur ton profil et tes réponses, voici ce dont tu as vraiment besoin ✨")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)

                        VStack(spacing: 30) {
                            // Carte principale : Heures optimales
                            VStack(spacing: 16) {
                                Text("\(String(format: "%.1f", sleepNeed.optimalHours))h")
                                    .font(.system(size: 72, weight: .bold))
                                    .foregroundColor(.blue)

                                Text("de sommeil optimal")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))

                                Text(sleepNeed.recommendation)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 40)
                            .onTapGesture {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showDetails.toggle()
                                }
                            }

                            // Détails (expandable)
                            if showDetails {
                                VStack(spacing: 16) {
                                    // Minimum
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Minimum")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))

                                            Text("\(String(format: "%.1f", sleepNeed.minimumHours))h")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.orange)
                                        }

                                        Spacer()

                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.orange.opacity(0.1))
                                    )

                                    // Optimal
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Optimal")
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundColor(.white.opacity(0.7))

                                            Text("\(String(format: "%.1f", sleepNeed.optimalHours))h")
                                                .font(.system(size: 24, weight: .bold))
                                                .foregroundColor(.blue)
                                        }

                                        Spacer()

                                        Image(systemName: "star.fill")
                                            .font(.system(size: 28))
                                            .foregroundColor(.blue)
                                    }
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue.opacity(0.1))
                                    )

                                    // Déficit (si applicable)
                                    if let deficit = sleepNeed.deficit, deficit > 0 {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Déficit actuel")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white.opacity(0.7))

                                                Text("\(String(format: "%.1f", deficit))h")
                                                    .font(.system(size: 24, weight: .bold))
                                                    .foregroundColor(.red)
                                            }

                                            Spacer()

                                            Image(systemName: "arrow.down.circle.fill")
                                                .font(.system(size: 28))
                                                .foregroundColor(.red)
                                        }
                                        .padding(20)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(Color.red.opacity(0.1))
                                        )
                                    }
                                }
                                .padding(.horizontal, 40)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }

                        // Espace pour le bouton en bas
                        Spacer()
                            .frame(height: 100)
                    }
                }
            }
        }
        .onAppear {
            // Page d'information - pas de passage automatique
        }
}
}
