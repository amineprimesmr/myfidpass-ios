//
//  MerchantTraceabilityExportView.swift
//  myfidpass
//
//  Exports traçabilité : filtres (période, type, membre), CSV serveur, PDF généré localement.
//

import SwiftUI

struct MerchantTraceabilityExportView: View {
    private enum PeriodChoice: String, CaseIterable, Identifiable {
        case all = "Tout"
        case d7 = "7 jours"
        case d30 = "30 jours"
        case d90 = "90 jours"
        case d365 = "12 mois"
        case custom = "Plage de dates"
        var id: String { rawValue }
    }

    private enum MovementFilter: String, CaseIterable, Identifiable {
        case all = "Tous les mouvements"
        case credits = "Crédits (points / €)"
        case visits = "Passages seuls"
        case rewards = "Récompenses & réductions"
        case corrections = "Corrections caisse"
        case game = "Jeux / tickets"
        var id: String { rawValue }

        /// Valeur du query `types` (API dashboard).
        var typesParameter: String? {
            switch self {
            case .all: return nil
            case .credits: return "points_add"
            case .visits: return "visit"
            case .rewards: return "reward_redeem"
            case .corrections: return "points_correction"
            case .game: return "points_redeem_game_tickets"
            }
        }
    }

    @State private var periodChoice: PeriodChoice = .d30
    @State private var movementFilter: MovementFilter = .all
    @State private var customFrom = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customTo = Date()
    @State private var memberIdFilter = ""
    @State private var exportLimit = 25_000
    @State private var isExportingCsv = false
    @State private var isExportingPdf = false
    @State private var message: String?
    @State private var showShareCsv = false
    @State private var showSharePdf = false
    @State private var csvURL: URL?
    @State private var pdfURL: URL?

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        Form {
            Section {
                Text(
                    "Téléchargez l’historique des opérations fidélité (crédits, passages, récompenses, corrections, jeux). "
                        + "Le CSV convient aux tableurs ; le PDF résume et liste les lignes pour archivage ou contrôle."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Période") {
                Picker("Période", selection: $periodChoice) {
                    ForEach(PeriodChoice.allCases) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                if periodChoice == .custom {
                    DatePicker("Du", selection: $customFrom, displayedComponents: .date)
                    DatePicker("Au", selection: $customTo, displayedComponents: .date)
                }
            }

            Section("Type d’opération") {
                Picker("Filtrer", selection: $movementFilter) {
                    ForEach(MovementFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
            }

            Section("Options") {
                Picker("Lignes max.", selection: $exportLimit) {
                    Text("5 000").tag(5_000)
                    Text("10 000").tag(10_000)
                    Text("25 000").tag(25_000)
                }
                TextField("ID membre (optionnel)", text: $memberIdFilter)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Text("Filtre avancé : identifiant technique du client (UUID). Laissez vide pour tous les clients.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Section("Exporter") {
                Button {
                    Task { await exportCsv() }
                } label: {
                    HStack {
                        Text("Télécharger CSV")
                        Spacer()
                        if isExportingCsv { ProgressView() }
                    }
                }
                .disabled(isExportingCsv || isExportingPdf || !isRangeValid)

                Button {
                    Task { await exportPdf() }
                } label: {
                    HStack {
                        Text("Télécharger PDF")
                        Spacer()
                        if isExportingPdf { ProgressView() }
                    }
                }
                .disabled(isExportingCsv || isExportingPdf || !isRangeValid)
            }

            Section {
                Text("Les montants et libellés reflètent les règles du programme au moment de l’opération. Réessayez une synchro si vous venez de modifier des réglages.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Traçabilité & exports")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Export", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
        .sheet(isPresented: $showShareCsv) {
            if let csvURL {
                ShareSheet(items: [csvURL])
            }
        }
        .sheet(isPresented: $showSharePdf) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
    }

    private var isRangeValid: Bool {
        if periodChoice != .custom { return true }
        return customFrom <= customTo
    }

    private func exportParams() -> (
        days: Int?,
        types: String?,
        dateFrom: String?,
        dateTo: String?,
        memberId: String?
    ) {
        let mid = memberIdFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        let memberId = mid.isEmpty ? nil : mid
        let types = movementFilter.typesParameter

        switch periodChoice {
        case .all:
            return (nil, types, nil, nil, memberId)
        case .d7:
            return (7, types, nil, nil, memberId)
        case .d30:
            return (30, types, nil, nil, memberId)
        case .d90:
            return (90, types, nil, nil, memberId)
        case .d365:
            return (365, types, nil, nil, memberId)
        case .custom:
            let a = Self.dayFormatter.string(from: customFrom)
            let b = Self.dayFormatter.string(from: customTo)
            return (nil, types, a, b, memberId)
        }
    }

    private func makeEndpoint(format: String) -> APIEndpoint? {
        guard let slug = AuthStorage.currentBusinessSlug else { return nil }
        let p = exportParams()
        return .businessTransactionsExport(
            slug: slug,
            format: format,
            days: p.days,
            type: nil,
            types: p.types,
            dateFrom: p.dateFrom,
            dateTo: p.dateTo,
            memberId: p.memberId,
            limit: exportLimit
        )
    }

    private func exportCsv() async {
        guard isRangeValid else {
            message = "La date de fin doit être après la date de début."
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        guard let endpoint = makeEndpoint(format: "csv") else { return }
        isExportingCsv = true
        defer { Task { @MainActor in isExportingCsv = false } }
        do {
            let data = try await APIClient.shared.requestCSV(endpoint)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("transactions-\(slug).csv")
            try data.write(to: url, options: .atomic)
            await MainActor.run {
                csvURL = url
                showShareCsv = true
            }
        } catch {
            await MainActor.run {
                message = (error as? APIError)?.errorDescription ?? "Export CSV impossible."
            }
        }
    }

    private func exportPdf() async {
        guard isRangeValid else {
            message = "La date de fin doit être après la date de début."
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        guard let endpoint = makeEndpoint(format: "json") else { return }
        isExportingPdf = true
        defer { Task { @MainActor in isExportingPdf = false } }
        do {
            let report = try await APIClient.shared.request(endpoint) as TransactionExportJSONResponse
            guard let pdfData = TransactionExportPDFBuilder.pdfData(from: report) else {
                await MainActor.run { message = "Impossible de générer le PDF." }
                return
            }
            let stamp = Self.dayFormatter.string(from: Date())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("rapport-fidelite-\(slug)-\(stamp).pdf")
            try pdfData.write(to: url, options: .atomic)
            await MainActor.run {
                pdfURL = url
                showSharePdf = true
            }
        } catch {
            await MainActor.run {
                message = (error as? APIError)?.errorDescription ?? "Export PDF impossible."
            }
        }
    }
}

#Preview {
    NavigationStack {
        MerchantTraceabilityExportView()
    }
}
