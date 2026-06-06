//
//  AddStampVisitSheet.swift
//  myfidpass
//
//  Plein écran « Tampon » après scan QR : prénom client, tampons, slider de validation en bas.
//

import SwiftUI

// MARK: - Données (scan programme tampons)

struct ScanStampSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let barcode: String
    let memberName: String
    let cardModel: DashboardHomeCardModel
}

// MARK: - Vue

struct AddStampVisitSheet: View {
    let data: ScanStampSheetData
    @Binding var isSubmitting: Bool
    var onDismiss: () -> Void
    /// Appelé sur le thread principal après crédit tampon réussi, juste avant fermeture de la feuille (toast, etc.).
    var onStampVisitSuccess: (ScanResponse) -> Void
    var onConfirm: () async -> ScanResponse?
    /// Carte pleine : accorder la récompense (QR caisse généré côté commerçant).
    var onGrantReward: () async -> String?

    private let topChrome = MerchantScanSheetTopChrome()
    /// Solde serveur actuel (dernier scan / sync).
    @State private var committedStamps: Int
    /// Recrée le contrôle slide après chaque passage (l’animation « terminé » est réinitialisée).
    @State private var slideResetID = UUID()

    private var model: DashboardHomeCardModel { data.cardModel }
    private var requiredStampsInt: Int { max(1, Int(model.requiredStamps)) }
    private var midRewardLabelTrimmed: String {
        model.stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var finalRewardLabelTrimmed: String {
        model.stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var memberFirstName: String {
        MerchantScanSheetCopy.memberFirstName(from: data.memberName)
    }

    init(
        data: ScanStampSheetData,
        isSubmitting: Binding<Bool>,
        onDismiss: @escaping () -> Void,
        onStampVisitSuccess: @escaping (ScanResponse) -> Void,
        onConfirm: @escaping () async -> ScanResponse?,
        onGrantReward: @escaping () async -> String? = { nil }
    ) {
        self.data = data
        self._isSubmitting = isSubmitting
        self.onDismiss = onDismiss
        self.onStampVisitSuccess = onStampVisitSuccess
        self.onConfirm = onConfirm
        self.onGrantReward = onGrantReward
        let initial = min(max(0, Int(data.cardModel.previewStampsCount)), max(1, Int(data.cardModel.requiredStamps)))
        _committedStamps = State(initialValue: initial)
    }

    /// Carte pleine ou dernier tampon du cycle (ex. 9/10) : accorder la récompense, pas créditer encore.
    private var isCardCompleteForReward: Bool {
        if stampsUntilNextMilestone <= 0 { return true }
        if committedStamps >= requiredStampsInt { return true }
        return committedStamps >= max(1, requiredStampsInt - 1)
    }

    private var balanceCaption: String {
        let total = requiredStampsInt
        let cur = min(max(0, committedStamps), total)
        if isCardCompleteForReward {
            return "Carte complète : \(cur) / \(total) tampons"
        }
        return "Solde actuel : \(cur) / \(total) tampons"
    }

    /// Tampons restants jusqu’au **prochain palier** (5ᵉ si carte > 5 cases, sinon la carte pleine).
    private var stampsUntilNextMilestone: Int {
        let total = requiredStampsInt
        let filled = min(max(0, committedStamps), total)
        if filled >= total { return 0 }
        if total <= 5 {
            return total - filled
        }
        if filled < 5 {
            return 5 - filled
        }
        return total - filled
    }

    /// Nom marchand de la récompense **au prochain palier** (intermédiaire ou finale selon le même découpage que la carte Wallet).
    private var rewardNameAtNextMilestone: String {
        let total = requiredStampsInt
        let filled = min(max(0, committedStamps), total)
        if filled >= total {
            return finalRewardLabelTrimmed.isEmpty ? "Récompense" : finalRewardLabelTrimmed
        }
        if total <= 5 {
            return finalRewardLabelTrimmed.isEmpty ? "Récompense" : finalRewardLabelTrimmed
        }
        if filled < 5 {
            return midRewardLabelTrimmed.isEmpty ? "Récompense intermédiaire" : midRewardLabelTrimmed
        }
        return finalRewardLabelTrimmed.isEmpty ? "Récompense finale" : finalRewardLabelTrimmed
    }

    /// Sur l’écran caisse, le client est **déjà là** : « DANS 1 PASSAGE » faisait croire à un prochain passage. Si un seul tampon manque, c’est **ce** glissement qui débloque le palier.
    private var milestoneRewardLeadLine: String {
        let need = stampsUntilNextMilestone
        if need <= 0 { return "OBJECTIF ATTEINT" }
        if need == 1 { return "RÉCOMPENSE DÉBLOQUÉE" }
        return Self.upperDansPassages(need: need)
    }

    /// Glissement = crédit tampon **et** attribution côté client : wording « offrir » au palier fatidique.
    private var isNextStampUnlocksMilestone: Bool { stampsUntilNextMilestone == 1 }

    private static func upperDansPassages(need: Int) -> String {
        if need <= 0 { return "OBJECTIF ATTEINT" }
        if need == 1 { return "DANS 1 PASSAGE" }
        return "DANS \(need) PASSAGES"
    }

    private var stampNextRewardHero: some View {
        MerchantScanRewardHero(
            leadLine: milestoneRewardLeadLine,
            rewardLabel: rewardNameAtNextMilestone,
            emphasizeLead: isNextStampUnlocksMilestone,
            chrome: topChrome
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let pw = merchantScanSanitizeDimension(proxy.size.width)
                let ph = merchantScanSanitizeDimension(proxy.size.height)
                merchantScanDarkRadialBackground(width: pw, height: ph)
                    .frame(width: pw, height: ph)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let headerTopInset = merchantScanHeaderTopInset(from: geo)
                let bottomPad = max(geo.safeAreaInsets.bottom, 12)

                VStack(spacing: 0) {
                    MerchantScanSheetHeaderBar(
                        title: memberFirstName,
                        subtitle: balanceCaption,
                        onDismiss: onDismiss,
                        chrome: topChrome
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, headerTopInset + 10)

                    CafeDesArtsCardPreview(
                    displayName: model.displayName.isEmpty ? "Ma Carte Fidélité" : model.displayName,
                    requiredStamps: model.requiredStamps,
                    stampsCount: Int32(min(max(0, committedStamps), requiredStampsInt)),
                    primaryColorHex: model.primaryHex,
                    accentColorHex: model.accentHex,
                    stripColorHex: nil,
                    logoURL: model.logoURL,
                    stripDisplayMode: model.stripDisplayMode,
                    stripText: model.stripText.isEmpty ? nil : model.stripText,
                    stampEmoji: model.stampEmoji,
                    cardBackgroundImagePath: nil,
                    cardBackgroundRemoteURL: nil,
                    labelColorHex: model.labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : model.labelHex,
                    headerRightText: model.headerRightText,
                    memberPreviewText: model.memberPreviewText,
                    memberColumnTitle: model.memberColumnTitle,
                    stampMidRewardLabel: model.stampMidRewardLabel,
                    stampRewardLabel: model.stampRewardLabel,
                    restantsCaption: model.labelRestants,
                    compact: true,
                    onEditZoneTap: nil,
                    fidelityQRPayloadURL: model.fidelityQRPayloadURL,
                    stampsOnly: true,
                    stampsOnlyBare: true
                )
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, 20)
                .frame(maxWidth: 420)
                .frame(maxWidth: .infinity)

                stampNextRewardHero

                Spacer(minLength: 8)

                Group {
                    if isCardCompleteForReward {
                        slideToGrantRewardPanel
                    } else {
                        slideToConfirmPanel
                    }
                }
                .padding(.horizontal, 20)
                    .padding(.bottom, bottomPad + 8)
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .ignoresSafeArea(edges: [.top, .bottom])

            if isSubmitting {
                ZStack {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.35)
                        .tint(.white)
                }
                .allowsHitTesting(true)
            }
        }
        .merchantScanFullScreenChrome()
    }

    private var slideToConfirmPanel: some View {
        let unlocks = isNextStampUnlocksMilestone
        let reward = rewardNameAtNextMilestone
        let idle: String = {
            if unlocks {
                if reward.isEmpty { return "Glisser pour offrir la récompense" }
                return "Glisser pour offrir : \(reward)"
            }
            return "Glisser pour créditer 1 tampon"
        }()
        let onSwipe = unlocks ? "Offrir" : "1 tampon"
        let confirm = unlocks ? "Récompense offerte" : "Tampon enregistré"
        let cfg = SlideToConfirm.Config(
            idleText: idle,
            onSwipeText: onSwipe,
            confirmationText: confirm,
            tint: unlocks ? AppTheme.Colors.success : AppTheme.Colors.primary,
            foregroundColor: .white,
            height: MerchantScanSheetTheme.slideHeight,
            knobPadding: 6,
            disabled: isSubmitting
        )
        return SlideToConfirm(config: cfg) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await applySingleStampVisit() }
        }
        .id(slideResetID)
    }

    private var slideToGrantRewardPanel: some View {
        let reward = finalRewardLabelTrimmed.isEmpty ? rewardNameAtNextMilestone : finalRewardLabelTrimmed
        let idle = reward.isEmpty
            ? "Glisser pour accorder la récompense"
            : "Glisser pour accorder : \(reward)"
        let cfg = SlideToConfirm.Config(
            idleText: idle,
            onSwipeText: "Accorder",
            confirmationText: "Récompense accordée",
            tint: AppTheme.Colors.success,
            foregroundColor: .white,
            height: MerchantScanSheetTheme.slideHeight,
            knobPadding: 6,
            disabled: isSubmitting
        )
        return SlideToConfirm(config: cfg) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task { await applyGrantReward() }
        }
        .id(slideResetID)
    }

    private func applyGrantReward() async {
        if let err = await onGrantReward() {
            await MainActor.run { slideResetID = UUID() }
            if !err.isEmpty {
                await MainActor.run {
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
            return
        }
        await MainActor.run { onDismiss() }
    }

    private func applySingleStampVisit() async {
        guard !isCardCompleteForReward else {
            await MainActor.run { slideResetID = UUID() }
            return
        }
        guard let response = await onConfirm() else {
            await MainActor.run { slideResetID = UUID() }
            return
        }
        await MainActor.run {
            let cap = requiredStampsInt
            let raw = response.newBalance ?? response.member?.points
                ?? (committedStamps + (response.pointsAdded ?? 1))
            let normalized = cap > 0 ? Swift.max(0, raw) % cap : Swift.max(0, raw)
            committedStamps = Swift.min(normalized, cap)
            onStampVisitSuccess(response)
            onDismiss()
        }
    }

}

#if DEBUG
#Preview {
    AddStampVisitSheet(
        data: ScanStampSheetData(
            slug: "demo",
            barcode: "00000000-0000-0000-0000-000000000001",
            memberName: "Camille",
            cardModel: DashboardHomeCardModel(
                displayName: "Café des Arts",
                programType: "stamps",
                primaryHex: "1a1a2e",
                accentHex: "eaeaea",
                labelHex: "a0a0a8",
                stripDisplayMode: "logo",
                stripText: "",
                logoURL: nil,
                stampEmoji: "☕️",
                requiredStamps: 8,
                previewStampsCount: 3,
                previewPointsCount: 0,
                cardBackgroundImagePath: nil,
                cardBackgroundRemoteURL: nil,
                headerRightText: "Récompenses ↗",
                memberPreviewText: "Camille",
                labelRestants: "Restants",
                memberColumnTitle: "MEMBRE",
                stampMidRewardLabel: "",
                stampRewardLabel: "-50 %",
                fidelityQRPayloadURL: nil
            )
        ),
        isSubmitting: .constant(false),
        onDismiss: {},
        onStampVisitSuccess: { _ in },
        onConfirm: { nil }
    )
}
#endif
