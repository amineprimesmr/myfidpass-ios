//
//  CarryOverCaloriesStepView.swift
//  Process
//
//  Page : Reportez-vous aux calories supplémentaires au lendemain ?
//

import SwiftUI

struct CarryOverCaloriesStepView: View {
    @StateObject private var hapticManager = HapticManager.shared

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            // Fond noir
            Color.black
                .ignoresSafeArea(.all)

            VStack(spacing: 0) {
                // Espacement en haut
                Spacer()
                    .frame(height: 60)

                // Question principale
                Text("Reportes-tu les calories supplémentaires au lendemain ?")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 12)

                // Tag informatif
                Text("Reportes-toi jusqu'à 200 cals")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.15))
                    )
                    .padding(.bottom, 40)

                // Deux cartes côte à côte
                HStack(spacing: 16) {
                    // Carte "Hier" (Hier)
                    VStack(alignment: .leading, spacing: 0) {
                        // En-tête avec icône et titre
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            Spacer()
                            Text("Hier")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.pink.opacity(0.8))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        // Données calories
                        Text("350/500")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)

                        // Label "calories restantes" avec "150"
                        HStack(spacing: 4) {
                            Text("calories restantes")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Text("150")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Spacer()

                        // Arc de progression en bas
                        GeometryReader { geometry in
                            ZStack {
                                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height)
                                let radius: CGFloat = geometry.size.width / 2 - 8

                                // Arc de fond
                                Path { path in
                                    path.addArc(
                                        center: center,
                                        radius: radius,
                                        startAngle: .degrees(180),
                                        endAngle: .degrees(0),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.black.opacity(0.1), lineWidth: 8)

                                // Arc de progression (70% = 350/500)
                                let progress: Double = 350.0 / 500.0 // 70%
                                let endAngle = 180.0 - (180.0 * progress)
                                Path { path in
                                    path.addArc(
                                        center: center,
                                        radius: radius,
                                        startAngle: .degrees(180),
                                        endAngle: .degrees(endAngle),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.black, lineWidth: 8)

                                // Icône flamme au centre en bas
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .position(x: center.x, y: center.y - radius * 0.3)
                            }
                        }
                        .frame(height: 60)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 1.0, green: 0.95, blue: 0.98)) // Rose pâle
                    )

                    // Carte "Aujourd'hui"
                    VStack(alignment: .leading, spacing: 0) {
                        // En-tête avec icône et titre
                        HStack {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            Spacer()
                            Text("Aujourd'hui")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                        // Données calories
                        Text("350/650")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)

                        // "+150" avec icône
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 12))
                                .foregroundColor(Color.gray.opacity(0.6))
                            Text("+150")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color.gray.opacity(0.7))
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        // Label "calories restantes" avec "150 + 150"
                        HStack(spacing: 4) {
                            Text("calories restantes")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white)
                            Text("150 + 150")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.black)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)

                        Spacer()

                        // Arc de progression en bas
                        GeometryReader { geometry in
                            ZStack {
                                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height)
                                let radius: CGFloat = geometry.size.width / 2 - 8

                                // Arc de fond
                                Path { path in
                                    path.addArc(
                                        center: center,
                                        radius: radius,
                                        startAngle: .degrees(180),
                                        endAngle: .degrees(0),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.black.opacity(0.1), lineWidth: 8)

                                // Arc de progression (54% = 350/650)
                                let progress: Double = 350.0 / 650.0 // 54%
                                let endAngle = 180.0 - (180.0 * progress)
                                Path { path in
                                    path.addArc(
                                        center: center,
                                        radius: radius,
                                        startAngle: .degrees(180),
                                        endAngle: .degrees(endAngle),
                                        clockwise: false
                                    )
                                }
                                .stroke(Color.black, lineWidth: 8)

                                // Icône flamme au centre en bas
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.black)
                                    .position(x: center.x, y: center.y - radius * 0.3)
                            }
                        }
                        .frame(height: 60)
                        .padding(.bottom, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)

                Spacer()
            }
        }
    }
}
