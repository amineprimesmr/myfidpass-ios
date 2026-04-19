//
//  ProcessResultsDurabilityStepView.swift
//  Process
//
//  Page avec graphique montrant que Process génère des résultats durables
//

import SwiftUI

struct ProcessResultsDurabilityStepView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @State private var animationProgress: CGFloat = 0.0

    // Callback pour passer à la page suivante
    var onComplete: (() -> Void)?

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    // Callback pour revenir en arrière
    var onBack: (() -> Void)?

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement uniforme entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing)

                // Espace supplémentaire pour descendre le graphique
                Spacer()
                    .frame(height: 80)

                // Graphique de performance - Style PlanProgressGraphView
                VStack(spacing: 20) {
                GeometryReader { geometry in
                        let width = geometry.size.width
                        let height: CGFloat = 200

                        // Données pour les deux courbes (6 mois) - Commencent à 0 (en bas)
                        // Courbe violette (Process) : monte lentement, exponentiellement et irrégulièrement
                        let processData: [Double] = [
                            0.0,      // Mois 0 : départ en bas
                            0.08,     // Mois 1 : légère montée
                            0.12,     // Mois 2 : petite irrégularité (plateau)
                            0.20,     // Mois 3 : accélération
                            0.28,     // Mois 4 : petite pause
                            0.42,     // Mois 5 : montée exponentielle
                            0.49      // Mois 6 : progression (réduite pour finir plus bas)
                        ]

                        // Courbe rouge (Traditionnel) : monte rapidement, atteint un pic modéré, puis redescend
                        // Valeurs ajustées pour qu'elle monte un peu plus haut mais reste sous la courbe violette
                        let traditionalData: [Double] = [
                            0.0,      // Mois 0 : départ en bas
                            0.15,     // Mois 1 : montée rapide
                            0.32,     // Mois 2 : pic modéré (encore plus haut)
                            0.28,     // Mois 3 : début de descente
                            0.20,     // Mois 4 : descente continue
                            0.12,     // Mois 5 : retour vers le bas
                            0.06      // Mois 6 : presque en bas
                        ]

                        ZStack {
                            // ✨ Rectangle sombre en fond
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )

                            // ✨ Texte "Performances" en haut à gauche
                            VStack {
                                HStack {
                                    Text("Performances")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.leading, 16)
                                        .padding(.top, 12)
                                        Spacer()
                                    }
                                Spacer()
                            }

                            // ✨ Texte "Méthode traditionnelle" en bas à droite (petit et discret)
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Text("Méthode traditionnelle")
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(.trailing, 16)
                                        .padding(.bottom, 12)
                                }
                            }

                            // ✨ Lignes horizontales en fond (grille) - sans les lignes en haut et en bas
                            Path { path in
                                // Dessiner seulement les lignes du milieu (1, 2, 3) pour éviter la superposition avec l'encadré
                                for i in 1...3 {
                                    let y = height * CGFloat(i) / 4
                                    path.move(to: CGPoint(x: 0, y: y))
                                    path.addLine(to: CGPoint(x: width, y: y))
                                }
                            }
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)

                            // Calculer les points pour les deux courbes avec normalisation globale
                            // Utiliser le max global pour que les courbes soient comparables
                            let globalMax = max(processData.max() ?? 1.0, traditionalData.max() ?? 1.0)
                            let processPoints = calculateSmoothPoints(data: processData, width: width, height: height, globalMax: globalMax)
                            let traditionalPoints = calculateSmoothPoints(data: traditionalData, width: width, height: height, globalMax: globalMax)

                            // ✨ Zone de remplissage sous la courbe Process (avec gradient violet) - ANIMATION PROGRESSIVE
                            if !processPoints.isEmpty {
                                Path { path in
                                    let bottomOffset: CGFloat = height * 8.0
                                    let bottomY = height + bottomOffset

                                    path.move(to: CGPoint(x: 0, y: bottomY))

                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(processPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(processPoints.prefix(visiblePointsCount))

                                    if !visiblePoints.isEmpty {
                                        // Premier point : ligne depuis le bas
                                        if let firstPoint = visiblePoints.first {
                                            path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                                        }

                                        // Construire la courbe progressivement
                                        for index in 1..<visiblePoints.count {
                                            let point = visiblePoints[index]
                                            let prevPoint = visiblePoints[index - 1]
                                            let controlPoint1 = CGPoint(
                                                x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                                y: prevPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: point.x - (point.x - prevPoint.x) / 3,
                                                y: point.y
                                            )
                                            path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                        }

                                        // Si l'animation n'est pas complète, fermer jusqu'au bord droit
                                        if let lastPoint = visiblePoints.last {
                                            path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
                                        }
                                    }

                                    path.addLine(to: CGPoint(x: 0, y: bottomY))
                                    path.closeSubpath()
                                }
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(red: 0.7, green: 0.55, blue: 0.85).opacity(0.7), location: 0.0),
                                            .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.9), location: 0.4),
                                            .init(color: Color(red: 0.4, green: 0.2, blue: 0.6).opacity(1.0), location: 0.5),
                                            .init(color: Color(red: 0.5, green: 0.3, blue: 0.7).opacity(0.6), location: 0.6),
                                            .init(color: Color(red: 0.6, green: 0.4, blue: 0.8).opacity(0.3), location: 0.75),
                                            .init(color: Color.clear, location: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0.0),
                                            .init(color: .white.opacity(0.8), location: 0.6),
                                            .init(color: .white.opacity(0.3), location: 0.85),
                                            .init(color: .clear, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                // ✨ OMBRE SOUS LA COURBE Process - Animation progressive point par point
                                Path { path in
                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(processPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(processPoints.prefix(visiblePointsCount))

                                    for (index, point) in visiblePoints.enumerated() {
                                        let adjustedPoint = CGPoint(x: point.x, y: point.y + 2)
                                        if index == 0 {
                                            path.move(to: adjustedPoint)
                                        } else {
                                            let prevPoint = visiblePoints[index - 1]
                                            let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y + 2)
                                            let controlPoint1 = CGPoint(
                                                x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                                y: prevAdjustedPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                                y: adjustedPoint.y
                                            )
                                            path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                        }
                                    }
                                }
                                .stroke(
                                    Color.black.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                                )
                                .blur(radius: 3)

                                // ✨ Courbe Process principale avec gradient violet - Animation progressive point par point
                                Path { path in
                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(processPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(processPoints.prefix(visiblePointsCount))

                                    for (index, point) in visiblePoints.enumerated() {
                                        if index == 0 {
                                            path.move(to: point)
                                        } else {
                                            let prevPoint = visiblePoints[index - 1]
                                            let controlPoint1 = CGPoint(
                                                x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                                y: prevPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: point.x - (point.x - prevPoint.x) / 3,
                                                y: point.y
                                            )
                                            path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                        }
                                    }
                                }
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.77, green: 0.64, blue: 0.97),
                                            Color(red: 0.6, green: 0.4, blue: 0.8),
                                            Color(red: 0.42, green: 0.05, blue: 0.51)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                                )

                                // ✨ TRAIT BLANC LÉGER SUR LE DESSUS DE LA COURBE Process - Animation progressive point par point
                                Path { path in
                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(processPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(processPoints.prefix(visiblePointsCount))

                                    for (index, point) in visiblePoints.enumerated() {
                                        let adjustedPoint = CGPoint(x: point.x, y: point.y - 2)
                                        if index == 0 {
                                            path.move(to: adjustedPoint)
                                        } else {
                                            let prevPoint = visiblePoints[index - 1]
                                            let prevAdjustedPoint = CGPoint(x: prevPoint.x, y: prevPoint.y - 2)
                                            let controlPoint1 = CGPoint(
                                                x: prevAdjustedPoint.x + (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                                y: prevAdjustedPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: adjustedPoint.x - (adjustedPoint.x - prevAdjustedPoint.x) / 3,
                                                y: adjustedPoint.y
                                            )
                                            path.addCurve(to: adjustedPoint, control1: controlPoint1, control2: controlPoint2)
                                        }
                                    }
                                }
                                .stroke(
                                    Color.white.opacity(0.3),
                                    style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round)
                                )

                                // ✨ Point blanc à la fin de la courbe Process - Apparition progressive
                                if let lastPoint = processPoints.last, animationProgress > 0.9 {
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 12, height: 12)
                                        .position(lastPoint)
                                        .opacity((animationProgress - 0.9) / 0.1) // Apparition progressive dans les 10% finaux
                                        .scaleEffect(animationProgress > 0.95 ? 1.0 : 0.5)
                                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: animationProgress)
                                }
                            }

                            // ✨ Zone de remplissage sous la courbe Traditionnel (rouge avec gradient) - ANIMATION PROGRESSIVE
                            if !traditionalPoints.isEmpty {
                                Path { path in
                                    let bottomOffset: CGFloat = height * 8.0
                                    let bottomY = height + bottomOffset

                                    path.move(to: CGPoint(x: 0, y: bottomY))

                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(traditionalPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(traditionalPoints.prefix(visiblePointsCount))

                                    if !visiblePoints.isEmpty {
                                        // Premier point : ligne depuis le bas
                                        if let firstPoint = visiblePoints.first {
                                            path.addLine(to: CGPoint(x: firstPoint.x, y: firstPoint.y))
                                        }

                                        // Construire la courbe progressivement
                                        for index in 1..<visiblePoints.count {
                                            let point = visiblePoints[index]
                                            let prevPoint = visiblePoints[index - 1]
                                            let controlPoint1 = CGPoint(
                                                x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                                y: prevPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: point.x - (point.x - prevPoint.x) / 3,
                                                y: point.y
                                            )
                                            path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                        }

                                        // Si l'animation n'est pas complète, fermer jusqu'au bord droit
                                        if let lastPoint = visiblePoints.last {
                                            path.addLine(to: CGPoint(x: lastPoint.x, y: bottomY))
                                        }
                                    }

                                    path.addLine(to: CGPoint(x: 0, y: bottomY))
                                    path.closeSubpath()
                                }
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color.red.opacity(0.4), location: 0.0),
                                            .init(color: Color.red.opacity(0.2), location: 0.5),
                                            .init(color: Color.red.opacity(0.05), location: 1.0)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .mask(
                                    LinearGradient(
                                        stops: [
                                            .init(color: .white, location: 0.0),
                                            .init(color: .white.opacity(0.8), location: 0.6),
                                            .init(color: .white.opacity(0.3), location: 0.85),
                                            .init(color: .clear, location: 1.0)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                // ✨ Courbe Traditionnel avec gradient rouge - Animation progressive point par point
                                Path { path in
                                    // ✅ Construire le chemin PROGRESSIVEMENT selon animationProgress
                                    let visiblePointsCount = Int(Double(traditionalPoints.count - 1) * animationProgress) + 1
                                    let visiblePoints = Array(traditionalPoints.prefix(visiblePointsCount))

                                    for (index, point) in visiblePoints.enumerated() {
                                        if index == 0 {
                                            path.move(to: point)
                                        } else {
                                            let prevPoint = visiblePoints[index - 1]
                                            let controlPoint1 = CGPoint(
                                                x: prevPoint.x + (point.x - prevPoint.x) / 3,
                                                y: prevPoint.y
                                            )
                                            let controlPoint2 = CGPoint(
                                                x: point.x - (point.x - prevPoint.x) / 3,
                                                y: point.y
                                            )
                                            path.addCurve(to: point, control1: controlPoint1, control2: controlPoint2)
                                        }
                                    }
                                }
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color.red.opacity(0.9),
                                            Color.red.opacity(0.7),
                                            Color.red.opacity(0.5)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                                )
                            }
                        }
                            }
                    .frame(height: 200)
                            .padding(.horizontal, 20)

                    // Labels "Mois 1" et "Mois 6" sous le rectangle
                    HStack {
                        Text("Mois 1")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.leading, 20) // Plus à gauche
                        Spacer()
                        Text("Mois 6")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.trailing, 20) // Plus à droite
                        }
                    .padding(.horizontal, 20) // Réduire le padding horizontal général
                    .padding(.top, -4) // Plus haut (padding négatif)

                        // Texte en dessous
                    Text("80% des utilisateurs de process maintiennent leurs performances meme 6 mois plus tard")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                    }
                .padding(.horizontal, 20)

                Spacer()
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Process génère des", "résultats durables")
                    .padding(.top, OnboardingConstants.titleTopPadding)  // Utiliser la même constante que les autres pages
                Spacer()
            }

        }
        .onAppear {
            // Valider automatiquement
            onValidationChanged?(true)

            // ✅ Animation progressive du graphique - les courbes se dessinent de gauche à droite
            // S'assurer que l'animation commence vraiment à 0
            animationProgress = 0.0

            // Démarrer l'animation immédiatement (sans délai) pour que les courbes se dessinent progressivement
            withAnimation(.easeInOut(duration: 3.0)) {
                animationProgress = 1.0
            }
        }
    }

    // MARK: - Calculate Smooth Points

    private func calculateSmoothPoints(data: [Double], width: CGFloat, height: CGFloat, globalMax: Double? = nil) -> [CGPoint] {
        guard !data.isEmpty else { return [] }

        // Petit padding horizontal : commencer un peu à droite et finir un peu à gauche
        let horizontalPadding: CGFloat = width * 0.05 // 5% de padding de chaque côté (augmenté)
        let usableWidth = width - (horizontalPadding * 2)
        let stepWidth = usableWidth / CGFloat(max(1, data.count - 1))
        var points: [CGPoint] = []

        // Utiliser le max global si fourni (pour normalisation globale), sinon utiliser le max local
        let maxValue = globalMax ?? (data.max() ?? 1.0)
        let minValue = data.min() ?? 0.0
        let valueRange = max(maxValue - minValue, 0.01) // Éviter division par zéro

        for (index, value) in data.enumerated() {
            let x: CGFloat
            if index == 0 {
                x = horizontalPadding // Commencer un peu à droite
            } else {
                x = horizontalPadding + (CGFloat(index) * stepWidth)
            }
            // Normaliser la valeur entre 0 et 1 en utilisant le max global
            // 0 = en bas (height), 1 = en haut (0)
            let normalizedValue = valueRange > 0.01 ? (value - minValue) / valueRange : 0.0
            // Utiliser 90% de la hauteur pour la courbe, avec un padding de 5% en haut
            // Quand normalizedValue = 0, y = height (tout en bas)
            // Quand normalizedValue = 1, y = height * 0.05 (près du haut)
            let y: CGFloat
            if normalizedValue <= 0.0 {
                y = height // Tout en bas quand value = minValue
            } else {
                y = height - (CGFloat(normalizedValue) * height * 0.9) - (height * 0.05)
            }
            points.append(CGPoint(x: x, y: min(height, max(height * 0.05, y))))
        }

        return points
    }
}
