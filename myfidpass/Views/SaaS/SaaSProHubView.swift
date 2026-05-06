//
//  SaaSProHubView.swift
//  myfidpass
//
//  Vues SaaS (stats, import, campagnes, abonnement) — entrées : Commerce et Paramètres.
//

import SwiftUI
import CoreData
import Charts
import SafariServices
import UIKit

// MARK: - Statistiques

private let statPeriods: [(id: String, label: String)] = [
    ("7d", "7 jours"),
    ("30d", "30 jours"),
    ("this_month", "Ce mois"),
    ("6m", "6 mois"),
    ("12m", "12 mois"),
]

struct AdvancedStatsView: View {
    /// Intégré dans `ProfileInsightsView` : pas de `ScrollView` ni titre de navigation propres.
    var embedInParent: Bool = false

    @EnvironmentObject private var syncService: SyncService
    @State private var period: String = "this_month"
    @StateObject private var viewModel = MerchantStatsIndicatorsViewModel()

    var body: some View {
        Group {
            if embedInParent {
                statsColumn
            } else {
                ScrollView {
                    statsColumn
                }
                .background(AppTheme.Colors.background)
                .navigationTitle("Statistiques")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task(id: period) { await viewModel.load(period: period) }
    }

    private var statsColumn: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            headerView
            periodPicker

            if viewModel.isLoading && viewModel.stats == nil {
                MerchantStatsLoadingSkeletonView()
            } else if let error = viewModel.errorMessage, viewModel.stats == nil {
                StatsErrorCard(
                    message: error,
                    onRetry: { Task { await viewModel.load(period: period) } }
                )
            } else if viewModel.isEmptyForPeriod {
                EmptyStatsCard()
            } else {
                kpisSections
                insightCallouts
                if !viewModel.evolution.isEmpty {
                    EvolutionActivityChartView(evolution: viewModel.evolution)
                } else {
                    Text("Tendances indisponibles pour cette période")
                        .font(AppTheme.Fonts.caption2())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .padding(.horizontal)
                        .padding(.top, AppTheme.Spacing.sm)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(.vertical)
    }

    private var periodPicker: some View {
        Picker("Période", selection: $period) {
            ForEach(statPeriods, id: \.id) { p in
                Text(p.label).tag(p.id)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Statistiques")
                .font(AppTheme.Fonts.largeTitle())
                .foregroundStyle(AppTheme.Colors.textPrimary)

            let businessName = viewModel.stats?.businessName?.isEmpty == false ? viewModel.stats?.businessName : nil
            Text(businessName ?? "Votre commerce")
                .font(AppTheme.Fonts.title2())
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if let last = syncService.lastSyncDate {
                Text("Dernière mise à jour : \(last.formatted(date: .numeric, time: .shortened))")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else {
                Text("Mise à jour à la demande")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal)
    }

    private var kpisSections: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            ForEach(viewModel.kpiSections) { section in
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text(section.title)
                        .font(AppTheme.Fonts.headline())
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: MerchantStatsKpiGridLayout.interColumnSpacing),
                            GridItem(.flexible()),
                        ],
                        alignment: .center,
                        spacing: MerchantStatsKpiGridLayout.interRowSpacing
                    ) {
                        ForEach(section.cards) { card in
                            MerchantStatsKpiCardView(model: card)
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                    .padding(.horizontal)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(section.title)
            }
        }
    }

    private var insightCallouts: some View {
        Group {
            if !viewModel.insightCallouts.isEmpty {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                    Text("Comprendre en 30 secondes")
                        .font(AppTheme.Fonts.headline())
                        .padding(.horizontal)
                        .accessibilityAddTraits(.isHeader)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: MerchantStatsKpiGridLayout.interColumnSpacing),
                            GridItem(.flexible()),
                        ],
                        alignment: .center,
                        spacing: MerchantStatsKpiGridLayout.interRowSpacing
                    ) {
                        ForEach(viewModel.insightCallouts) { callout in
                            MerchantStatsInsightCalloutView(model: callout)
                                .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                    .padding(.horizontal)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Comprendre en 30 secondes")
            }
        }
    }
}

/// Graphique d’évolution : vue séparée pour éviter l’erreur « unable to type-check in reasonable time ».
private struct EvolutionActivityChartView: View {
    let evolution: [EvolutionWeekDTO]

    private enum TrendMetric: String, CaseIterable, Identifiable {
        case ops
        case members

        var id: String { rawValue }

        var title: String {
            switch self {
            case .ops: return "Activité (ops)"
            case .members: return "Audience (membres)"
            }
        }
    }

    @State private var metric: TrendMetric = .ops

    private struct Row: Identifiable {
        let id: Int
        let weekLabel: String
        let operations: Int
        let members: Int
    }

    private var rows: [Row] {
        evolution.enumerated().map { index, el in
            let w = (el.weekIndex ?? index) + 1
            return Row(
                id: index,
                weekLabel: "S\(w)",
                operations: el.operationsCount ?? 0,
                members: el.membersCount ?? 0
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Picker("Mode", selection: $metric) {
                ForEach(TrendMetric.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Text(metric == .ops ? "Activité par semaine" : "Audience par semaine")
                .font(AppTheme.Fonts.headline())
                .padding(.horizontal)

            Chart(rows) { row in
                let y: Int = (metric == .ops) ? row.operations : row.members
                BarMark(
                    x: .value("Sem.", row.weekLabel),
                    y: .value(metric == .ops ? "Ops" : "Membres", y)
                )
                .foregroundStyle(AppTheme.Colors.primary.gradient)
            }
            .frame(height: 220)
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Semaine")
                    Spacer()
                    Text("Ops")
                        .frame(width: 44, alignment: .trailing)
                    Text("Membres")
                        .frame(width: 70, alignment: .trailing)
                }
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)

                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(rows) { row in
                        HStack {
                            Text(row.weekLabel)
                                .font(AppTheme.Fonts.caption2())
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                            Spacer()
                            Text(StatsFR.formatInt(row.operations))
                                .font(AppTheme.Fonts.caption2())
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 44, alignment: .trailing)
                            Text(StatsFR.formatInt(row.members))
                                .font(AppTheme.Fonts.caption2())
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tendances : " + (metric == .ops ? "Activité par semaine" : "Audience par semaine"))
    }
}

// MARK: - Error / Empty

private struct StatsErrorCard: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Une erreur est survenue")
                .font(AppTheme.Fonts.headline())

            Text(message)
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                onRetry()
            } label: {
                Text("Réessayer")
                    .font(AppTheme.Fonts.subheadline())
                    .fontWeight(.semibold)
            }
            .commerceStatsLiquidGlassTileButton(cornerRadius: 20, controlSize: .large)
            .accessibilityLabel("Réessayer le chargement des statistiques")
        }
        .padding()
        // Contient déjà un bouton « Réessayer » : pas de `Button` externe (imbrication interdite).
        .commerceStatsDarkLiquidGlassCard(cornerRadius: AppTheme.Radius.md)
        .padding(.horizontal)
    }
}

private struct EmptyStatsCard: View {
    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Aucune donnée pour cette période")
                    .font(AppTheme.Fonts.headline())
                Text("Essayez une autre période ou attendez la prochaine synchronisation.")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .large)
        .padding(.horizontal)
    }
}

private struct MerchantStatsLoadingSkeletonView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<6) { _ in
                    Button(action: {}) {
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.textSecondary.opacity(0.25))
                                .frame(height: 16)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.textSecondary.opacity(0.25))
                                .frame(height: 22)
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.textSecondary.opacity(0.18))
                                .frame(height: 14)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .regular)
                }
            }
            .padding(.horizontal)

            Button(action: {}) {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .fill(Color.clear)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .overlay(
                        ProgressView()
                            .tint(AppTheme.Colors.primary)
                    )
            }
            .padding(.horizontal)
            .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .large)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Callouts

private struct MerchantStatsInsightCalloutView: View {
    let model: MerchantStatsInsightCalloutModel

    var body: some View {
        Button(action: {}) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: model.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)

                    Text(model.title)
                        .font(AppTheme.Fonts.subheadline())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }

                Text(model.dataLine)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(model.nextStep)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .commerceStatsLiquidGlassTileButton(cornerRadius: AppTheme.Radius.md, controlSize: .regular)
        .accessibilityLabel(model.accessibilityLabel)
    }
}

// MARK: - Commerce : stats + calendrier (une seule destination)

/// Fusion indicateurs (membres, points, graphique) et calendrier d’activité hebdomadaire.
struct ProfileInsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService

    @State private var segment = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Vue", selection: $segment) {
                Text("Indicateurs").tag(0)
                Text("Calendrier").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            if segment == 0 {
                ScrollView {
                    AdvancedStatsView(embedInParent: true)
                        .environmentObject(syncService)
                }
            } else {
                CalendarScrollEffectHomeView(context: viewContext)
                    .environmentObject(syncService)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.Colors.background)
        .navigationTitle("Activité & statistiques")
        .navigationBarTitleDisplayMode(.inline)
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
            } header: { Text("Export rapide") }
            footer: {
                Text("Pour un rapport filtré (période, type de mouvement) et un PDF, ouvrez Réglages → Traçabilité & exports.")
                    .font(.caption)
            }
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
            await syncService.syncAfterServerMutation()
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
            let data = try await APIClient.shared.requestCSV(
                .businessTransactionsExport(
                    slug: slug,
                    format: "csv",
                    days: 30,
                    type: nil,
                    types: nil,
                    dateFrom: nil,
                    dateTo: nil,
                    memberId: nil,
                    limit: nil
                )
            )
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

// MARK: - Notifications avancées

/// Conservé pour les liens existants (Commerce, etc.) : même écran que l’onglet **Campagnes**.
struct AdvancedNotificationsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        CampaignNotificationsView(context: viewContext)
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
