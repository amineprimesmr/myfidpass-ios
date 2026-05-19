//
//  AddStampVisitSheet.swift
//  myfidpass
//
//  Plein écran « Tampon » après scan QR : même chrome que le crédit points (fond radial, feuille basse),
//  aperçu carte tampons (CafeDesArtsCardPreview) à la place du pavé numérique.
//

import SwiftUI
import UIKit

// MARK: - Données (scan programme tampons)

struct ScanStampSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let barcode: String
    let memberName: String
    let cardModel: DashboardHomeCardModel
}

// MARK: - Thème (aligné sur AddPointsAmountSheet)

private func sanitizeDimension(_ x: CGFloat) -> CGFloat {
    guard x.isFinite, x > 0 else { return 1 }
    return x
}

private enum StampVisitTheme {
    static let keypadBg = Color(red: 242 / 255, green: 242 / 255, blue: 247 / 255)
    static let keypadTopCornerRadius: CGFloat = 52
    static let balanceBadgeTopInLightZone: CGFloat = 8
    static let minLightPanelHeightFloor: CGFloat = 148
}

private struct StampVisitTopChrome {
    var primary: Color { .white }
    var secondary: Color { Color.white.opacity(0.55) }
    var tertiary: Color { Color.white.opacity(0.28) }
    var glassStroke: Color { Color.white.opacity(0.22) }
}

// MARK: - Vue

struct AddStampVisitSheet: View {
    let data: ScanStampSheetData
    @Binding var isSubmitting: Bool
    var onDismiss: () -> Void
    /// Appelé sur le thread principal après crédit tampon réussi, juste avant fermeture de la feuille (toast, etc.).
    var onStampVisitSuccess: (ScanResponse) -> Void
    var onConfirm: () async -> ScanResponse?

    @Environment(\.colorScheme) private var colorScheme

    private let topChrome = StampVisitTopChrome()
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

    init(
        data: ScanStampSheetData,
        isSubmitting: Binding<Bool>,
        onDismiss: @escaping () -> Void,
        onStampVisitSuccess: @escaping (ScanResponse) -> Void,
        onConfirm: @escaping () async -> ScanResponse?
    ) {
        self.data = data
        self._isSubmitting = isSubmitting
        self.onDismiss = onDismiss
        self.onStampVisitSuccess = onStampVisitSuccess
        self.onConfirm = onConfirm
        let initial = min(max(0, Int(data.cardModel.previewStampsCount)), max(1, Int(data.cardModel.requiredStamps)))
        _committedStamps = State(initialValue: initial)
    }

    private var balanceCaption: String {
        let total = requiredStampsInt
        let cur = min(max(0, committedStamps), total)
        if cur >= total {
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
        let lead = milestoneRewardLeadLine
        let reward = rewardNameAtNextMilestone
        return VStack(alignment: .center, spacing: 10) {
            Text(lead)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(isNextStampUnlocksMilestone ? topChrome.primary.opacity(0.95) : topChrome.secondary)
                .multilineTextAlignment(.center)
            Text(reward)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.96, blue: 0.78),
                            Color(red: 0.98, green: 0.82, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(3)
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                let pw = sanitizeDimension(proxy.size.width)
                let ph = sanitizeDimension(proxy.size.height)
                stampVisitDarkRadialBackground(width: pw, height: ph)
                    .frame(width: pw, height: ph)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let w = sanitizeDimension(geo.size.width)
                let h = sanitizeDimension(geo.size.height)
                let bottomInset = geo.safeAreaInsets.bottom
                let bottomPad = max(bottomInset, 12)
                let layoutH = h + bottomInset
                let headerTopInset: CGFloat = {
                    let g = geo.safeAreaInsets.top
                    if g >= 12 { return g }
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
                        return max(g, win.safeAreaInsets.top)
                    }
                    return max(g, 47)
                }()

                let minLightNeeded = StampVisitTheme.balanceBadgeTopInLightZone + 24 + 64 + bottomPad + 18
                let minLight = max(StampVisitTheme.minLightPanelHeightFloor, minLightNeeded)

                let darkFloor: CGFloat = {
                    let header: CGFloat = 48
                    let caption: CGFloat = 88
                    let cardApprox: CGFloat = min(w * 0.5, 240)
                    let verticalPad: CGFloat = 20
                    return header + caption + cardApprox + verticalPad
                }()

                let darkCoreMax = max(0, layoutH - headerTopInset - minLight)
                let darkCoreH = min(darkCoreMax, darkFloor + 120)
                let darkColumnH = headerTopInset + darkCoreH
                let lightColumnH = max(1, layoutH - darkColumnH)
                let sheetH = max(1, lightColumnH - StampVisitTheme.balanceBadgeTopInLightZone)

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        stampHeaderBar
                            .padding(.horizontal, 12)
                            .padding(.top, headerTopInset + 10)

                        Text(balanceCaption)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundStyle(topChrome.primary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 22)
                            .padding(.top, 14)
                            .padding(.bottom, 6)

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
                            cardBackgroundImagePath: CardLogoStorage.resolvedDisplayPath(forStoredPath: model.cardBackgroundImagePath),
                            cardBackgroundRemoteURL: model.cardBackgroundRemoteURL,
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
                            stampsOnly: true
                        )
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, 4)
                        .frame(maxWidth: min(w * 0.92, 400))
                        .frame(maxWidth: .infinity)

                        stampNextRewardHero

                        Spacer(minLength: 8)
                    }
                    .frame(width: w, height: darkColumnH)
                    .background {
                        stampVisitDarkRadialBackground(width: w, height: darkColumnH)
                    }
                    .clipped()

                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: StampVisitTheme.balanceBadgeTopInLightZone)

                        ZStack(alignment: .bottom) {
                            UnevenRoundedRectangle(
                                cornerRadii: RectangleCornerRadii(
                                    topLeading: StampVisitTheme.keypadTopCornerRadius,
                                    bottomLeading: 0,
                                    bottomTrailing: 0,
                                    topTrailing: StampVisitTheme.keypadTopCornerRadius
                                ),
                                style: .continuous
                            )
                            .fill(StampVisitTheme.keypadBg)
                            .frame(width: w, height: sheetH)

                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                if committedStamps < requiredStampsInt {
                                    slideToConfirmPanel
                                        .padding(.horizontal, 16)
                                        .padding(.bottom, bottomPad + 10)
                                }
                            }
                            .frame(width: w, height: sheetH, alignment: .bottom)
                        }
                        .frame(width: w, height: sheetH, alignment: .top)
                    }
                    .frame(width: w, height: lightColumnH, alignment: .top)
                }
                .frame(width: w, height: layoutH)
            }
            .ignoresSafeArea(edges: [.bottom, .top])

            if isSubmitting {
                ZStack {
                    Color(UIColor.tertiarySystemBackground)
                        .opacity(colorScheme == .light ? 0.88 : 0.5)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.35)
                        .tint(AppTheme.Colors.primary)
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var stampHeaderBar: some View {
        HStack(spacing: 0) {
            Group {
                if #available(iOS 26.0, *) {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(topChrome.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.circle)
                    .accessibilityLabel("Annuler")
                } else {
                    Button(action: onDismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(topChrome.primary)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .overlay {
                                        Circle()
                                            .strokeBorder(topChrome.glassStroke, lineWidth: 1)
                                    }
                            }
                    }
                    .accessibilityLabel("Annuler")
                }
            }

            VStack(spacing: 3) {
                Text("Aperçu Wallet")
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .foregroundStyle(topChrome.primary)
                Text(data.memberName)
                    .font(.system(size: 13, weight: .medium, design: .default))
                    .foregroundStyle(topChrome.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
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
            height: 56,
            disabled: isSubmitting
        )
        return VStack(alignment: .leading, spacing: 8) {
            Text(unlocks ? "Offrir la récompense" : "Valider le passage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            SlideToConfirm(config: cfg) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                Task { await applySingleStampVisit() }
            }
            .id(slideResetID)
            Text(
                unlocks
                    ? "Ce passage crédite le tampon du palier et attribue la récompense au client."
                    : "Un seul tampon par glissement, comme un scan en caisse."
            )
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
        }
        .padding(14)
        .background(Color.white.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
        )
    }

    private func applySingleStampVisit() async {
        let previousBalance = await MainActor.run { committedStamps }
        guard previousBalance < requiredStampsInt else {
            await MainActor.run { slideResetID = UUID() }
            return
        }
        guard let response = await onConfirm() else {
            await MainActor.run { slideResetID = UUID() }
            return
        }
        await MainActor.run {
            onStampVisitSuccess(response)
            onDismiss()
        }
    }

}

// MARK: - Fond (identique à AddPointsAmountSheet)

private func stampVisitDarkRadialBackground(width: CGFloat, height: CGFloat) -> some View {
    let dim = max(width, height)
    let endR = dim * 1.02
    let startR = dim * 0.06
    return ZStack {
        Color(red: 0.005, green: 0.007, blue: 0.012)
        RadialGradient(
            colors: [
                Color(red: 0.09, green: 0.095, blue: 0.13),
                Color(red: 0.055, green: 0.058, blue: 0.078),
                Color(red: 0.032, green: 0.035, blue: 0.048),
                Color(red: 0.018, green: 0.02, blue: 0.032),
                Color(red: 0.01, green: 0.012, blue: 0.022),
                Color(red: 0.004, green: 0.006, blue: 0.014)
            ],
            center: UnitPoint(x: 0.5, y: 0.08),
            startRadius: startR,
            endRadius: endR
        )
        RadialGradient(
            colors: [
                Color(red: 0.16, green: 0.168, blue: 0.215),
                Color(red: 0.07, green: 0.075, blue: 0.095),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.035),
            startRadius: 4,
            endRadius: dim * 0.52
        )
        .blendMode(.plusLighter)
        .opacity(0.32)
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
