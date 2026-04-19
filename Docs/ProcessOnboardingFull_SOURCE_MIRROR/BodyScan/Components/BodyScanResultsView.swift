//
//  BodyScanResultsView.swift
//  Process
//
//  Vue d'affichage des résultats du scan - Version complète avec analyses détaillées
//

import SwiftUI

struct BodyScanResultsView: View {
    let scanData: BodyScanData
    let chatGPTResult: BodyScanChatGPTResult?
    let onContinue: () -> Void

    @State private var animationProgress: Double = 0.0
    @State private var visibleSections: Set<ResultSection> = []

    enum ResultSection: CaseIterable {
        case overview, posture, composition, bodyParts, strengths, improvements, verdict, recommendations
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                // Vue d'ensemble
                if let overview = chatGPTResult?.overview {
                    OverviewCard(overview: overview, animationProgress: animationProgress, delay: 0.0)
                }

                // Score de posture
                if let posture = scanData.postureAnalysis {
                    PostureScoreCard(
                        posture: posture,
                        animationProgress: animationProgress,
                        delay: 0.1
                    )
                }

                // Points forts
                if let strengths = chatGPTResult?.strengths, !strengths.isEmpty {
                    StrengthsCard(
                        strengths: strengths,
                        animationProgress: animationProgress,
                        delay: 0.2
                    )
                }

                // Composition corporelle détaillée
                if let composition = scanData.composition {
                    DetailedCompositionCard(
                        composition: composition,
                        chatGPTComposition: chatGPTResult?.composition,
                        animationProgress: animationProgress,
                        delay: 0.3
                    )
                }

                // Analyses par partie du corps
                if let bodyParts = chatGPTResult?.bodyPartsAnalysis {
                    BodyPartsAnalysisSection(
                        bodyParts: bodyParts,
                        animationProgress: animationProgress,
                        delay: 0.4
                    )
                }

                // Axes d'amélioration
                if let improvements = chatGPTResult?.improvements, !improvements.isEmpty {
                    ImprovementsCard(
                        improvements: improvements,
                        animationProgress: animationProgress,
                        delay: 0.6
                    )
                }

                // Verdict final
                if let verdict = chatGPTResult?.finalVerdict {
                    FinalVerdictCard(
                        verdict: verdict,
                        animationProgress: animationProgress,
                        delay: 0.7
                    )
                }

                // Recommandations
                if let recommendations = chatGPTResult?.recommendations, !recommendations.isEmpty {
                    BodyScanRecommendationsCard(
                        recommendations: recommendations,
                        animationProgress: animationProgress,
                        delay: 0.8
                    )
                }

                // Bouton continuer
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    onContinue()
                }) {
                    Text("CONTINUER")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .opacity(animationProgress)
                .offset(y: (1.0 - animationProgress) * 30)
                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.9), value: animationProgress)
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) {
            animationProgress = 1.0
        }
    }
}

// MARK: - Vue d'ensemble

struct OverviewCard: View {
    let overview: String
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan)

                Text("Vue d'ensemble")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(overview)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

// MARK: - Carte Score de Posture

struct PostureScoreCard: View {
    let posture: PostureAnalysis
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "figure.stand")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)

                Text("Analyse de Posture")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            // Score global
            VStack(spacing: 8) {
                Text("\(Int(posture.overallScore))")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)

                Text("/ 100")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 20)

            // Déséquilibres détectés
            if !posture.imbalances.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Déséquilibres détectés:")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))

                    ForEach(Array(posture.imbalances.enumerated()), id: \.element.id) { index, imbalance in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(severityColor(imbalance.severity))
                                .frame(width: 10, height: 10)

                            Text(imbalance.description)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)

                            Spacer()
                        }
                        .opacity(animationProgress)
                        .offset(x: (1.0 - animationProgress) * -20)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay + Double(index) * 0.05), value: animationProgress)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }

    private func severityColor(_ severity: PostureSeverity) -> Color {
        switch severity {
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        }
    }
}

// MARK: - Points forts

struct StrengthsCard: View {
    let strengths: [String]
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.green)

                Text("Tes points forts")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(strengths.enumerated()), id: \.offset) { index, strength in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)

                        Text(strength)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(2)

                        Spacer()
                    }
                    .opacity(animationProgress)
                    .offset(x: (1.0 - animationProgress) * -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay + Double(index) * 0.05), value: animationProgress)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

// MARK: - Composition corporelle détaillée

struct DetailedCompositionCard: View {
    let composition: BodyComposition
    let chatGPTComposition: BodyCompositionChatGPT?
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)

                Text("Composition Corporelle")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(spacing: 16) {
                // Pourcentages
                VStack(spacing: 12) {
                    if let bodyFat = composition.bodyFatPercentage {
                        CompositionRow(title: "Masse grasse", value: String(format: "%.1f%%", bodyFat), color: .orange)
                    }
                    if let muscle = composition.muscleMassPercentage {
                        CompositionRow(title: "Masse musculaire", value: String(format: "%.1f%%", muscle), color: .blue)
                    }
                    if let bmi = composition.bmi {
                        CompositionRow(title: "IMC", value: String(format: "%.1f", bmi), color: .green)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

struct CompositionRow: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.8))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Analyses par partie du corps

struct BodyPartsAnalysisSection: View {
    let bodyParts: BodyPartsAnalysisChatGPT
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "figure.arms.open")
                    .font(.system(size: 24))
                    .foregroundColor(.purple)

                Text("Analyses détaillées")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 40)

            VStack(spacing: 16) {
                if let shoulders = bodyParts.shoulders {
                    BodyPartCard(title: "Épaules & ceinture scapulaire", analysis: shoulders, color: .blue, delay: delay + 0.0)
                }
                if let back = bodyParts.back {
                    BodyPartCard(title: "Dos", analysis: back, color: .indigo, delay: delay + 0.05)
                }
                if let chest = bodyParts.chest {
                    BodyPartCard(title: "Poitrine", analysis: chest, color: .pink, delay: delay + 0.1)
                }
                if let pelvis = bodyParts.pelvis {
                    BodyPartCard(title: "Bassin & hanches", analysis: pelvis, color: .teal, delay: delay + 0.15)
                }
                if let waist = bodyParts.waist {
                    BodyPartCard(title: "Taille", analysis: waist, color: .cyan, delay: delay + 0.2)
                }
                if let legs = bodyParts.legs {
                    BodyPartCard(title: "Jambes", analysis: legs, color: .mint, delay: delay + 0.25)
                }
            }
        }
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

struct BodyPartCard: View {
    let title: String
    let analysis: BodyPartAnalysisChatGPT
    let color: Color
    let delay: Double

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                HapticManager.shared.impact(.light)
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    if let alignment = analysis.alignment, !alignment.isEmpty {
                        BodyScanDetailRow(label: "Alignement", text: alignment)
                    }
                    if let posture = analysis.posture, !posture.isEmpty {
                        BodyScanDetailRow(label: "Posture", text: posture)
                    }
                    if let observations = analysis.observations, !observations.isEmpty {
                        BodyScanDetailRow(label: "Observations", text: observations)
                    }
                    if let width = analysis.width, !width.isEmpty {
                        BodyScanDetailRow(label: "Largeur", text: width)
                    }
                    if let thickness = analysis.thickness, !thickness.isEmpty {
                        BodyScanDetailRow(label: "Épaisseur", text: thickness)
                    }
                    if let summary = analysis.summary, !summary.isEmpty {
                        BodyScanDetailRow(label: "Résumé", text: summary, isSummary: true)
                    }
                    if let quadricepsHamstrings = analysis.quadricepsHamstrings, !quadricepsHamstrings.isEmpty {
                        BodyScanDetailRow(label: "Quadriceps / Ischio-jambiers", text: quadricepsHamstrings)
                    }
                    if let calves = analysis.calves, !calves.isEmpty {
                        BodyScanDetailRow(label: "Mollets", text: calves)
                    }
                    if let recommendation = analysis.recommendation, !recommendation.isEmpty {
                        BodyScanDetailRow(label: "Recommandation", text: recommendation, isRecommendation: true)
                    }
                    if let assessment = analysis.assessment, !assessment.isEmpty {
                        BodyScanDetailRow(label: "Évaluation", text: assessment)
                    }
                    if let potential = analysis.potential, !potential.isEmpty {
                        BodyScanDetailRow(label: "Potentiel", text: potential, isPotential: true)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
    }
}

struct BodyScanDetailRow: View {
    let label: String
    let text: String
    var isSummary: Bool = false
    var isRecommendation: Bool = false
    var isPotential: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            Text(text)
                .font(.system(size: 15, weight: isSummary || isRecommendation || isPotential ? .medium : .regular))
                .foregroundColor(.white.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Axes d'amélioration

struct ImprovementsCard: View {
    let improvements: [String]
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)

                Text("Axes d'amélioration")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(improvements.enumerated()), id: \.offset) { index, improvement in
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)

                        Text(improvement)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(2)

                        Spacer()
                    }
                    .opacity(animationProgress)
                    .offset(x: (1.0 - animationProgress) * -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay + Double(index) * 0.05), value: animationProgress)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

// MARK: - Verdict final

struct FinalVerdictCard: View {
    let verdict: String
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.yellow)

                Text("Verdict final")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            Text(verdict)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white.opacity(0.95))
                .lineSpacing(5)
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.yellow.opacity(0.15),
                            Color.orange.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.yellow.opacity(0.4), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}

// MARK: - Recommandations

struct BodyScanRecommendationsCard: View {
    let recommendations: [String]
    let animationProgress: Double
    let delay: Double

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.blue)

                Text("Recommandations")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.blue.opacity(0.8))
                            .frame(width: 24, alignment: .leading)

                        Text(recommendation)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer()
                    }
                    .opacity(animationProgress)
                    .offset(x: (1.0 - animationProgress) * -20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay + Double(index) * 0.05), value: animationProgress)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .opacity(animationProgress)
        .offset(y: (1.0 - animationProgress) * 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animationProgress)
    }
}
