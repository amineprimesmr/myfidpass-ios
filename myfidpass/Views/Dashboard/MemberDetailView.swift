//
//  MemberDetailView.swift
//  myfidpass
//
//  Fiche client — DA type « gestion d’abonnement » (Wallet / Réglages iOS).
//

import SwiftUI
import CoreData
import UIKit

// MARK: - Palette (alignée captures Wallet / Abonnements)

/// Sélection pour présenter la fiche client en sheet (pas plein écran).
struct MemberDetailSheetItem: Identifiable {
    let objectID: NSManagedObjectID
    var id: String { objectID.uriRepresentation().absoluteString }
}

private enum MemberProfileWalletStyle {
    static let card = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let cardStroke = Color.white.opacity(0.06)
    static let primaryText = Color.white
    static let secondaryText = Color(red: 142 / 255, green: 142 / 255, blue: 147 / 255)
    static let accentBlue = Color(red: 10 / 255, green: 132 / 255, blue: 255 / 255)
    static let destructive = Color(red: 255 / 255, green: 69 / 255, blue: 58 / 255)
    static let avatarFill = Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255)
    static let rowIconFill = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
    static let cornerRadius: CGFloat = 18
    static let sheetCornerRadius: CGFloat = 36
}

private struct MemberProfileWalletGradientBackground: View {
    var body: some View {
        GeometryReader { geo in
            let dim = max(geo.size.width, geo.size.height, 1)
            ZStack {
                Color(red: 0.005, green: 0.007, blue: 0.012)
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.13, blue: 0.18),
                        Color(red: 0.07, green: 0.075, blue: 0.10),
                        Color(red: 0.035, green: 0.038, blue: 0.052),
                        Color(red: 0.012, green: 0.014, blue: 0.022),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.08),
                    startRadius: 6,
                    endRadius: dim * 0.92
                )
                RadialGradient(
                    colors: [
                        Color(red: 0.20, green: 0.22, blue: 0.30).opacity(0.5),
                        Color.clear,
                    ],
                    center: UnitPoint(x: 0.5, y: 0),
                    startRadius: 4,
                    endRadius: dim * 0.42
                )
            }
        }
    }
}

private struct MemberDetailSheetContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct MemberDetailSheetChromeModifier: ViewModifier {
    @State private var contentHeight: CGFloat = 360

    private var fittedDetentHeight: CGFloat {
        let screenH = UIScreen.main.bounds.height
        let chromePadding: CGFloat = 28
        let minH: CGFloat = 300
        let maxH = screenH * 0.92
        return min(max(contentHeight + chromePadding, minH), maxH)
    }

    private var presentationDetents: Set<PresentationDetent> {
        let screenH = UIScreen.main.bounds.height
        let fitted = PresentationDetent.height(fittedDetentHeight)
        if contentHeight + 28 > screenH * 0.78 {
            return [fitted, .large]
        }
        return [fitted]
    }

    @ViewBuilder
    private func coreChrome(_ content: Content) -> some View {
        content
            .onPreferenceChange(MemberDetailSheetContentHeightKey.self) { height in
                guard height > 0, abs(height - contentHeight) > 2 else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    contentHeight = height
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                MemberProfileWalletGradientBackground()
                    .ignoresSafeArea()
            }
            .presentationDetents(presentationDetents)
            .presentationDragIndicator(.hidden)
            .presentationBackground {
                MemberProfileWalletGradientBackground()
                    .ignoresSafeArea()
            }
    }

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            // iOS 26 : rayon fixe → sheet « flottante » avec marges gauche/droite/bas.
            coreChrome(content)
                .presentationCornerRadius(nil)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        } else if #available(iOS 18, *) {
            // iOS 18+ : `.form` par défaut = marges latérales ; `.page` = pleine largeur.
            coreChrome(content)
                .presentationSizing(.page)
                .presentationCornerRadius(MemberProfileWalletStyle.sheetCornerRadius)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        } else {
            coreChrome(content)
                .presentationCornerRadius(MemberProfileWalletStyle.sheetCornerRadius)
                .ignoresSafeArea(edges: [.horizontal, .bottom])
        }
    }
}

extension View {
    /// Sheet pleine largeur : pas de tiret, fond bord à bord (gauche / droite / bas).
    func memberDetailSheetChrome() -> some View {
        modifier(MemberDetailSheetChromeModifier())
    }
}

struct MemberDetailView: View {
    @ObservedObject var card: ClientCard
    let context: NSManagedObjectContext
    @FetchRequest private var stamps: FetchedResults<Stamp>
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var dataService: DataService

    @State private var memberPointsAmountFlow: MemberPointsAmountFlow?
    @State private var isMemberPointsAmountSubmitting = false
    @StateObject private var receiptCoordinator = ReceiptValidationCoordinator()
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var successAlertTitle = "Succès"
    @State private var grantedRewards: [MemberGameRewardDTO] = []
    @State private var isLoadingRewards = false
    @State private var claimingGrantId: String?
    @State private var isSyncingHistory = false
    @State private var showDeleteConfirm = false
    @State private var showAllTransactions = false
    @State private var isDeletingMember = false

    private let memberQueryKey: String
    private var template: CardTemplate? { dataService.currentCardTemplate() }

    private var resolvedMemberId: String? {
        let q = card.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !q.isEmpty { return q }
        let c = card.clientIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return c.isEmpty ? nil : c
    }

    private var displayName: String {
        let n = card.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return n.isEmpty ? "Client" : n
    }

    private var pointsBalance: Int { Int(card.stampsCount) }

    private var visibleStamps: [Stamp] {
        let all = Array(stamps)
        if showAllTransactions { return all }
        return Array(all.prefix(5))
    }

    private var transactionsPointsSummary: String {
        let values = stamps.compactMap { MerchantTransactionEventLabels.parsePoints(fromStampNote: $0.note) }
        guard !values.isEmpty else { return "—" }
        let sum = values.reduce(0, +)
        if sum > 0 { return "+\(sum) pts" }
        if sum < 0 { return "−\(abs(sum)) pts" }
        return "0 pt"
    }

    private var giftRewards: [MemberGameRewardDTO] {
        grantedRewards.filter { $0.reward?.kind == "gift" }
    }

    private var giftRewardsCount: Int { giftRewards.count }

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
        ZStack {
            MemberProfileWalletGradientBackground()
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection
                        .padding(.top, 12)

                    VStack(spacing: 14) {
                        pointsActionsRow
                        contactCard
                        if giftRewardsCount > 0 || isLoadingRewards {
                            giftsCard
                        }
                        transactionsSection
                        deleteMemberSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: MemberDetailSheetContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
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
        .alert("Supprimer ce client ?", isPresented: $showDeleteConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Supprimer", role: .destructive) {
                Task { await deleteMemberOnServer() }
            }
        } message: {
            Text("Cette action retire le client et son historique de votre commerce. Irréversible.")
        }
        .task {
            await syncMemberHistoryAndDashboard()
            await loadGiftRewards()
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            MemberProfileAvatarDisc(name: displayName, size: 72)

            Text(displayName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(MemberProfileWalletStyle.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 24)

            Text(pointsBalance == 1 ? "1 point" : "\(pointsBalance) points")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MemberProfileWalletStyle.primaryText)

            Text(memberSinceHeroLabel)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MemberProfileWalletStyle.secondaryText)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var memberSinceHeroLabel: String {
        if let created = card.createdAt {
            return "Membre depuis \(formattedCardDate(created))"
        }
        return "Membre fidélité"
    }

    // MARK: - Actions points

    private var pointsActionsRow: some View {
        HStack(spacing: 12) {
            MemberProfilePointsGlassButton(
                title: "Ajouter",
                systemImage: "plus",
                tint: MemberProfileWalletStyle.accentBlue,
                action: { prepareMemberPointsFlow(mode: .credit) }
            )
            MemberProfilePointsGlassButton(
                title: "Retirer",
                systemImage: "minus",
                tint: Color(red: 1, green: 0.55, blue: 0.26),
                action: { prepareMemberPointsFlow(mode: .debit) }
            )
        }
    }

    // MARK: - Cartes infos

    @ViewBuilder
    private var contactCard: some View {
        if let email = card.clientEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            MemberProfileWalletCard {
                MemberProfileLinkRow(label: "E-mail", value: email) {
                    if let url = URL(string: "mailto:\(email)") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
    }

    private var giftsCard: some View {
        MemberProfileWalletCard {
            if isLoadingRewards {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Chargement des cadeaux…")
                        .font(.system(size: 15))
                        .foregroundStyle(MemberProfileWalletStyle.secondaryText)
                }
                .padding(.vertical, 4)
            } else {
                ForEach(Array(giftRewards.enumerated()), id: \.element.id) { index, grant in
                    if index > 0 { MemberProfileCardDivider() }
                    MemberProfileGiftRow(
                        grant: grant,
                        isClaiming: claimingGrantId == grant.grantId,
                        onClaim: {
                            if let grantId = grant.grantId {
                                Task { await claimGiftReward(grantId: grantId) }
                            }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Transactions

    private var transactionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Transactions")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MemberProfileWalletStyle.primaryText)
                Spacer()
                if isSyncingHistory {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(MemberProfileWalletStyle.secondaryText)
                } else {
                    Text(transactionsPointsSummary)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MemberProfileWalletStyle.secondaryText)
                }
            }
            .padding(.horizontal, 4)

            if stamps.isEmpty, !isSyncingHistory {
                Text("Aucune transaction pour le moment.")
                    .font(.system(size: 14))
                    .foregroundStyle(MemberProfileWalletStyle.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
            } else {
                MemberProfileWalletCard {
                    ForEach(Array(visibleStamps.enumerated()), id: \.element.objectID) { index, stamp in
                        MemberProfileTransactionRow(
                            title: transactionTitle(for: stamp),
                            date: stamp.createdAt.map { formattedTransactionDate($0) } ?? "—",
                            amount: transactionAmount(for: stamp),
                            memberInitials: memberInitials
                        )
                        if index < visibleStamps.count - 1 {
                            Divider()
                                .overlay(MemberProfileWalletStyle.cardStroke)
                                .padding(.leading, 56)
                        }
                    }

                    if stamps.count > 5 {
                        MemberProfileCardDivider()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllTransactions.toggle()
                            }
                        } label: {
                            Text(showAllTransactions ? "Réduire" : "Tout afficher")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(MemberProfileWalletStyle.primaryText)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var deleteMemberSection: some View {
        MemberProfilePointsGlassButton(
            title: "Supprimer ce client",
            systemImage: "trash",
            tint: MemberProfileWalletStyle.destructive,
            emphasizeTint: true,
            isLoading: isDeletingMember,
            action: { showDeleteConfirm = true }
        )
        .disabled(isDeletingMember)
        .padding(.top, 6)
    }

    private var memberInitials: String {
        MemberProfileAvatarDisc.initials(from: displayName)
    }

    private func transactionTitle(for stamp: Stamp) -> String {
        let full = DataService.memberStampEventTitle(note: stamp.note)
        if let dot = full.firstIndex(of: "·") {
            return String(full[..<dot]).trimmingCharacters(in: .whitespaces)
        }
        return full
    }

    private func transactionAmount(for stamp: Stamp) -> String {
        MerchantTransactionEventLabels.dashboardAmountLine(
            type: MerchantTransactionEventLabels.parseType(fromStampNote: stamp.note),
            points: MerchantTransactionEventLabels.parsePoints(fromStampNote: stamp.note),
            isVisit: MerchantTransactionEventLabels.parseVisit(fromStampNote: stamp.note),
            isPointsProgram: memberDetailProgramIsPoints,
            rewardLabel: MerchantTransactionEventLabels.parseRewardLabel(fromStampNote: stamp.note),
            amountEur: MerchantTransactionEventLabels.parseAmountEur(fromStampNote: stamp.note),
            pointsPerEuro: memberDetailPointsPerEuro
        )
    }

    private var memberDetailProgramIsPoints: Bool {
        let slug = AuthStorage.currentBusinessSlug ?? ""
        let raw = slug.isEmpty ? nil : CardPreviewDisplaySnapshotStore.load(slug: slug)?.programType
        return (raw ?? "points").lowercased() == "points"
    }

    private var memberDetailPointsPerEuro: Int? {
        let slug = AuthStorage.currentBusinessSlug ?? ""
        guard !slug.isEmpty else { return nil }
        let ppe = ScanFlowSettingsCache.cached(for: slug)?.pointsPerEuro ?? 0
        return ppe > 0 ? ppe : nil
    }

    // MARK: - Dates

    private func formattedCardDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return f.string(from: date)
    }

    private func formattedTransactionDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.setLocalizedDateFormatFromTemplate("d MMM")
        return f.string(from: date)
    }

    // MARK: - Points (même flux que scan QR)

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
            }
        )
    }

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
                ) as RemoveMemberPointsResponse
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

    // MARK: - Sync

    private func syncMemberHistoryAndDashboard() async {
        await MainActor.run { isSyncingHistory = true }
        defer { Task { @MainActor in isSyncingHistory = false } }
        await performMemberHistoryAndDashboardSync(
            memberId: resolvedMemberId,
            syncService: syncService,
            dataService: dataService
        )
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

    private func deleteMemberOnServer() async {
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId = resolvedMemberId, !memberId.isEmpty else {
            await MainActor.run { errorMessage = "Impossible de supprimer ce client." }
            return
        }
        await MainActor.run { isDeletingMember = true }
        defer { Task { @MainActor in isDeletingMember = false } }
        do {
            _ = try await APIClient.shared.request(.deleteDashboardMember(slug: slug, memberId: memberId)) as EmptyResponse
            await MainActor.run {
                context.delete(card)
                try? context.save()
                dataService.invalidateActivityPreviewCache()
                dismiss()
            }
            await syncService.syncAfterServerMutation()
        } catch {
            await MainActor.run {
                errorMessage = APIError.merchantFacingMessage(from: error) ?? "Suppression impossible."
            }
        }
    }
}

// MARK: - Composants DA Wallet

private struct MemberProfileWalletCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: MemberProfileWalletStyle.cornerRadius, style: .continuous)
                .fill(MemberProfileWalletStyle.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: MemberProfileWalletStyle.cornerRadius, style: .continuous)
                .strokeBorder(MemberProfileWalletStyle.cardStroke, lineWidth: 1)
        )
    }
}

private struct MemberProfileCardDivider: View {
    var body: some View {
        Divider()
            .overlay(MemberProfileWalletStyle.cardStroke)
            .padding(.vertical, 10)
    }
}

private struct MemberProfilePointsGlassButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var emphasizeTint: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    private var titleColor: Color {
        if isLoading || emphasizeTint { return tint }
        return MemberProfileWalletStyle.primaryText
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(tint)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(tint)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(titleColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
        }
        .modifier(MemberProfilePointsGlassButtonStyle())
    }
}

private struct MemberProfilePointsGlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.roundedRectangle(radius: 16))
        } else {
            content
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 16)
        }
    }
}

private struct MemberProfileLinkRow: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.system(size: 17))
                    .foregroundStyle(MemberProfileWalletStyle.primaryText)
                Spacer(minLength: 8)
                Text(value)
                    .font(.system(size: 17))
                    .foregroundStyle(MemberProfileWalletStyle.accentBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

private struct MemberProfileAvatarDisc: View {
    let name: String
    let size: CGFloat

    static func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map { String($0).uppercased() } }
        if letters.isEmpty {
            return String(name.prefix(1)).uppercased()
        }
        return letters.joined()
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(MemberProfileWalletStyle.avatarFill)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
            Text(Self.initials(from: name))
                .font(.system(size: size * 0.34, weight: .bold))
                .foregroundStyle(MemberProfileWalletStyle.primaryText)
        }
    }
}

private struct MemberProfileTransactionRow: View {
    let title: String
    let date: String
    let amount: String
    let memberInitials: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(MemberProfileWalletStyle.rowIconFill)
                    .frame(width: 40, height: 40)
                Text(memberInitials)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MemberProfileWalletStyle.primaryText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MemberProfileWalletStyle.primaryText)
                    .lineLimit(1)
                Text(date)
                    .font(.system(size: 14))
                    .foregroundStyle(MemberProfileWalletStyle.secondaryText)
            }

            Spacer(minLength: 8)

            Text(amount)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MemberProfileWalletStyle.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 12)
    }
}

private struct MemberProfileGiftRow: View {
    let grant: MemberGameRewardDTO
    let isClaiming: Bool
    let onClaim: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(grant.displayLabel)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MemberProfileWalletStyle.primaryText)
                Text(grant.status == "claimed" ? "Remis au client" : "À remettre")
                    .font(.system(size: 14))
                    .foregroundStyle(grant.status == "claimed" ? Color.green.opacity(0.85) : MemberProfileWalletStyle.secondaryText)
            }
            Spacer()
            if grant.status != "claimed" {
                Button(action: onClaim) {
                    if isClaiming {
                        ProgressView().tint(MemberProfileWalletStyle.accentBlue)
                    } else {
                        Text("Remis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(MemberProfileWalletStyle.accentBlue)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isClaiming)
            }
        }
        .padding(.vertical, 10)
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

