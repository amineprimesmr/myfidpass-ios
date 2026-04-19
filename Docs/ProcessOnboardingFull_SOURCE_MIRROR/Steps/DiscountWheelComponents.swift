//
//  DiscountWheelComponents.swift
//  Process
//
//  Sections roulette, formes, overlays, fond animé (extrait de DiscountWheelView).
//

import SwiftUI

// MARK: - Structures de données

struct WheelSection: Identifiable {
    let id = UUID()
    let value: Int // Pourcentage (négatif pour cadeau)
    let color: Color
    let icon: String
    var isGift: Bool = false
    var isDark: Bool = false // Pour déterminer la couleur du texte
}

// MARK: - Vue de la roulette

struct WheelView: View {
    let sections: [WheelSection]
    let rotationAngle: Double
    let isSpinning: Bool

    private let sectionAngle: Double = 360.0 / 6.0 // 60° par section

    var body: some View {
        ZStack {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                WheelSectionView(
                    section: section,
                    startAngle: Double(index) * sectionAngle - 90, // Commencer à -90° pour que la première section commence en haut, puis décaler de moitié de section
                    angle: sectionAngle
                )
            }
        }
        .rotationEffect(.degrees(rotationAngle))
    }
}

struct WheelSectionView: View {
    let section: WheelSection
    let startAngle: Double
    let angle: Double

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2
            let sectionCenterAngle = startAngle + angle / 2
            let textColor = section.isDark ? Color.white : Color.black
            let centerAngleRad = sectionCenterAngle * .pi / 180.0
            let offsetDistance = radius * 0.65 // Plus loin du centre, mieux au milieu de la catégorie

            // Créer la forme de la section
            let pieSlice = WheelPieSlice(
                    startAngle: .degrees(startAngle),
                    endAngle: .degrees(startAngle + angle),
                    center: center,
                    radius: radius
                )

            ZStack {
                // Ombre de la section pour effet 3D
                pieSlice
                    .fill(Color.black.opacity(0.3))
                    .offset(x: 2, y: 2)
                    .blur(radius: 3)

                // Section principale avec gradient pour effet de profondeur
                pieSlice
                    .fill(
                        LinearGradient(
                            colors: [
                                section.color.opacity(1.0),
                                section.color.opacity(0.85),
                                section.color.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        // Bordure avec effet de relief
                        pieSlice
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.4),
                                        Color.black.opacity(0.3),
                                        Color.white.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: .black.opacity(0.4), radius: 4, x: 1, y: 2)
                    .shadow(color: .white.opacity(0.1), radius: 2, x: -1, y: -1)

                // Contenu de la section avec effet de profondeur
                sectionContentView(
                    section: section,
                    textColor: textColor,
                    sectionCenterAngle: sectionCenterAngle,
                    center: center,
                    centerAngleRad: centerAngleRad,
                    offsetDistance: offsetDistance
                )
            }
        }
    }

    @ViewBuilder
    private func sectionContentView(
        section: WheelSection,
        textColor: Color,
        sectionCenterAngle: Double,
        center: CGPoint,
        centerAngleRad: Double,
        offsetDistance: CGFloat
    ) -> some View {
        let positionX = center.x + offsetDistance * cos(centerAngleRad)
        let positionY = center.y + offsetDistance * sin(centerAngleRad)

        if section.isGift {
            // Pour le cadeau : icône avec effets 3D
            ZStack {
                // Ombre de l'icône
                Image(systemName: section.icon)
                    .font(.system(size: 45, weight: .bold))
                    .foregroundColor(Color.black.opacity(0.3))
                    .rotationEffect(.degrees(sectionCenterAngle))
                    .position(x: positionX + 2, y: positionY + 2)
                    .blur(radius: 2)

                // Icône principale avec gradient
                Image(systemName: section.icon)
                    .font(.system(size: 45, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                textColor,
                                textColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(sectionCenterAngle))
                    .position(x: positionX, y: positionY)
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 1, y: 1)
            }
        } else if section.value == -35 {
            // Si -35%, afficher un cadeau au lieu du texte
            Image(systemName: "gift.fill")
                .font(.system(size: 45, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            textColor,
                            textColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(sectionCenterAngle))
                .position(x: positionX, y: positionY)
        } else {
            // Pour les autres sections : texte avec effets 3D
            let text: String = {
                if section.value == -999 {
                    return "perdu"
                } else if section.value == 0 {
                    return "0%"
                } else {
                    return "\(section.value)%"
                }
            }()

            let fontSize: CGFloat = section.value == -999 ? 20 : 22
            let tracking: CGFloat = section.value == -999 ? 0 : -2

            // Texte principal sans ombres noires pour meilleure lisibilité
                Text(text)
                    .font(.system(size: fontSize, weight: .black))
                    .tracking(tracking)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                textColor,
                                textColor.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .rotationEffect(.degrees(sectionCenterAngle))
                    .position(x: positionX, y: positionY)
        }
    }
}

// MARK: - Forme de section de tarte

struct WheelPieSlice: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let center: CGPoint
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Ligne vers le centre
        path.move(to: center)

        // Arc de cercle
        let startRad = startAngle.radians
        let endRad = endAngle.radians

        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // Retour au centre
        path.closeSubpath()

        return path
    }
}

// MARK: - Forme triangle pour le pointeur

struct WheelPointer: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Triangle inversé : sommet en bas, base en haut (pointe vers le bas)
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY)) // Sommet en bas
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // Coin gauche en haut
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // Coin droit en haut
        path.closeSubpath()
        return path
    }
}

// MARK: - Overlay de résultat

struct ResultOverlay: View {
    let discount: Int
    let isGift: Bool
    let onDismiss: () -> Void
    let canSpinAgain: Bool

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    if !canSpinAgain {
                        onDismiss()
                    }
                }

            VStack(spacing: 30) {
                // Icône animée
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    isGift ? Color(red: 0.85, green: 0.78, blue: 0.98) : Color(red: 0.75, green: 0.68, blue: 0.95),
                                    (isGift ? Color(red: 0.85, green: 0.78, blue: 0.98) : Color(red: 0.75, green: 0.68, blue: 0.95)).opacity(0.3)
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .blur(radius: 20)

                    Image(systemName: isGift ? "gift.fill" : "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.white)
                        .scaleEffect(scale)
                }

                // Texte
                VStack(spacing: 12) {
                    Text(isGift ? "🎁 Cadeau spécial !" : "🎉 Félicitations !")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)

                    if isGift {
                        Text("Cadeau spécial !")
                            .font(.system(size: 48, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.78, blue: 0.98),
                                        Color(red: 0.80, green: 0.73, blue: 0.97)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else if discount == 0 {
                        Text("0% de réduction")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(Color(red: 0.75, green: 0.68, blue: 0.95))
                    } else {
                        Text("\(discount)% de réduction")
                            .font(.system(size: 36, weight: .black))
                            .foregroundColor(Color(red: 0.75, green: 0.68, blue: 0.95))
                    }

                    Text(isGift ? "Tu as gagné la réduction maximale !" : "Appliquée automatiquement")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }

                // Boutons
                VStack(spacing: 12) {
                    if canSpinAgain {
                        Button(action: {
                            HapticManager.shared.impact(.medium)
                            onDismiss()
                        }) {
                            Text("Réessayer")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                        .glassStyle()
                        .buttonBorderShape(.roundedRectangle(radius: 28))
                        .controlSize(.large)
                        .environment(\.colorScheme, .light)
                        .padding(.horizontal, 40)
                    }

                    Button(action: {
                        HapticManager.shared.impact(.light)
                        onDismiss()
                    }) {
                        Text(isGift || !canSpinAgain ? "Continuer" : "Garder cette réduction")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 28)
                                    .fill(Color.white.opacity(0.2))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 28)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 40)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isGift ? Color(red: 0.85, green: 0.78, blue: 0.98) : Color(red: 0.75, green: 0.68, blue: 0.95),
                                        (isGift ? Color(red: 0.85, green: 0.78, blue: 0.98) : Color(red: 0.75, green: 0.68, blue: 0.95)).opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .padding(.horizontal, 30)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

// MARK: - Background animé

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.1, green: 0.1, blue: 0.2),
                Color(red: 0.15, green: 0.1, blue: 0.25),
                Color(red: 0.2, green: 0.15, blue: 0.3)
            ],
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Retry Popup View

struct RetryPopupView: View {
    let onDismiss: () -> Void
    let onRetry: () -> Void

    @State private var offset: CGFloat = 200

    var body: some View {
        VStack {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Dommage...")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Retente ta chance !")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }

                // Bouton Réessayer
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        offset = 200
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onRetry()
                    }
                }) {
                    Text("Réessayer")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64) // Plus épais, comme le bouton "Commencer pour 0,00€"
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.95, green: 0.92, blue: 0.98), // Violet très clair, presque blanc (comme "Commencer pour 0,00€")
                            Color(red: 0.92, green: 0.95, blue: 0.98)  // Bleu très clair, presque blanc (comme "Commencer pour 0,00€")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            }
            .padding(.vertical, 30)
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
            .offset(y: offset)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
        }
        .ignoresSafeArea()
    }
}
