//
//  MemberDetailView.swift
//  myfidpass
//
//  Fiche membre : infos, historique, actions (crédit / correction points, tampons, cadeaux roue).
//

import SwiftUI
import CoreData

struct MemberDetailView: View {
    @ObservedObject var card: ClientCard
    let context: NSManagedObjectContext
    @FetchRequest private var stamps: FetchedResults<Stamp>
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService
    /// Même UX plein écran que après scan QR (`AddPointsAmountSheet`).
    @State private var memberPointsAmountFlow: MemberPointsAmountFlow?
    @State private var isMemberPointsAmountSubmitting = false
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    @State private var isRedeeming = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var successAlertTitle = "Succès"
    @State private var grantedRewards: [MemberGameRewardDTO] = []
    @State private var isLoadingRewards = false
    @State private var claimingGrantId: String?
    @State private var isSyncingHistory = false
    private let memberQueryKey: String
    private var template: CardTemplate? { dataService.currentCardTemplate() }

    /// Identifiant serveur du membre (sync : `qrCodeValue` ; repli `clientIdentifier`).
    private var resolvedMemberId: String? {
        let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !q.isEmpty { return q }
        let c = card.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return c.isEmpty ? nil : c
    }
    init(card: ClientCard, context: NSManagedObjectContext) {
        _card = ObservedObject(wrappedValue: card)
        self.context = context
        let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let c = card.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        memberQueryKey = !q.isEmpty ? q : c
        if !memberQueryKey.isEmpty, let template = card.template {
            _stamps = FetchRequest<Stamp>(
                sortDescriptors: [SortDescriptor(\Stamp.createdAt, order: .reverse)],
                predicate: NSPredicate(format: "clientCard.qrCodeValue == %@ AND clientCard.template == %@", memberQueryKey, template)
            )
        } else {
            _stamps = FetchRequest<Stamp>(
                sortDescriptors: [SortDescriptor(\Stamp.createdAt, order: .reverse)],
                predicate: NSPredicate(format: "clientCard == %@", card)
            )
        }
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
                if isSyncingHistory {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Synchronisation de l’historique…")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                if let created = card.createdAt {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nouveau membre")
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
                if !stamps.isEmpty {
                    Text("\(stamps.count) opération\(stamps.count > 1 ? "s" : "") synchronisée\(stamps.count > 1 ? "s" : "") depuis le serveur.")
                        .font(AppTheme.Fonts.caption())
                } else if stamps.isEmpty, card.createdAt != nil {
                    Text("Les mouvements de points et passages synchronisés apparaissent ici.")
                        .font(AppTheme.Fonts.caption())
                }
            }

            Section {
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

            if let template, Int(template.requiredStamps) > 0, Int(card.stampsCount) >= Int(template.requiredStamps) {
                Section {
                    Button {
                        redeemStamps()
                    } label: {
                        Label("Utiliser la récompense (tampons)", systemImage: "gift.fill")
                    }
                    .disabled(isRedeeming)
                } header: {
                    Text("Utiliser une récompense")
                }
            }

            let giftGrants = grantedRewards.filter { $0.reward?.kind == "gift" }
            if !giftGrants.isEmpty || isLoadingRewards {
                Section {
                    if isLoadingRewards {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Chargement…")
                                .font(AppTheme.Fonts.body())
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    } else {
                        ForEach(giftGrants) { grant in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(grant.displayLabel)
                                        .font(AppTheme.Fonts.body().weight(.semibold))
                                    if grant.status == "claimed" {
                                        Text("Remis au client")
                                            .font(AppTheme.Fonts.caption())
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("À remettre")
                                            .font(AppTheme.Fonts.caption())
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                                Spacer()
                                if grant.status != "claimed" {
                                    Button {
                                        if let grantId = grant.grantId {
                                            Task { await claimGiftReward(grantId: grantId) }
                                        }
                                    } label: {
                                        if claimingGrantId == grant.grantId {
                                            ProgressView()
                                        } else {
                                            Text("Remis")
                                                .font(AppTheme.Fonts.body().weight(.semibold))
                                                .foregroundStyle(AppTheme.Colors.accent)
                                        }
                                    }
                                    .disabled(claimingGrantId != nil)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Cadeaux roue (à remettre)")
                } footer: {
                    Text("Cadeaux gagnés par ce membre sur la roue. Appuyez sur « Remis » une fois le cadeau donné.")
                }
            }

        }
        .listStyle(.insetGrouped)
        .navigationTitle(card.clientDisplayName ?? "Membre")
        .navigationBarTitleDisplayMode(.inline)
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
            await syncMemberHistoryAndDashboard()
            await loadGiftRewards()
        }
        .task {
            await syncMemberHistoryAndDashboard()
            await loadGiftRewards()
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
            scanMaxPointsPerTransaction: flow.data.scanMaxPointsPerTransaction,
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

    private func syncMemberHistoryAndDashboard() async {
        await MainActor.run { isSyncingHistory = true }
        defer { Task { @MainActor in isSyncingHistory = false } }
        await performMemberHistoryAndDashboardSync(
            memberId: resolvedMemberId,
            syncService: syncService,
            dataService: dataService
        )
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
                    pointsMinAmountEur: settings.pointsMinAmountEur,
                    scanMaxPointsPerTransaction: settings.scanMaxPointsPerTransaction
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
                await syncMemberHistoryAndDashboard()
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
                await syncMemberHistoryAndDashboard()
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
                await syncMemberHistoryAndDashboard()
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
                    await syncMemberHistoryAndDashboard()
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
                await syncMemberHistoryAndDashboard()
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
                await syncMemberHistoryAndDashboard()
            } catch {
                await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? "Impossible d'utiliser la récompense." }
            }
            await MainActor.run { isRedeeming = false }
        }
    }

    private func loadGiftRewards() async {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = resolvedMemberId else { return }
        await MainActor.run { isLoadingRewards = true }
        do {
            let response: MemberRewardsListResponse = try await APIClient.shared.request(.memberRewardsList(slug: slug, memberId: memberId))
            await MainActor.run {
                grantedRewards = response.rewards
                isLoadingRewards = false
            }
        } catch {
            await MainActor.run { isLoadingRewards = false }
        }
    }

    private func claimGiftReward(grantId: String) async {
        guard let slug = AuthStorage.currentBusinessSlug, let memberId = resolvedMemberId else { return }
        await MainActor.run { claimingGrantId = grantId }
        do {
            _ = try await APIClient.shared.request(.claimMemberReward(slug: slug, memberId: memberId, grantId: grantId)) as ClaimRewardResponse
            await MainActor.run {
                if let idx = grantedRewards.firstIndex(where: { $0.grantId == grantId }) {
                    let old = grantedRewards[idx]
                    grantedRewards[idx] = MemberGameRewardDTO(grantId: old.grantId, status: "claimed", reward: old.reward)
                }
                claimingGrantId = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? "Impossible de valider ce cadeau."
                claimingGrantId = nil
            }
        }
    }
}

// MARK: - Sync historique fiche membre

@MainActor
private func performMemberHistoryAndDashboardSync(
    memberId: String?,
    syncService: SyncService,
    dataService: DataService
) async {
    let mid = memberId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    if !mid.isEmpty {
        await syncService.syncMemberTransactionHistory(memberId: mid)
        dataService.invalidateActivityPreviewCache()
    }
    await syncService.syncAfterServerMutation()
}

/// Réponse POST .../members/:id/points ou .../points/remove
struct AddMemberPointsResponse: Decodable {
    let id: String?
    let points: Int?
    let pointsAdded: Int?
    let pointsRemoved: Int?
}
