//
//  SaaSProHubView.swift
//  myfidpass
//
//  Hub « Espace pro » : parité fonctionnelle avec le SaaS web (stats, jeux, engagement, notifs, import).
//

import SwiftUI
import CoreData
import Charts
import SafariServices
import UIKit

struct SaaSProHubView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        NavigationStack {
            List {
                Section("Données & membres") {
                    NavigationLink {
                        AdvancedStatsView()
                            .environmentObject(syncService)
                    } label: {
                        Label("Statistiques & évolution", systemImage: "chart.xyaxis.line")
                    }
                    NavigationLink {
                        MembersImportExportView()
                            .environmentObject(syncService)
                    } label: {
                        Label("Import / export CSV", systemImage: "square.and.arrow.up.on.square")
                    }
                }

                Section("Programme & jeux") {
                    NavigationLink {
                        GamesManagementView()
                            .environmentObject(syncService)
                    } label: {
                        Label("Jeux & roulette", systemImage: "dice.fill")
                    }
                }

                Section("Notifications") {
                    NavigationLink {
                        AdvancedNotificationsView()
                            .environmentObject(syncService)
                    } label: {
                        Label("Campagnes & diagnostics", systemImage: "bell.badge.fill")
                    }
                }

                Section("Compte & abonnement") {
                    NavigationLink {
                        SubscriptionBusinessView()
                            .environmentObject(authService)
                            .environmentObject(syncService)
                    } label: {
                        Label("Abonnement & nouveau commerce", systemImage: "creditcard.fill")
                    }
                }
            }
            .navigationTitle("Espace pro")
            .navigationBarTitleDisplayMode(.large)
            .background(AppTheme.Colors.background)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Statistiques

private let statPeriods: [(id: String, label: String)] = [
    ("7d", "7 jours"),
    ("30d", "30 jours"),
    ("this_month", "Ce mois"),
    ("6m", "6 mois"),
]

struct AdvancedStatsView: View {
    @EnvironmentObject private var syncService: SyncService
    @State private var period: String = "this_month"
    @State private var stats: BusinessStatsResponse?
    @State private var evolution: [EvolutionWeekDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                periodPicker
                if let stats {
                    statGrid(stats)
                }
                if !evolution.isEmpty {
                    EvolutionActivityChartView(evolution: evolution)
                }
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .alert("Erreur", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private var periodPicker: some View {
        Picker("Période", selection: $period) {
            ForEach(statPeriods, id: \.id) { p in
                Text(p.label).tag(p.id)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .onChange(of: period) { _, _ in Task { await load() } }
    }

    @ViewBuilder
    private func statGrid(_ s: BusinessStatsResponse) -> some View {
        let cells: [(String, String)] = [
            ("Membres", "\(s.membersCount ?? 0)"),
            ("Points (période)", "\(s.pointsThisMonth ?? 0)"),
            ("Transactions", "\(s.transactionsThisMonth ?? 0)"),
            ("Nouveaux (7 j)", "\(s.newMembersLast7Days ?? 0)"),
            ("Inactifs 30 j", "\(s.inactiveMembers30Days ?? 0)"),
            ("Rétention %", String(format: "%.0f", s.retentionPct ?? 0)),
        ]
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(cells, id: \.0) { title, value in
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(AppTheme.Fonts.caption()).foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(value).font(AppTheme.Fonts.title3()).foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }
        }
        .padding(.horizontal)
    }

    private func load() async {
        guard let slug = AuthStorage.currentBusinessSlug else {
            errorMessage = "Aucun commerce sélectionné."
            return
        }
        isLoading = true
        defer { Task { @MainActor in isLoading = false } }
        do {
            async let s: BusinessStatsResponse = APIClient.shared.request(.businessStats(slug: slug, period: period))
            async let ev: DashboardEvolutionResponse = APIClient.shared.request(.businessEvolution(slug: slug, weeks: 8, period: period))
            let (gotStats, gotEv) = try await (s, ev)
            await MainActor.run {
                stats = gotStats
                evolution = gotEv.evolution
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}

/// Graphique d’évolution : vue séparée pour éviter l’erreur « unable to type-check in reasonable time ».
private struct EvolutionActivityChartView: View {
    let evolution: [EvolutionWeekDTO]

    private struct Row: Identifiable {
        let id: Int
        let weekLabel: String
        let operations: Int
    }

    private var rows: [Row] {
        evolution.enumerated().map { index, el in
            let w = (el.weekIndex ?? index) + 1
            return Row(id: index, weekLabel: "S\(w)", operations: el.operationsCount ?? 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Activité par semaine")
                .font(AppTheme.Fonts.headline())
                .padding(.horizontal)
            Chart(rows) { row in
                BarMark(
                    x: .value("Sem.", row.weekLabel),
                    y: .value("Ops", row.operations)
                )
                .foregroundStyle(AppTheme.Colors.primary.gradient)
            }
            .frame(height: 220)
            .padding(.horizontal)
        }
    }
}

// MARK: - Import / export

struct MembersImportExportView: View {
    @EnvironmentObject private var syncService: SyncService
    @State private var importText = ""
    @State private var onDuplicate: String = "skip"
    @State private var isImporting = false
    @State private var message: String?
    @State private var showShareMembers = false
    @State private var showShareTx = false
    @State private var csvMembersURL: URL?
    @State private var csvTxURL: URL?

    var body: some View {
        Form {
            Section {
                Text("Collez des lignes `email;nom;points` ou une ligne par membre JSON depuis un tableur.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextEditor(text: $importText)
                    .frame(minHeight: 120)
                Picker("Doublons", selection: $onDuplicate) {
                    Text("Ignorer").tag("skip")
                    Text("Mettre à jour").tag("update")
                }
                Button {
                    Task { await runImport() }
                } label: {
                    if isImporting { ProgressView() } else { Text("Importer") }
                }
                .disabled(isImporting || importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } header: { Text("Import membres") }

            Section {
                Button("Télécharger export membres (.csv)") {
                    Task { await exportMembers() }
                }
                Button("Télécharger transactions 30 j (.csv)") {
                    Task { await exportTx() }
                }
            } header: { Text("Export") }
        }
        .navigationTitle("Import / export")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Résultat", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
        .sheet(isPresented: $showShareMembers) {
            if let csvMembersURL {
                ShareSheet(items: [csvMembersURL])
            }
        }
        .sheet(isPresented: $showShareTx) {
            if let csvTxURL {
                ShareSheet(items: [csvTxURL])
            }
        }
    }

    private func runImport() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        let lines = importText.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        var rows: [MembersImportPayload.MemberImportRow] = []
        for line in lines {
            let parts = line.split(separator: ";").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                let email = parts[0]
                let name = parts[1]
                let pts = parts.count > 2 ? Int(parts[2]) : nil
                rows.append(.init(email: email, name: name, points: pts))
            }
        }
        guard !rows.isEmpty else {
            message = "Aucune ligne valide (format : email;nom;points optionnel)."
            return
        }
        isImporting = true
        defer { Task { @MainActor in isImporting = false } }
        do {
            let payload = MembersImportPayload(members: rows, onDuplicate: onDuplicate)
            let r = try await APIClient.shared.request(.membersImport(slug: slug, payload: payload)) as MembersImportResponse
            await MainActor.run {
                message = "Créés : \(r.created ?? 0), mis à jour : \(r.updated ?? 0), ignorés : \(r.skipped ?? 0), erreurs : \(r.errors ?? 0)."
                importText = ""
            }
            await syncService.syncIfNeeded(force: true)
        } catch {
            await MainActor.run {
                message = (error as? APIError)?.errorDescription ?? "Import impossible."
            }
        }
    }

    private func exportMembers() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let data = try await APIClient.shared.requestCSV(.businessMembersExport(slug: slug, search: nil, filter: nil, sort: nil))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("membres-\(slug).csv")
            try data.write(to: url, options: .atomic)
            await MainActor.run {
                csvMembersURL = url
                showShareMembers = true
            }
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription ?? "Export impossible." }
        }
    }

    private func exportTx() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let data = try await APIClient.shared.requestCSV(.businessTransactionsExport(slug: slug, days: 30, type: nil))
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("transactions-\(slug).csv")
            try data.write(to: url, options: .atomic)
            await MainActor.run {
                csvTxURL = url
                showShareTx = true
            }
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription ?? "Export impossible." }
        }
    }
}

// MARK: - Jeux

struct GamesManagementView: View {
    @EnvironmentObject private var syncService: SyncService
    @State private var games: [BusinessGameDTO] = []
    @State private var errorMessage: String?

    var body: some View {
        List {
            ForEach(games) { g in
                NavigationLink {
                    RouletteRewardsEditorView(game: g)
                        .environmentObject(syncService)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(g.gameName ?? g.gameCode ?? "Jeu")
                            Text(g.enabled == true ? "Activé" : "Désactivé")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Jeux")
        .task { await load() }
        .alert("Erreur", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
    }

    private func load() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let r = try await APIClient.shared.request(.dashboardGames(slug: slug)) as DashboardGamesResponse
            await MainActor.run { games = r.games }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription }
        }
    }
}

struct RouletteRewardsEditorView: View {
    let game: BusinessGameDTO
    @EnvironmentObject private var syncService: SyncService
    @State private var editRows: [EditableRouletteRow] = []
    @State private var enabled: Bool
    @State private var ticketCost: Int
    @State private var dailyLimit: Int
    @State private var cooldown: Int
    @State private var isSaving = false
    @State private var isSavingRewards = false
    @State private var message: String?

    private var isRoulette: Bool { (game.gameCode ?? "").lowercased() == "roulette" }

    init(game: BusinessGameDTO) {
        self.game = game
        _enabled = State(initialValue: game.enabled ?? false)
        _ticketCost = State(initialValue: game.ticketCost ?? 1)
        _dailyLimit = State(initialValue: game.dailySpinLimit ?? 0)
        _cooldown = State(initialValue: game.cooldownSeconds ?? 0)
    }

    var body: some View {
        Form {
            Section("Configuration") {
                Toggle("Activé", isOn: $enabled)
                Stepper("Coût tickets : \(ticketCost)", value: $ticketCost, in: 1...50)
                Stepper("Limite spins / jour : \(dailyLimit)", value: $dailyLimit, in: 0...100)
                Stepper("Cooldown (s) : \(cooldown)", value: $cooldown, in: 0...3600)
                Button("Enregistrer la config") { Task { await saveConfig() } }
                    .disabled(isSaving)
            }
            Section("Segments (\(isRoulette ? "roulette : points ou aucun gain" : "lecture seule"))") {
                if editRows.isEmpty {
                    Text("Aucun segment. Ajoutez-en un ou rechargez.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach($editRows) { $row in
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Code interne", text: $row.code)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .disabled(!isRoulette)
                        TextField("Libellé affiché", text: $row.label)
                            .disabled(!isRoulette)
                        Picker("Type de lot", selection: $row.kind) {
                            Text("Aucun gain").tag("none")
                            Text("Points").tag("points")
                        }
                        .disabled(!isRoulette)
                        if row.kind == "points" {
                            Stepper("Points gagnés : \(row.pointsValue)", value: $row.pointsValue, in: 0...1_000_000)
                                .disabled(!isRoulette)
                        }
                        Stepper("Poids (probabilité relative) : \(row.weight)", value: $row.weight, in: 1...1000)
                            .disabled(!isRoulette)
                        Toggle("Actif", isOn: $row.active)
                            .disabled(!isRoulette)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    guard isRoulette else { return }
                    editRows.remove(atOffsets: indexSet)
                }
                if isRoulette {
                    Button("Ajouter un segment") {
                        editRows.append(EditableRouletteRow.newSegment())
                    }
                    Button("Enregistrer les segments") { Task { await saveRewards() } }
                        .disabled(isSavingRewards || editRows.isEmpty)
                } else {
                    Text("L’édition des lots pour ce jeu se fait sur le SaaS web si disponible.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(game.gameName ?? "Jeu")
        .task { await loadRewards() }
        .alert("Info", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
    }

    private var slug: String? { AuthStorage.currentBusinessSlug }
    private var code: String { game.gameCode ?? "roulette" }

    private func loadRewards() async {
        guard let slug else { return }
        do {
            let r = try await APIClient.shared.request(.dashboardGameRewardsGet(slug: slug, gameCode: code)) as GameRewardsResponse
            await MainActor.run {
                editRows = r.rewards.map { EditableRouletteRow(from: $0) }
            }
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }

    private func saveConfig() async {
        guard let slug else { return }
        isSaving = true
        defer { Task { @MainActor in isSaving = false } }
        do {
            let body = PatchGameBody(enabled: enabled, ticketCost: ticketCost, dailySpinLimit: dailyLimit, cooldownSeconds: cooldown)
            _ = try await APIClient.shared.request(.dashboardPatchGame(slug: slug, gameCode: code, body: body)) as SimpleAPIOKResponse
            await MainActor.run { message = "Configuration enregistrée." }
            await syncService.syncIfNeeded(force: true)
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }

    private func saveRewards() async {
        guard let slug, isRoulette else { return }
        isSavingRewards = true
        defer { Task { @MainActor in isSavingRewards = false } }
        do {
            let inputs = editRows.map { $0.toGameRewardInput() }
            let body = PutGameRewardsBody(rewards: inputs)
            _ = try await APIClient.shared.request(.dashboardGameRewardsPut(slug: slug, gameCode: code, body: body)) as EmptyResponse
            await MainActor.run { message = "Segments enregistrés." }
            await loadRewards()
            await syncService.syncIfNeeded(force: true)
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }
}

/// Ligne éditable pour PUT `/dashboard/games/roulette/rewards` (kind `none` ou `points` uniquement).
private struct EditableRouletteRow: Identifiable {
    let id = UUID()
    var code: String
    var label: String
    var kind: String
    var weight: Int
    var active: Bool
    var pointsValue: Int

    private init(code: String, label: String, kind: String, weight: Int, active: Bool, pointsValue: Int) {
        self.code = code
        self.label = label
        self.kind = kind
        self.weight = weight
        self.active = active
        self.pointsValue = pointsValue
    }

    init(from dto: GameRewardDTO) {
        let c = dto.code?.trimmingCharacters(in: .whitespaces) ?? ""
        code = c.isEmpty ? "seg_\(UUID().uuidString.prefix(8))" : c
        label = dto.label ?? ""
        let k = (dto.kind ?? "none").lowercased()
        kind = k == "points" ? "points" : "none"
        weight = max(1, dto.weight ?? 1)
        active = dto.active ?? true
        pointsValue = max(0, dto.value?.points ?? 0)
    }

    static func newSegment() -> EditableRouletteRow {
        EditableRouletteRow(
            code: "seg_\(UUID().uuidString.prefix(8))",
            label: "Nouveau",
            kind: "none",
            weight: 1,
            active: true,
            pointsValue: 0
        )
    }

    func toGameRewardInput() -> GameRewardInput {
        let k = kind == "points" ? "points" : "none"
        let value: GameRewardInput.GameRewardValueInput? =
            k == "points"
            ? .init(points: max(0, pointsValue), stamps: nil)
            : .init(points: nil, stamps: nil)
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let codeFinal = trimmedCode.isEmpty ? "seg_\(UUID().uuidString.prefix(8))" : trimmedCode
        return GameRewardInput(
            code: codeFinal,
            label: trimmedLabel.isEmpty ? codeFinal : String(trimmedLabel.prefix(120)),
            kind: k,
            weight: max(1, weight),
            active: active,
            stock: nil,
            value: value
        )
    }
}

// MARK: - Notifications avancées

struct AdvancedNotificationsView: View {
    @EnvironmentObject private var syncService: SyncService
    @State private var title = ""
    @State private var bodyText = ""
    @State private var segment: String?
    @State private var segments: CampaignSegmentsResponse?
    @State private var stats: NotificationChannelStatsResponse?
    @State private var message: String?

    var body: some View {
        Form {
            Section("Segments (aperçu effectifs)") {
                if let s = segments {
                    Text("Inactifs 30j : \(s.inactive30 ?? 0)")
                    Text("Nouveaux 30j : \(s.new30 ?? 0)")
                    Text("Récurrents : \(s.recurrent ?? 0)")
                }
            }
            Section("Campagne") {
                TextField("Titre (optionnel)", text: $title)
                TextField("Message", text: $bodyText, axis: .vertical)
                    .lineLimit(3...6)
                Picker("Segment", selection: Binding(
                    get: { segment ?? "" },
                    set: { segment = $0.isEmpty ? nil : $0 }
                )) {
                    Text("Tous").tag("")
                    Text("Inactifs 30j").tag("inactive30")
                    Text("Inactifs 90j").tag("inactive90")
                    Text("Nouveaux 30j").tag("new30")
                    Text("Récurrents").tag("recurrent")
                    Text("Points ≥ 50").tag("points50")
                }
                Button("Envoyer") { Task { await send() } }
                    .disabled(bodyText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Diagnostics PassKit / Web Push") {
                if let stats {
                    Text("Abonnements Web Push : \(stats.webPushCount ?? 0)")
                    Text("Passes enregistrés : \(stats.passKitCount ?? 0)")
                    if let d = stats.diagnostic { Text(d).font(.caption) }
                }
                Button("Rafraîchir les stats") { Task { await loadStats() } }
            }
        }
        .navigationTitle("Notifications pro")
        .task {
            await loadSegments()
            await loadStats()
        }
        .alert("Info", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
    }

    private func loadSegments() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let s = try await APIClient.shared.request(.dashboardNotificationSegments(slug: slug)) as CampaignSegmentsResponse
            await MainActor.run { segments = s }
        } catch { }
    }

    private func loadStats() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let s = try await APIClient.shared.request(.dashboardNotificationStats(slug: slug)) as NotificationChannelStatsResponse
            await MainActor.run { stats = s }
        } catch { }
    }

    private func send() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        let msg = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }
        do {
            let payload = NotificationSendPayload(
                title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title,
                message: msg,
                categoryIds: nil,
                segment: segment
            )
            let r = try await APIClient.shared.request(.dashboardNotificationSend(slug: slug, body: payload)) as NotificationSendResponse
            await MainActor.run {
                message = "Envoyé : \(r.sent ?? 0) (Web: \(r.sentWebPush ?? 0), Wallet: \(r.sentPassKit ?? 0))"
                bodyText = ""
            }
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }
}

// MARK: - Abonnement & commerce

struct SubscriptionBusinessView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @State private var checkoutURL: URL?
    @State private var showSafari = false
    @State private var bizName = ""
    @State private var bizSlug = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section("Abonnement") {
                Text(
                    "L’app ne propose pas d’achat intégré (In-App Purchase). "
                        + "L’abonnement MyFidpass est souscrit sur notre site via Stripe : le détail des offres "
                        + "(intitulé, durée, prix en vigueur) s’affiche sur la page de paiement avant validation."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    Link("Conditions d’utilisation", destination: LegalURLs.termsOfUse)
                    Link("Politique de confidentialité", destination: LegalURLs.privacyPolicy)
                }
                .font(.subheadline)
                Button("Souscrire ou gérer l’offre (paiement Stripe)") {
                    Task { await startCheckout() }
                }
            }
            Section("Nouveau commerce") {
                TextField("Nom du commerce", text: $bizName)
                TextField("Slug (lettres minuscules)", text: $bizSlug)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Créer sur le serveur") {
                    Task { await createBiz() }
                }
                .disabled(bizName.trimmingCharacters(in: .whitespaces).isEmpty || bizSlug.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Compte pro")
        .sheet(isPresented: $showSafari) {
            if let checkoutURL {
                SafariView(url: checkoutURL)
            }
        }
        .alert("Info", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
    }

    private func startCheckout() async {
        do {
            let r = try await APIClient.shared.request(.paymentCheckout(planId: "starter")) as CheckoutSessionResponse
            if let u = r.url, let url = URL(string: u) {
                await MainActor.run {
                    checkoutURL = url
                    showSafari = true
                }
            } else {
                await MainActor.run { message = "Paiement indisponible (Stripe non configuré)." }
            }
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }

    private func createBiz() async {
        let name = bizName.trimmingCharacters(in: .whitespaces)
        var slug = bizSlug.trimmingCharacters(in: .whitespaces).lowercased()
        slug = slug.replacingOccurrences(of: " ", with: "-")
        let payload = CreateBusinessPayload(name: name, slug: slug, organizationName: name)
        do {
            let r = try await APIClient.shared.request(.createBusiness(payload: payload)) as CreateBusinessResponse
            await MainActor.run {
                message = "Commerce créé : \(r.slug ?? slug)"
                bizName = ""
                bizSlug = ""
            }
            if let s = r.slug {
                authService.selectBusiness(slug: s)
            }
            await syncService.syncIfNeeded(force: true)
        } catch {
            await MainActor.run { message = (error as? APIError)?.errorDescription }
        }
    }
}

// MARK: - Partage & Safari

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
