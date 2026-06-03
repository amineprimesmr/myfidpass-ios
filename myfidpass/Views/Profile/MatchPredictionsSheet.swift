//
//  MatchPredictionsSheet.swift
//  myfidpass
//
//  Configuration commerçant du challenge pronostics — les clients pronostiquent sur leur carte fidélité.
//

import SwiftUI

struct MatchPredictionsSheet: View {
    let slug: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var isSavingConfig = false
    @State private var enabled = false
    @State private var pointsPerCorrectPrediction = 10
    @State private var nextMatch: MatchPredictionNextMatchDTO?
    @State private var stats: MatchPredictionStatsDTO?
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 48)
                    } else {
                        merchantInfoCard
                        configCard
                        if enabled {
                            nextMatchPreviewCard
                        }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Coupe du monde 2026")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private var merchantInfoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.2.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.Colors.primary)
            VStack(alignment: .leading, spacing: 4) {
                Text("Pronostics côté clients")
                    .font(.subheadline.weight(.bold))
                Text("Tes clients choisissent le résultat du prochain match sur leur carte fidélité (page web / Wallet). Tu actives le jeu et les points ici — pas de pronostic depuis l’app commerçant.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var configCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activer le challenge")
                        .font(.headline)
                    Text("Bandeau « Pronostiquez et gagnez » sur le flyer + bloc sur la carte client.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Stepper(value: $pointsPerCorrectPrediction, in: 1...500, step: 1) {
                HStack {
                    Text("Points par bon pronostic")
                    Spacer()
                    Text("+\(pointsPerCorrectPrediction) pts")
                        .fontWeight(.bold)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }

            Button {
                Task { await saveConfig() }
            } label: {
                HStack {
                    if isSavingConfig { ProgressView().tint(.white) }
                    Text(isSavingConfig ? "Enregistrement..." : "Enregistrer")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(AppTheme.Colors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isSavingConfig)

            feedbackText
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 4, y: 2)
    }

    @ViewBuilder
    private var nextMatchPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prochain match (aperçu client)")
                .font(.headline)

            if let match = nextMatch {
                VStack(spacing: 16) {
                    Text(match.roundLabel ?? match.title ?? "Phase de groupes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)

                    HStack(alignment: .center, spacing: 12) {
                        teamColumn(flag: match.teamHomeFlag, name: match.teamHome)
                        Text("VS")
                            .font(.caption.weight(.black))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                        teamColumn(flag: match.teamAwayFlag, name: match.teamAway)
                    }

                    Text(formatDate(match.startsAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    HStack {
                        Label("\(stats?.predictionsOnNextMatch ?? match.entriesCount ?? 0) pronostics", systemImage: "person.3.fill")
                        Spacer()
                        if let total = stats?.totalPredictions, total > 0 {
                            Text("\(total) au total")
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                    .font(.caption.weight(.semibold))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [Color(red: 0.95, green: 0.99, blue: 0.96), AppTheme.Colors.cardBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
            } else {
                Text("Aucun match ouvert pour l’instant. Le calendrier se met à jour automatiquement.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 4, y: 2)
    }

    private func teamColumn(flag: String?, name: String) -> some View {
        VStack(spacing: 6) {
            Text(flag ?? "🏳️")
                .font(.system(size: 36))
            Text(name)
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var feedbackText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
        } else if let message {
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
    }

    private func load(clearErrors: Bool = true) async {
        await MainActor.run {
            isLoading = true
            if clearErrors { errorMessage = nil }
        }
        do {
            let response: MatchPredictionsDashboardResponse = try await APIClient.shared.request(
                .dashboardMatchPredictions(slug: slug)
            )
            await MainActor.run {
                apply(response)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = APIError.merchantFacingMessage(from: error) ?? "Impossible de charger la configuration."
                isLoading = false
            }
        }
    }

    private func saveConfig() async {
        await MainActor.run {
            isSavingConfig = true
            errorMessage = nil
            message = nil
        }
        do {
            let body = MatchPredictionsConfigPatchBody(
                enabled: enabled,
                pointsPerCorrectPrediction: pointsPerCorrectPrediction
            )
            let patch: MatchPredictionsConfigPatchResponse = try await APIClient.shared.request(
                .dashboardMatchPredictionsConfig(slug: slug, body: body)
            )
            await MainActor.run {
                if let cfg = patch.config {
                    enabled = cfg.enabled ?? enabled
                    if let pts = cfg.pointsPerCorrectPrediction {
                        pointsPerCorrectPrediction = max(1, min(500, pts))
                    }
                }
                message = "Configuration enregistrée."
                NotificationCenter.default.post(
                    name: .myfidpassMatchPredictionsConfigDidSave,
                    object: nil,
                    userInfo: ["slug": slug, "enabled": enabled]
                )
            }
            await load(clearErrors: false)
        } catch {
            await MainActor.run {
                errorMessage = APIError.merchantFacingMessage(from: error) ?? "Enregistrement impossible."
            }
        }
        await MainActor.run { isSavingConfig = false }
    }

    private func apply(_ response: MatchPredictionsDashboardResponse) {
        enabled = response.config?.enabled ?? false
        pointsPerCorrectPrediction = max(1, min(500, response.config?.pointsPerCorrectPrediction ?? 10))
        nextMatch = response.nextMatch
        stats = response.stats
    }

    private func formatDate(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "—" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: trimmed)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: trimmed)
        }
        guard let date else { return trimmed }
        return date.formatted(
            .dateTime
                .locale(Locale(identifier: "fr_FR"))
                .weekday(.wide)
                .day()
                .month(.wide)
                .hour()
                .minute()
        )
    }
}
