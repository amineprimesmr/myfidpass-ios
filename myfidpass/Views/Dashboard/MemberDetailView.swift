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
    @FetchRequest private var stamps: FetchedResults<Stamp>
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    @Environment(\.dismiss) private var dismiss
    @State private var showCategorySheet = false
    /// Même UX plein écran que après scan QR (`AddPointsAmountSheet`).
    @State private var memberPointsAmountFlow: MemberPointsAmountFlow?
    @State private var isMemberPointsAmountSubmitting = false
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    @State private var isRedeeming = false
    @State private var pointsToRedeem = ""
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var successAlertTitle = "Succès"
    @State private var showDeleteMemberConfirm = false
    @State private var isDeletingMember = false
    private var template: CardTemplate? { dataService.currentCardTemplate() }

    /// Identifiant serveur du membre (sync : `qrCodeValue` ; repli `clientIdentifier`).
    private var resolvedMemberId: String? {
        let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !q.isEmpty { return q }
        let c = card.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return c.isEmpty ? nil : c
    }
    private var categories: [MemberCategory] {
        guard let t = template else { return [] }
        return dataService.categories(for: t)
    }
    private var memberCategoryNames: [String] {
        (card.categories?.allObjects as? [MemberCategory])?
            .compactMap(\.name)
            .sorted() ?? []
    }

    init(card: ClientCard, context: NSManagedObjectContext) {
        _card = ObservedObject(wrappedValue: card)
        self.context = context
        _stamps = FetchRequest<Stamp>(
            sortDescriptors: [SortDescriptor(\Stamp.createdAt, order: .forward)],
            predicate: NSPredicate(format: "clientCard == %@", card)
        )
    }

    var body: some View {
        let _ = dataService.updateTrigger
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

            Section {
                if let created = card.createdAt {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Carte créée")
                            .font(AppTheme.Fonts.body().weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text(formattedDate(created))
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                if stamps.isEmpty, card.createdAt == nil {
                    Text("Aucune activité enregistrée. Tirez pour synchroniser : l’historique vient des transactions du serveur.")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                ForEach(Array(stamps), id: \.objectID) { stamp in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(DataService.memberStampEventTitle(note: stamp.note))
                            .font(AppTheme.Fonts.body())
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        if let d = stamp.createdAt {
                            Text(formattedDate(d))
                                .font(AppTheme.Fonts.caption())
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            } header: {
                Text("Historique des transactions")
            } footer: {
                if stamps.isEmpty, card.createdAt != nil {
                    Text("Les mouvements de points et passages synchronisés apparaissent ici.")
                        .font(AppTheme.Fonts.caption())
                }
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
                    prepareMemberPointsFlow(mode: .credit)
                } label: {
                    Label("Ajouter des points", systemImage: "plus.circle.fill")
                }
                Button {
                    prepareMemberPointsFlow(mode: .debit)
                } label: {
                    Label("Retirer des points (correction)", systemImage: "minus.circle.fill")
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

            Section {
                Button(role: .destructive) {
                    showDeleteMemberConfirm = true
                } label: {
                    Label("Supprimer ce membre et sa carte", systemImage: "trash")
                }
                .disabled(isDeletingMember)
            } header: {
                Text("Zone de danger")
            } footer: {
                Text("Supprime le client sur le serveur (carte Wallet, points, historique). Irréversible.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(card.clientDisplayName ?? "Membre")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCategorySheet) {
            MemberCategoriesSheet(card: card, context: context, categories: categories)
                .environmentObject(syncService)
                .environmentObject(dataService)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .modifier(LiquidGlassSheetModifier())
        }
        .fullScreenCover(item: $memberPointsAmountFlow) { flow in
            memberPointsAmountSheet(for: flow)
        }
        .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
        .alert(successAlertTitle, isPresented: .constant(successMessage != nil)) {
            Button("OK") {
                successMessage = nil
                memberPointsAmountFlow = nil
            }
        } message: {
            if let msg = successMessage { Text(msg) }
        }
        .refreshable {
            await syncService.syncAfterServerMutation()
        }
        .alert("Supprimer définitivement ce membre ?", isPresented: $showDeleteMemberConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                Task { await deleteMemberOnServer() }
            }
        } message: {
            Text("La carte Wallet du client ne sera plus valide. Action irréversible.")
        }
    }

    /// Découpe l’initialisation d’`AddPointsAmountSheet` : le ternaire sur `onRedeemTier` faisait échouer l’inférence Swift (« Failed to produce diagnostic »).
    @ViewBuilder
    private func memberPointsAmountSheet(for flow: MemberPointsAmountFlow) -> some View {
        AddPointsAmountSheet(
            mode: flow.mode,
            memberName: flow.data.memberName,
            barcode: flow.data.barcode,
            pointsPerEuro: flow.data.pointsPerEuro,
            memberPoints: flow.data.memberPoints,
            rewardTiers: flow.data.rewardTiers,
            pointsMinAmountEur: flow.data.pointsMinAmountEur,
            isSubmitting: $isMemberPointsAmountSubmitting,
            receiptCoordinator: receiptCoordinator,
            onDismiss: { memberPointsAmountFlow = nil },
            onSubmit: { amount in
                await submitMemberPointsAmount(amount: amount, flow: flow)
            },
            onRedeemTier: makeRedeemTierHandler(for: flow)
        )
    }

    private func makeRedeemTierHandler(for flow: MemberPointsAmountFlow) -> ((ScanRewardTier, Double) async -> Int?)? {
        guard flow.mode == .credit, !flow.data.rewardTiers.isEmpty else { return nil }
        let data = flow.data
        return { tier, amount in
            await redeemOrCreditAndRedeem(tier: tier, amountEur: amount, data: data)
        }
    }

    private func deleteMemberOnServer() async {
        guard let slug = AuthStorage.currentBusinessSlug,
              let raw = resolvedMemberId, !raw.isEmpty else {
            await MainActor.run { errorMessage = "Identifiant membre manquant." }
            return
        }
        await MainActor.run { isDeletingMember = true }
        defer { Task { @MainActor in isDeletingMember = false } }
        do {
            _ = try await APIClient.shared.request(.deleteDashboardMember(slug: slug, memberId: raw)) as EmptyResponse
            await MainActor.run {
                dataService.deleteClientCard(card)
                dismiss()
            }
            await syncService.syncAfterServerMutation()
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Suppression impossible."
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: date)
    }

    /// Charge les règles du programme puis ouvre le même plein écran que le scan QR.
    private func prepareMemberPointsFlow(mode: AddPointsAmountMode) {
        guard let slug = AuthStorage.currentBusinessSlug,
              let barcode = resolvedMemberId, !barcode.isEmpty else {
            errorMessage = "Commerce non connecté ou membre sans identifiant."
            return
        }
        Task {
            do {
                let settings: BusinessSettingsResponse
                if let cached = ScanFlowSettingsCache.cached(for: slug) {
                    settings = cached
                    Task.detached(priority: .utility) {
                        do {
                            let fresh = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                            ScanFlowSettingsCache.store(fresh, for: slug)
                        } catch { }
                    }
                } else {
                    settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                    ScanFlowSettingsCache.store(settings, for: slug)
                }
                let tierDTOs = settings.pointsRewardTiers ?? []
                let rewardTiers = tierDTOs
                    .filter { $0.points > 0 }
                    .map { ScanRewardTier(points: $0.points, label: $0.label.isEmpty ? "Récompense" : $0.label) }
                    .sorted { $0.points < $1.points }
                let data = ScanResultSheetData(
                    slug: slug,
                    memberName: card.clientDisplayName ?? "Client",
                    barcode: barcode,
                    pointsPerEuro: settings.pointsPerEuro ?? 1,
                    memberPoints: Int(card.stampsCount),
                    rewardTiers: rewardTiers,
                    pointsMinAmountEur: settings.pointsMinAmountEur
                )
                await MainActor.run {
                    memberPointsAmountFlow = MemberPointsAmountFlow(data: data, mode: mode)
                }
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Impossible de charger les règles du programme."
                }
            }
        }
    }

    @discardableResult
    private func submitMemberPointsAmount(amount: Double, flow: MemberPointsAmountFlow) async -> Bool {
        let d = flow.data
        let ppe = max(1, d.pointsPerEuro)
        var pts = 0
        if amount > 0 {
            if let minEur = d.pointsMinAmountEur, amount < minEur - 1e-9 {
                await MainActor.run {
                    errorMessage = "Montant sous le minimum défini pour ce commerce."
                }
                return false
            }
            pts = Int(floor(amount * Double(ppe)))
        }
        switch flow.mode {
        case .credit:
            guard pts > 0 else { return false }
            isMemberPointsAmountSubmitting = true
            defer { Task { @MainActor in isMemberPointsAmountSubmitting = false } }
            do {
                let settings: BusinessSettingsResponse
                if let c = ScanFlowSettingsCache.cached(for: d.slug) {
                    settings = c
                } else {
                    settings = try await APIClient.shared.request(.businessSettings(slug: d.slug)) as BusinessSettingsResponse
                    ScanFlowSettingsCache.store(settings, for: d.slug)
                }
                var receiptTok: String?
                if (settings.requireReceiptQrValidation ?? 0) == 1, amount > 0 {
                    guard let t = try await receiptCoordinator.requestValidatedToken(slug: d.slug, amountEur: amount) else {
                        await MainActor.run { errorMessage = "Scan du ticket de caisse annulé." }
                        return false
                    }
                    receiptTok = t
                }
                let response: ScanResponse = try await APIClient.shared.request(
                    .scan(
                        slug: d.slug,
                        barcode: d.barcode,
                        visit: false,
                        points: nil,
                        amountEur: amount,
                        receiptValidationToken: receiptTok
                    )
                )
                await MainActor.run {
                    if let bal = response.newBalance {
                        card.stampsCount = Int32(bal)
                    } else if let p = response.member?.points {
                        card.stampsCount = Int32(p)
                    } else {
                        card.stampsCount += Int32(response.pointsAdded ?? pts)
                    }
                    card.updatedAt = Date()
                    try? context.save()
                    let added = response.pointsAdded ?? pts
                    successAlertTitle = "Points ajoutés"
                    successMessage = "\(added) point\(added > 1 ? "s" : "") ajouté\(added > 1 ? "s" : "")."
                    memberPointsAmountFlow = nil
                }
                await syncService.syncAfterServerMutation()
                return true
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Crédit impossible."
                }
                return false
            }
        case .debit:
            let before = Int(card.stampsCount)
            let remove = min(pts, before)
            guard remove > 0 else {
                await MainActor.run {
                    errorMessage = "Aucun point à retirer pour ce montant."
                }
                return false
            }
            isMemberPointsAmountSubmitting = true
            defer { Task { @MainActor in isMemberPointsAmountSubmitting = false } }
            do {
                let response = try await APIClient.shared.request(
                    .removeMemberPoints(slug: d.slug, memberId: d.barcode, points: remove)
                ) as AddMemberPointsResponse
                await MainActor.run {
                    if let bal = response.points {
                        card.stampsCount = Int32(bal)
                    } else {
                        card.stampsCount = Int32(max(0, before - remove))
                    }
                    card.updatedAt = Date()
                    try? context.save()
                    let removed = response.pointsRemoved ?? remove
                    successAlertTitle = "Points retirés"
                    successMessage = "\(removed) point\(removed > 1 ? "s" : "") retiré\(removed > 1 ? "s" : "") (correction)."
                    memberPointsAmountFlow = nil
                }
                await syncService.syncAfterServerMutation()
                return true
            } catch {
                await MainActor.run {
                    errorMessage = (error as? APIError)?.errorDescription ?? "Retrait impossible."
                }
                return false
            }
        }
    }

    /// Utiliser un palier depuis l’écran montant : redeem seul si solde suffisant, sinon crédit du panier puis redeem.
    private func redeemOrCreditAndRedeem(tier: ScanRewardTier, amountEur: Double, data: ScanResultSheetData) async -> Int? {
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId = resolvedMemberId, !memberId.isEmpty else {
            await MainActor.run { errorMessage = "Commerce non connecté ou membre sans identifiant." }
            return nil
        }
        let before = Int(card.stampsCount)
        let ppe = max(1, data.pointsPerEuro)
        var earned = 0
        if amountEur > 0 {
            if let minEur = data.pointsMinAmountEur, amountEur < minEur - 1e-9 {
                await MainActor.run { errorMessage = "Montant sous le minimum défini pour ce commerce." }
                return nil
            }
            earned = Int(floor(amountEur * Double(ppe)))
        }
        let after = before + earned

        func performRedeem() async throws -> RedeemResponse {
            try await APIClient.shared.request(
                .redeemReward(slug: slug, memberId: memberId, type: .points(pointsToDeduct: tier.points))
            ) as RedeemResponse
        }

        do {
            if before >= tier.points {
                let response = try await performRedeem()
                let newP = response.newPoints ?? max(0, before - tier.points)
                await MainActor.run {
                    card.stampsCount = Int32(newP)
                    card.updatedAt = Date()
                    try? context.save()
                }
                await syncService.syncAfterServerMutation()
                return newP
            }
            if earned > 0, after >= tier.points {
                let settings: BusinessSettingsResponse
                if let c = ScanFlowSettingsCache.cached(for: slug) {
                    settings = c
                } else {
                    settings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
                    ScanFlowSettingsCache.store(settings, for: slug)
                }
                var receiptTok: String?
                if (settings.requireReceiptQrValidation ?? 0) == 1, amountEur > 0 {
                    guard let t = try await receiptCoordinator.requestValidatedToken(slug: slug, amountEur: amountEur) else {
                        await MainActor.run { errorMessage = "Scan du ticket de caisse annulé." }
                        return nil
                    }
                    receiptTok = t
                }
                let creditResponse: ScanResponse = try await APIClient.shared.request(
                    .scan(
                        slug: slug,
                        barcode: data.barcode,
                        visit: false,
                        points: nil,
                        amountEur: amountEur,
                        receiptValidationToken: receiptTok
                    )
                )
                let credited = creditResponse.newBalance
                    ?? creditResponse.member?.points
                    ?? (before + (creditResponse.pointsAdded ?? earned))
                guard credited >= tier.points else {
                    await MainActor.run {
                        card.stampsCount = Int32(credited)
                        card.updatedAt = Date()
                        try? context.save()
                        errorMessage = "Solde encore insuffisant après crédit."
                    }
                    await syncService.syncAfterServerMutation()
                    return nil
                }
                await MainActor.run {
                    card.stampsCount = Int32(credited)
                    card.updatedAt = Date()
                    try? context.save()
                }
                let redeemResponse = try await performRedeem()
                let finalP = redeemResponse.newPoints ?? max(0, credited - tier.points)
                await MainActor.run {
                    card.stampsCount = Int32(finalP)
                    card.updatedAt = Date()
                    try? context.save()
                }
                await syncService.syncAfterServerMutation()
                return finalP
            }
            await MainActor.run {
                errorMessage = "Créditez d’abord assez de points pour ce palier (\(tier.points) pts), ou augmentez le montant du panier."
            }
            return nil
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d’appliquer la récompense."
            }
            return nil
        }
    }

    private func redeemStamps() {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = resolvedMemberId else { return }
        isRedeeming = true
        Task {
            do {
                _ = try await APIClient.shared.request(.redeemReward(slug: slug, memberId: memberId, type: .stamps)) as RedeemResponse
                await MainActor.run {
                    card.stampsCount = 0
                    card.updatedAt = Date()
                    try? context.save()
                    successAlertTitle = "Récompense"
                    successMessage = "Récompense tampons utilisée."
                }
                await syncService.syncAfterServerMutation()
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser la récompense." }
            }
            await MainActor.run { isRedeeming = false }
        }
    }

    private func redeemPoints() {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = resolvedMemberId else { return }
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
                    successAlertTitle = "Récompense"
                    successMessage = "Points utilisés."
                }
                await syncService.syncAfterServerMutation()
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
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if #available(iOS 26.0, *) {
                        Button("Annuler") { dismiss() }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.regular)
                    } else {
                        Button("Annuler") { dismiss() }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                    Spacer(minLength: 8)
                    Text("Catégories")
                        .font(.headline.weight(.semibold))
                    Spacer(minLength: 8)
                    if #available(iOS 26.0, *) {
                        Button("Enregistrer") {
                            saveCategories()
                        }
                        .disabled(isSaving)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                        .tint(AppTheme.Colors.primary)
                    } else {
                        Button("Enregistrer") {
                            saveCategories()
                        }
                        .disabled(isSaving)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

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
            }
            .sheetHideNavigationBar()
            .onAppear {
                selectedIds = Set((card.categories?.allObjects as? [MemberCategory])?.compactMap(\.serverId) ?? [])
            }
        }
    }

    private func saveCategories() {
        let memberId = (card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? card.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId, !memberId.isEmpty,
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
                await syncService.syncAfterServerMutation()
            } catch {
                await MainActor.run { isSaving = false }
            }
        }
    }
}

/// Réponse POST .../members/:id/points ou .../points/remove
struct AddMemberPointsResponse: Decodable {
    let id: String?
    let points: Int?
    let pointsAdded: Int?
    let pointsRemoved: Int?
}
