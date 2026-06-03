//
//  MatchPredictionsSheet.swift
//  myfidpass
//
//  Configuration commerçant du challenge pronostics foot.
//

import SwiftUI

struct MatchPredictionsSheet: View {
    let slug: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var isSavingConfig = false
    @State private var scoringMatchId: String?
    @State private var enabled = false
    @State private var pointsPerCorrectPrediction = 10
    @State private var matches: [MatchPredictionMatchDTO] = []
    @State private var selectedResults: [String: String] = [:]
    @State private var message: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        configCard
                        matchesCard
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

    private var configCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $enabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Activer le challenge")
                        .font(.headline)
                    Text("Les clients voient les matchs dans leur espace fidélité.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Stepper(value: $pointsPerCorrectPrediction, in: 1...500, step: 1) {
                HStack {
                    Text("Gain par bon pronostic")
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

    private var matchesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Phase de groupes")
                    .font(.headline)
                Spacer()
                if !matches.isEmpty {
                    Text("\(matches.count) matchs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            if matches.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Aucun match affiché pour l’instant.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Le calendrier (72 matchs de groupes) est chargé depuis le serveur. Vérifiez votre connexion ou réessayez.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Button("Réessayer") {
                        Task { await load(retryIfEmpty: false) }
                    }
                    .font(.subheadline.weight(.semibold))
                }
            } else {
                ForEach(matches) { match in
                    matchRow(match)
                    if match.id != matches.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 4, y: 2)
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

    private func matchRow(_ match: MatchPredictionMatchDTO) -> some View {
        let current = Binding<String>(
            get: { selectedResults[match.id] ?? match.resultChoice ?? "home" },
            set: { selectedResults[match.id] = $0 }
        )
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(match.title ?? "Match sélectionné")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text("\(match.teamHome) vs \(match.teamAway)")
                        .font(.subheadline.weight(.bold))
                    Text(formatDate(match.startsAt))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(match.entriesCount ?? 0) pronostics")
                        .font(.caption.weight(.semibold))
                    if (match.pointsDistributed ?? 0) > 0 {
                        Text("\(match.pointsDistributed ?? 0) pts distribués")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
            }

            Picker("Résultat", selection: current) {
                Text(match.teamHome).tag("home")
                Text("Nul").tag("draw")
                Text(match.teamAway).tag("away")
            }
            .pickerStyle(.segmented)

            Button {
                Task { await score(match: match, choice: current.wrappedValue) }
            } label: {
                HStack {
                    if scoringMatchId == match.id { ProgressView() }
                    Text(match.resultChoice == nil ? "Valider le résultat" : "Recalculer / confirmer")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(scoringMatchId != nil)
        }
        .padding(.vertical, 4)
    }

    private func load(clearErrors: Bool = true, retryIfEmpty: Bool = true) async {
        await MainActor.run {
            isLoading = true
            if clearErrors { errorMessage = nil }
        }
        do {
            var response: MatchPredictionsDashboardResponse = try await APIClient.shared.request(.dashboardMatchPredictions(slug: slug))
            if retryIfEmpty, response.matches.isEmpty {
                try? await Task.sleep(nanoseconds: 900_000_000)
                response = try await APIClient.shared.request(.dashboardMatchPredictions(slug: slug))
            }
            await MainActor.run {
                apply(response)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = APIError.merchantFacingMessage(from: error) ?? "Impossible de charger les pronostics."
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
            let patch: MatchPredictionsConfigPatchResponse = try await APIClient.shared.request(.dashboardMatchPredictionsConfig(slug: slug, body: body))
            await MainActor.run {
                if let cfg = patch.config {
                    enabled = cfg.enabled ?? enabled
                    if let pts = cfg.pointsPerCorrectPrediction {
                        pointsPerCorrectPrediction = max(1, min(500, pts))
                    }
                }
                message = "Configuration enregistrée."
                errorMessage = nil
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

    private func score(match: MatchPredictionMatchDTO, choice: String) async {
        await MainActor.run {
            scoringMatchId = match.id
            errorMessage = nil
            message = nil
        }
        do {
            let body = MatchPredictionsResultBody(resultChoice: choice)
            let response: MatchPredictionsResultResponse = try await APIClient.shared.request(.dashboardMatchPredictionsSetResult(slug: slug, matchId: match.id, body: body))
            let winners = response.winnersCount ?? response.correctCount ?? 0
            await load()
            await MainActor.run { message = "Résultat validé : \(winners) gagnant(s)." }
        } catch {
            await MainActor.run {
                errorMessage = APIError.merchantFacingMessage(from: error) ?? "Validation du résultat impossible."
            }
        }
        await MainActor.run { scoringMatchId = nil }
    }

    private func apply(_ response: MatchPredictionsDashboardResponse) {
        enabled = response.config?.enabled ?? false
        pointsPerCorrectPrediction = max(1, min(500, response.config?.pointsPerCorrectPrediction ?? 10))
        matches = response.matches
        selectedResults = Dictionary(uniqueKeysWithValues: response.matches.map { ($0.id, $0.resultChoice ?? "home") })
    }

    private func formatDate(_ raw: String) -> String {
        let formatter = ISO8601DateFormatter()
        let date = formatter.date(from: raw) ?? Date()
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
    }
}
