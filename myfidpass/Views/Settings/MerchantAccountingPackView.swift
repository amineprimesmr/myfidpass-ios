//
//  MerchantAccountingPackView.swift
//  myfidpass
//
//  Pack comptable : tout est calculé côté serveur (paliers, libellés, paniers, règles programme).
//

import SwiftUI

struct MerchantAccountingPackView: View {
    private enum PeriodChoice: String, CaseIterable, Identifiable {
        case all = "Tout"
        case d7 = "7 jours"
        case d30 = "30 jours"
        case d90 = "90 jours"
        case d365 = "12 mois"
        case custom = "Plage de dates"
        var id: String { rawValue }
    }

    @State private var periodChoice: PeriodChoice = .d30
    @State private var customFrom = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    @State private var customTo = Date()
    @State private var exportLimit = 25_000

    @State private var isDownloading = false
    @State private var message: String?
    @State private var shareURLs: [URL] = []
    @State private var showShare = false

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
                    "Le serveur construit automatiquement les montants indicatifs à partir de votre carte "
                        + "(libellés des paliers et tampons, points/€, panier moyen déclaré, crédits avec montant sur la période). "
                        + "Aucun champ à remplir : choisissez la période puis exportez les fichiers pour votre comptable."
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
                Picker("Lignes max. (grand livre)", selection: $exportLimit) {
                    Text("5 000").tag(5_000)
                    Text("10 000").tag(10_000)
                    Text("25 000").tag(25_000)
                }
            }

            Section {
                Button {
                    Task { await downloadPack() }
                } label: {
                    HStack {
                        Text("Générer et partager le pack")
                        Spacer()
                        if isDownloading { ProgressView() }
                    }
                }
                .disabled(isDownloading || !isRangeValid)
            }

            Section {
                Text("Indicateurs non audités — à valider avec votre expert-comptable.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Pack comptable")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Pack comptable", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
        }
        .sheet(isPresented: $showShare) {
            if !shareURLs.isEmpty {
                ShareSheet(items: shareURLs)
            }
        }
    }

    private var isRangeValid: Bool {
        if periodChoice != .custom { return true }
        return customFrom <= customTo
    }

    private func exportParams() -> (days: Int?, dateFrom: String?, dateTo: String?) {
        switch periodChoice {
        case .all:
            return (nil, nil, nil)
        case .d7:
            return (7, nil, nil)
        case .d30:
            return (30, nil, nil)
        case .d90:
            return (90, nil, nil)
        case .d365:
            return (365, nil, nil)
        case .custom:
            let a = Self.dayFormatter.string(from: customFrom)
            let b = Self.dayFormatter.string(from: customTo)
            return (nil, a, b)
        }
    }

    private func downloadPack() async {
        guard isRangeValid else {
            message = "La date de fin doit être après la date de début."
            return
        }
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        let p = exportParams()
        let endpoint = APIEndpoint.businessAccountingPack(
            slug: slug,
            days: p.days,
            dateFrom: p.dateFrom,
            dateTo: p.dateTo,
            limit: exportLimit
        )
        isDownloading = true
        defer { Task { @MainActor in isDownloading = false } }
        do {
            let pack = try await APIClient.shared.request(endpoint) as MerchantAccountingPackResponse
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("pack-comptable-\(slug)-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var urls: [URL] = []
            for f in pack.files {
                guard let data = f.contentUtf8?.data(using: .utf8) else { continue }
                let name = f.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { continue }
                let url = folder.appendingPathComponent(name)
                try data.write(to: url, options: .atomic)
                urls.append(url)
            }
            guard !urls.isEmpty else {
                await MainActor.run { message = "Réponse vide du serveur." }
                return
            }
            await MainActor.run {
                shareURLs = urls
                showShare = true
            }
        } catch {
            await MainActor.run {
                message = (error as? APIError)?.errorDescription ?? "Téléchargement impossible."
            }
        }
    }
}

#Preview {
    NavigationStack {
        MerchantAccountingPackView()
    }
}
