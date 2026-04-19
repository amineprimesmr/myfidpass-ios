//
//  FlyerAIGenerationProgressExperience.swift
//  myfidpass
//
//  Barre de progression 70 s + textes pédagogiques pendant la génération flyer IA.
//

import SwiftUI

/// Barre de progression linéaire sur 70 s avec messages qui évoluent (UX « studio créatif »).
struct FlyerAIGenerationProgressExperience: View {
    var isGenerating: Bool
    /// Durée totale de remplissage de la barre (secondes).
    var totalDuration: TimeInterval = 70
    /// Couleur d’accent (alignée sur le violet studio).
    var accentColor: Color = Color(red: 0.45, green: 0.32, blue: 0.96)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sessionStart: Date?

    private static let stepTitles: [String] = [
        "Analyse de votre brief",
        "Mise en page du cadre",
        "Composition du visuel",
        "Harmonisation des couleurs",
        "Intégration QR & roue",
        "Affinage des contrastes",
        "Rendu haute définition",
        "Contrôle qualité",
        "Préparation partage",
        "Finalisation"
    ]

    private static let stepSubtitles: [String] = [
        "Vos mots-clés et la palette guident le moteur créatif.",
        "Structure, marges et hiérarchie pour un flyer lisible.",
        "Textures, fond et ambiance de votre commerce.",
        "Cohérence avec l’identité visuelle choisie.",
        "Placement du code QR et de la roue à lots cadeaux.",
        "Lisibilité sur écran et à l’impression.",
        "Génération de l’image finale côté serveur.",
        "Netteté, détails et équilibre des zones.",
        "Format adapté au partage et à l’affichage.",
        "Dernières retouches avant affichage dans l’app."
    ]

    private var stepCount: Int { min(Self.stepTitles.count, Self.stepSubtitles.count) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            TimelineView(.animation(minimumInterval: reduceMotion ? 0.6 : 1.0 / 30.0)) { context in
                let p = progress(at: context.date)
                let idx = stepIndex(forProgress: p)
                VStack(alignment: .leading, spacing: 16) {
                    headerRow(percent: p)
                    progressBar(progress: p, date: context.date)
                    stepTexts(stepIndex: idx)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear(perform: syncSessionStartIfNeeded)
        .onChange(of: isGenerating) { _, new in
            if new {
                sessionStart = Date()
            } else {
                sessionStart = nil
            }
        }
    }

    private func syncSessionStartIfNeeded() {
        if isGenerating, sessionStart == nil {
            sessionStart = Date()
        }
    }

    private func headerRow(percent: Double) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text("Création de votre flyer")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(FlyerProgressTheme.textPrimary)
            Spacer(minLength: 0)
            Text("\(Int(round(percent * 100)))%")
                .font(.system(.caption, design: .rounded, weight: .bold).monospacedDigit())
                .foregroundStyle(FlyerProgressTheme.textSecondary)
                .contentTransition(.numericText())
        }
    }

    private func progressBar(progress p: Double, date: Date) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(FlyerProgressTheme.trackBackground)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor.opacity(0.92),
                                Color(red: 0.62, green: 0.48, blue: 0.99),
                                accentColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, w * CGFloat(p)))
                    .shadow(color: accentColor.opacity(0.42), radius: 8, y: 0)
                if !reduceMotion, isGenerating, p > 0.02, p < 0.995 {
                    shimmerSheen(totalWidth: w, filledWidth: max(8, w * CGFloat(p)), time: date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .frame(height: 10)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(FlyerProgressTheme.hairline, lineWidth: 1)
        )
    }

    private func shimmerSheen(totalWidth: CGFloat, filledWidth: CGFloat, time: TimeInterval) -> some View {
        let phase = (time * 0.9).truncatingRemainder(dividingBy: 1.0)
        let travel = (phase * 2 - 0.5) * filledWidth
        return LinearGradient(
            colors: [
                .clear,
                Color.white.opacity(0.18),
                Color.white.opacity(0.32),
                Color.white.opacity(0.18),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: min(filledWidth * 0.55, 160))
        .offset(x: travel * 0.4)
        .blur(radius: 1)
        .mask(alignment: .leading) {
            Capsule()
                .frame(width: filledWidth)
        }
    }

    private func stepTexts(stepIndex idx: Int) -> some View {
        let title = Self.stepTitles[safe: idx] ?? Self.stepTitles[0]
        let subtitle = Self.stepSubtitles[safe: idx] ?? Self.stepSubtitles[0]
        return VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(FlyerProgressTheme.textPrimary)
            Text(subtitle)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(FlyerProgressTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: idx)
        .id(idx)
    }

    private func progress(at date: Date) -> Double {
        guard isGenerating, let start = sessionStart else { return 0 }
        let elapsed = date.timeIntervalSince(start)
        return min(1, max(0, elapsed / totalDuration))
    }

    private func stepIndex(forProgress p: Double) -> Int {
        min(stepCount - 1, Int(p * Double(stepCount)))
    }
}

// MARK: - Couleurs (alignées sur le hub flyer IA)

private enum FlyerProgressTheme {
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.38)
    static let trackBackground = Color.white.opacity(0.1)
    static let hairline = Color.white.opacity(0.14)
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

#Preview {
    ZStack {
        Color(red: 14 / 255, green: 17 / 255, blue: 19 / 255).ignoresSafeArea()
        FlyerAIGenerationProgressExperience(isGenerating: true)
            .padding()
    }
}
