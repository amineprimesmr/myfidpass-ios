//
//  ShareForFreeAccessView.swift
//  Process
//
//  Page de partage pour accès gratuit
//

import SwiftUI

struct ShareForFreeAccessView: View {
    @Environment(\.dismiss) private var dismiss
    let onFreeAccessGranted: () -> Void

    @State private var shareCount = 0
    @State private var showShareSheet = false
    @State private var shareText = "Découvre Process, l'app qui révolutionne ta santé ! 🚀"

    var body: some View {
        ZStack {
            // Background avec gradient animé
            AnimatedGradientBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 40) {
                    // Header avec bouton fermer
                    HStack {
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.8))
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 44, height: 44)
                                )
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // Contenu principal
                    VStack(spacing: 30) {
                        // Icône principale
                        ZStack {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            Color.green.opacity(0.3),
                                            Color.green.opacity(0.1)
                                        ],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 100
                                    )
                                )
                                .frame(width: 200, height: 200)
                                .blur(radius: 30)

                            Image(systemName: "gift.fill")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .padding(.top, 20)

                        // Titre
                        VStack(spacing: 12) {
                            Text("Accède gratuitement à")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("ton programme personnalisé")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                        // Description
                        VStack(spacing: 16) {
                            Text("Partage Process avec 3 personnes et obtiens")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)

                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.yellow)

                                Text("7 jours de plan personnalisé gratuit")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                        .padding(.horizontal, 40)

                        // Compteur de partages
                        VStack(spacing: 16) {
                            Text("Partages effectués")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))

                            ZStack {
                                // Cercle de progression
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                                    .frame(width: 120, height: 120)

                                Circle()
                                    .trim(from: 0, to: CGFloat(shareCount) / 3.0)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.green, .mint],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                                    )
                                    .frame(width: 120, height: 120)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: shareCount)

                                VStack(spacing: 4) {
                                    Text("\(shareCount)")
                                        .font(.system(size: 36, weight: .black))
                                        .foregroundColor(.white)

                                    Text("/ 3")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }

                            if shareCount < 3 {
                                Text("\(3 - shareCount) partage\(3 - shareCount > 1 ? "s" : "") restant\(3 - shareCount > 1 ? "s" : "")")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.green)

                                    Text("Objectif atteint !")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.vertical, 30)
                        .padding(.horizontal, 40)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 40)

                        // Bouton de partage
                        if shareCount < 3 {
                            Button(action: {
                                HapticManager.shared.impact(.medium)
                                shareApp()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 20, weight: .bold))

                                    Text("Partager l'application")
                                        .font(.system(size: 20, weight: .black))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: .green.opacity(0.5), radius: 15, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 40)
                        } else {
                            // Bouton pour activer l'accès gratuit
                            Button(action: {
                                HapticManager.shared.notification(.success)
                                onFreeAccessGranted()
                                dismiss()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20, weight: .bold))

                                    Text("Activer mon accès gratuit")
                                        .font(.system(size: 20, weight: .black))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 60)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: .blue.opacity(0.5), radius: 15, x: 0, y: 5)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 40)
                            .transition(.scale.combined(with: .opacity))
                        }

                        // Informations supplémentaires
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))

                                Text("Accès valable 7 jours")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }

                            HStack(spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white.opacity(0.6))

                                Text("Partage via n'importe quelle app")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.top, 20)
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }

    private func shareApp() {
        // Simuler le partage (dans une vraie app, on utiliserait UIActivityViewController)
        // Pour l'instant, on incrémente le compteur directement
        // Dans une vraie implémentation, il faudrait vérifier que le partage a bien été effectué

        showShareSheet = true

        // Simuler l'incrémentation après le partage
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                shareCount += 1
            }

            if shareCount == 3 {
                HapticManager.shared.notification(.success)
            } else {
                HapticManager.shared.impact(.medium)
            }
}
}
}
