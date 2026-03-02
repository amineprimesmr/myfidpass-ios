//
//  MemberDetailView.swift
//  myfidpass
//
//  Fiche membre : infos (nom, email, points, dernière visite, catégories), actions (catégoriser, ajouter des points).
//

import SwiftUI
import CoreData

struct MemberDetailView: View {
    @ObservedObject var card: ClientCard
    let context: NSManagedObjectContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    @State private var showCategorySheet = false
    @State private var showAddPointsSheet = false
    @State private var pointsToAdd = "1"
    @State private var isAddingPoints = false
    @State private var isRedeeming = false
    @State private var pointsToRedeem = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var template: CardTemplate? { dataService.currentCardTemplate() }
    private var categories: [MemberCategory] {
        guard let t = template else { return [] }
        return dataService.categories(for: t)
    }
    private var memberCategoryNames: [String] {
        (card.categories?.allObjects as? [MemberCategory])?
            .compactMap(\.name)
            .sorted() ?? []
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Nom", value: card.clientDisplayName ?? "—")
                if let email = card.clientEmail, !email.isEmpty {
                    LabeledContent("Email", value: email)
                }
                LabeledContent("Points", value: "\(card.stampsCount)")
                if let date = card.updatedAt {
                    LabeledContent("Dernière visite", value: formattedDate(date))
                }
            } header: {
                Text("Informations")
            }

            if !memberCategoryNames.isEmpty {
                Section("Catégories") {
                    ForEach(memberCategoryNames, id: \.self) { name in
                        Text(name)
                            .font(AppTheme.Fonts.body())
                    }
                }
            }

            Section {
                Button {
                    showCategorySheet = true
                } label: {
                    Label("Catégoriser", systemImage: "folder.badge.gearshape")
                }
                Button {
                    showAddPointsSheet = true
                } label: {
                    Label("Ajouter des points", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Actions")
            }

            if template != nil {
                let required = Int(template!.requiredStamps)
                let hasEnoughStamps = Int(card.stampsCount) >= required && required > 0
                Section {
                    if hasEnoughStamps {
                        Button {
                            redeemStamps()
                        } label: {
                            Label("Utiliser la récompense (tampons)", systemImage: "gift.fill")
                        }
                        .disabled(isRedeeming)
                    }
                    HStack {
                        TextField("Points à déduire", text: $pointsToRedeem)
                            .keyboardType(.numberPad)
                        Button("Utiliser") { redeemPoints() }
                            .disabled(isRedeeming || pointsToRedeem.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Utiliser une récompense")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(card.clientDisplayName ?? "Membre")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCategorySheet) {
            MemberCategoriesSheet(card: card, context: context, categories: categories)
                .environmentObject(syncService)
                .environmentObject(dataService)
        }
        .sheet(isPresented: $showAddPointsSheet) {
            AddPointsSheet(
                memberName: card.clientDisplayName ?? "Membre",
                pointsToAdd: $pointsToAdd,
                isAdding: $isAddingPoints,
                onConfirm: { addPoints() },
                onCancel: { showAddPointsSheet = false }
            )
        }
        .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert("Points ajoutés", isPresented: .constant(successMessage != nil)) {
            Button("OK") {
                successMessage = nil
                showAddPointsSheet = false
            }
        } message: {
            if let msg = successMessage { Text(msg) }
        }
        .refreshable {
            await syncService.syncIfNeeded()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: date)
    }

    private func addPoints() {
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId = card.qrCodeValue else {
            errorMessage = "Commerce non connecté."
            return
        }
        let points = Int(pointsToAdd.trimmingCharacters(in: .whitespaces)) ?? 1
        guard points > 0 else {
            errorMessage = "Indiquez un nombre de points positif."
            return
        }
        isAddingPoints = true
        Task {
            do {
                _ = try await APIClient.shared.request(.addMemberPoints(slug: slug, memberId: memberId, points: points)) as AddMemberPointsResponse
                await MainActor.run {
                    card.stampsCount += Int32(points)
                    card.updatedAt = Date()
                    try? context.save()
                    successMessage = "\(points) point\(points > 1 ? "s" : "") ajouté\(points > 1 ? "s" : "")."
                }
                await syncService.syncIfNeeded()
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d'ajouter les points."
                }
            }
            await MainActor.run { isAddingPoints = false }
        }
    }

    private func redeemStamps() {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = card.qrCodeValue else { return }
        isRedeeming = true
        Task {
            do {
                _ = try await APIClient.shared.request(.redeemReward(slug: slug, memberId: memberId, type: .stamps)) as RedeemResponse
                await MainActor.run {
                    card.stampsCount = 0
                    card.updatedAt = Date()
                    try? context.save()
                    successMessage = "Récompense tampons utilisée."
                }
                await syncService.syncIfNeeded()
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser la récompense." }
            }
            await MainActor.run { isRedeeming = false }
        }
    }

    private func redeemPoints() {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = card.qrCodeValue else { return }
        let value = pointsToRedeem.trimmingCharacters(in: .whitespaces)
        guard let points = Int(value), points > 0 else {
            errorMessage = "Saisissez un nombre de points à déduire."
            return
        }
        isRedeeming = true
        Task {
            do {
                let response = try await APIClient.shared.request(.redeemReward(slug: slug, memberId: memberId, type: .points(pointsToDeduct: points))) as RedeemResponse
                await MainActor.run {
                    if let newPts = response.newPoints {
                        card.stampsCount = Int32(newPts)
                        card.updatedAt = Date()
                        try? context.save()
                    }
                    pointsToRedeem = ""
                    successMessage = "Points utilisés."
                }
                await syncService.syncIfNeeded()
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser les points." }
            }
            await MainActor.run { isRedeeming = false }
        }
    }
}

// MARK: - Sheet catégories (cocher / décocher pour ce membre)

struct MemberCategoriesSheet: View {
    @ObservedObject var card: ClientCard
    let context: NSManagedObjectContext
    let categories: [MemberCategory]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    @State private var selectedIds: Set<String> = []
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categories, id: \.serverId) { cat in
                    let sid = cat.serverId ?? ""
                    Toggle(isOn: Binding(
                        get: { selectedIds.contains(sid) },
                        set: { selectedIds = $0 ? selectedIds.union([sid]) : selectedIds.subtracting([sid]) }
                    )) {
                        HStack(spacing: 8) {
                            if let hex = cat.colorHex, !hex.isEmpty {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 12, height: 12)
                            }
                            Text(cat.name ?? "")
                                .font(AppTheme.Fonts.body())
                        }
                    }
                    .disabled(isSaving)
                }
            }
            .navigationTitle("Catégories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveCategories()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                selectedIds = Set((card.categories?.allObjects as? [MemberCategory])?.compactMap(\.serverId) ?? [])
            }
        }
    }

    private func saveCategories() {
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId = card.qrCodeValue,
              let template = card.template else { return }
        isSaving = true
        let ids = Array(selectedIds)
        Task {
            do {
                _ = try await APIClient.shared.request(.updateMemberCategories(slug: slug, memberId: memberId, categoryIds: ids)) as EmptyResponse
                let newCats = ids.compactMap { dataService.category(byServerId: $0, template: template) }
                await MainActor.run {
                    card.categories = NSSet(array: newCats)
                    try? context.save()
                    dismiss()
                }
                await syncService.syncIfNeeded()
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}

// MARK: - Sheet ajouter des points

struct AddPointsSheet: View {
    let memberName: String
    @Binding var pointsToAdd: String
    @Binding var isAdding: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre de points", text: $pointsToAdd)
                        .keyboardType(.numberPad)
                } header: {
                    Text("Points à ajouter")
                } footer: {
                    Text("Pour \(memberName)")
                }
            }
            .navigationTitle("Ajouter des points")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Valider") {
                        onConfirm()
                    }
                    .disabled(isAdding)
                }
            }
        }
    }
}

// Réponse API POST .../members/:id/points (optionnel, pour décodage si besoin)
struct AddMemberPointsResponse: Decodable {
    let pointsAdded: Int?
    let newBalance: Int?
}
