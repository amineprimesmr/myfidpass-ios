//
//  FeaturesUnlockView.swift
//  Process
//
//  Page de déblocage progressif des fonctionnalités - "Des fonctionnalités débloquées chaque jour"
//

import SwiftUI

struct FeaturesUnlockView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @State private var selectedDay = 1
    @State private var circleRotation: Double = 0
    @State private var braceletScale: CGFloat = 0.5
    @State private var braceletOpacity: Double = 0
    @State private var circleOpacity: Double = 0
    @State private var titleOffset: CGFloat = 50
    @State private var titleOpacity: Double = 0
    @State private var descriptionOffset: CGFloat = 30
    @State private var descriptionOpacity: Double = 0
    @State private var finishButtonOpacity: Double = 0
    @State private var waveAnimation: Double = 0

    var onComplete: () -> Void
    var onBack: (() -> Void)?

    private let days = Array(1...7)
    private let dayFeatures: [Int: [String]] = [
        1: ["lock.open", "heart.fill", "dumbbell.fill", "figure.run", "moon.fill"],
        2: ["chart.line.uptrend.xyaxis", "bell.fill"],
        3: ["person.3.fill", "trophy.fill"],
        4: ["calendar", "target"],
        5: ["flame.fill", "bolt.fill"],
        6: ["brain.head.profile", "chart.bar.fill"],
        7: ["star.fill", "sparkles"]
    ]

    var body: some View {
        ZStack {
            // Fond noir avec dégradé subtil
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.1),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 80)

                // Cercle de progression avec segments
                ZStack {
                    // Cercle de fond
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 320, height: 320)

                    // Segments de jours (7 segments)
                    ForEach(days, id: \.self) { day in
                        segmentView(for: day)
                    }

                    // Bracelet PROCESS au centre avec animation
                    braceletView
                        .scaleEffect(braceletScale)
                        .opacity(braceletOpacity)

                    // Lignes d'ondes animées depuis le bracelet
                    waveLines
                }
                .frame(width: 320, height: 320)
                .opacity(circleOpacity)
                .rotationEffect(.degrees(circleRotation))

                Spacer()
                    .frame(height: 60)

                // Texte central dans le cercle (en overlay)
                Text("DES FONCTIONNALITÉS\nDÉBLOQUÉES CHAQUE JOUR")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .offset(y: 180)
                    .opacity(circleOpacity)

                Spacer()
                    .frame(height: 80)

                // Titre
                Text("À quoi s'attendre pour la suite")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .offset(y: titleOffset)
                    .opacity(titleOpacity)

                Spacer()
                    .frame(height: 32)

                // Description
                Text("Au cours de la semaine prochaine, PROCESS s'étalonnera en fonction de ton corps, découvrant ainsi tes schémas physiologiques. Porte ton Apple Watch en permanence pour obtenir des informations personnalisées et de nouvelles fonctionnalités tous les jours.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .padding(.horizontal, 40)
                    .offset(y: descriptionOffset)
                    .opacity(descriptionOpacity)

                Spacer()
            }

            // ✅ BOUTON RETOUR TEMPORAIRE EN MODE DEBUG
            #if DEBUG
            if let onBack = onBack {
                VStack {
                    HStack {
                        Button(action: {
                            hapticManager.impact(.light)
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 34, height: 34)
                        }
                        .glassStyle()
                        .buttonBorderShape(.circle)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }
                .zIndex(1000)
            }
            #endif

            // Bouton TERMINER en bas
            VStack {
                Spacer()
                HStack {
                    Text("TERMINER")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.leading, 40)

                    Spacer()

                    Button(action: {
                        Logger.debug("[FeaturesUnlockView] Bouton TERMINER cliqué", category: "Onboarding")
                        hapticManager.impact(.heavy)
                        hapticManager.notification(.success)
                        // ✅ CRITIQUE: Appeler onComplete de manière synchrone pour éviter les problèmes
                        onComplete()
                    }) {
                        ZStack {
                            Circle()
                                .fill(Color(red: 0.13, green: 0.98, blue: 0.47))
                                .frame(width: 70, height: 70)
                                .shadow(color: Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.5), radius: 15, x: 0, y: 0)

                            Image(systemName: "checkmark")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .buttonStyle(PlainButtonStyle()) // ✅ CRITIQUE: Utiliser PlainButtonStyle pour éviter les conflits
                    .padding(.trailing, 40)
                    .allowsHitTesting(true) // ✅ CRITIQUE: S'assurer que le bouton est cliquable
                    .zIndex(1000) // ✅ CRITIQUE: S'assurer que le bouton est au-dessus de tout
                }
                .padding(.bottom, 60)
                .opacity(finishButtonOpacity)
                .allowsHitTesting(finishButtonOpacity > 0) // ✅ CRITIQUE: Permettre les interactions seulement si visible
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Segment View

    private func segmentView(for day: Int) -> some View {
        let anglePerSegment = 360.0 / 7.0
        let startAngle = Double(day - 1) * anglePerSegment - 90
        let endAngle = Double(day) * anglePerSegment - 90
        let isActive = day <= selectedDay

        return ZStack {
            // Segment actif avec gradient
            if isActive {
                Path { path in
                    let center = CGPoint(x: 160, y: 160)
                    let radius: CGFloat = 150

                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                    path.closeSubpath()
                }
                .fill(
                    AngularGradient(
                        colors: [
                            Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.3),
                            Color(red: 0.65, green: 1.0, blue: 0.95).opacity(0.2)
                        ],
                        center: .center,
                        angle: .degrees(startAngle + anglePerSegment / 2)
                    )
                )
                .overlay(
                    Path { path in
                        let center = CGPoint(x: 160, y: 160)
                        let radius: CGFloat = 150

                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .stroke(Color(red: 0.13, green: 0.98, blue: 0.47), lineWidth: 3)
                )
            }

            // Numéro du jour
            let numberAngle = (startAngle + endAngle) / 2
            let numberRadius: CGFloat = 135
            let numberX = 160 + cos(numberAngle * .pi / 180) * numberRadius
            let numberY = 160 + sin(numberAngle * .pi / 180) * numberRadius

            Text("\(day)")
                .font(.system(size: 20, weight: isActive ? .bold : .medium, design: .rounded))
                .foregroundColor(isActive ? Color(red: 0.13, green: 0.98, blue: 0.47) : .white.opacity(0.4))
                .offset(x: numberX - 160, y: numberY - 160)

            // Icônes pour le jour 1
            if day == 1 && isActive {
                ForEach(Array((dayFeatures[1] ?? []).enumerated()), id: \.offset) { index, iconName in
                    let iconAngle = startAngle + (Double(index + 1) / Double((dayFeatures[1] ?? []).count + 1)) * anglePerSegment
                    let iconRadius: CGFloat = 115
                    let iconX = 160 + cos(iconAngle * .pi / 180) * iconRadius
                    let iconY = 160 + sin(iconAngle * .pi / 180) * iconRadius

                    Image(systemName: iconName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.13, green: 0.98, blue: 0.47))
                        .offset(x: iconX - 160, y: iconY - 160)
                }
            }
        }
    }

    // MARK: - Bracelet View

    private var braceletView: some View {
        ZStack {
            // Bracelet (style Apple Watch)
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.2, blue: 0.2),
                            Color(red: 0.3, green: 0.3, blue: 0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                )

            // Face du bracelet
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .frame(width: 60, height: 60)
                .overlay(
                    Text("P")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.13, green: 0.98, blue: 0.47),
                                    Color(red: 0.65, green: 1.0, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }

    // MARK: - Wave Lines

    private var waveLines: some View {
        ZStack {
            // Ligne 1
            Path { path in
                let center = CGPoint(x: 160, y: 160)
                path.move(to: center)
                path.addCurve(
                    to: CGPoint(x: 220, y: 120),
                    control1: CGPoint(x: 180, y: 140),
                    control2: CGPoint(x: 200, y: 130)
                )
            }
            .stroke(
                Color(red: 0.13, green: 0.98, blue: 0.47).opacity(0.4),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
            )

            // Ligne 2
            Path { path in
                let center = CGPoint(x: 160, y: 160)
                path.move(to: center)
                path.addCurve(
                    to: CGPoint(x: 100, y: 200),
                    control1: CGPoint(x: 140, y: 180),
                    control2: CGPoint(x: 120, y: 190)
                )
            }
            .stroke(
                Color(red: 0.65, green: 1.0, blue: 0.95).opacity(0.4),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
            )
            .opacity(sin(waveAnimation) * 0.5 + 0.5)
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        // Animation du cercle
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            circleOpacity = 1.0
        }

        // Animation du bracelet
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.4)) {
            braceletScale = 1.0
            braceletOpacity = 1.0
        }

        // Animation rotation douce
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            circleRotation = 360
        }

        // Animation des ondes
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            waveAnimation = .pi * 2
        }

        // Animation du titre
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            titleOffset = 0
            titleOpacity = 1.0
        }

        // Animation de la description
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
            descriptionOffset = 0
            descriptionOpacity = 1.0
        }

        // Animation du bouton - ✅ CRITIQUE: S'assurer que le bouton devient visible et cliquable
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(1.0)) {
            finishButtonOpacity = 1.0
        }

        // ✅ CRITIQUE: Forcer l'opacité à 1.0 immédiatement pour garantir la visibilité (même si l'animation échoue)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            finishButtonOpacity = 1.0
            Logger.debug("[FeaturesUnlockView] Opacité du bouton forcée à 1.0", category: "Onboarding")
        }
}
}
