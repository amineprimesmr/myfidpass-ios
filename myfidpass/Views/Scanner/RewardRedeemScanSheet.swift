//
//  RewardRedeemScanSheet.swift
//  myfidpass
//
//  Validation caisse d’un QR « Utiliser en magasin » — plein écran aligné sur AddStampVisitSheet.
//

import SwiftUI

struct ScanRewardRedeemSheetData: Identifiable {
    let id = UUID()
    let slug: String
    let memberId: String
    let memberName: String
    let barcode: String
    let rewardLabel: String
    let pointsRequired: Int
    let pointsBalance: Int
    let eligible: Bool
    let mode: String
    let tierIndex: Int?
    let tierImageURL: String?
}

/// Parse le payload `MYFIDPASS_REDEEM` (aligné backend `reward-redeem-qr.js`).
enum RewardRedeemQRPayload {
    case points(memberId: String, tierIndex: Int, points: Int)
    /// `stampThreshold` nil = carte complète ; sinon palier intermédiaire (ex. 5 tampons).
    case stamps(memberId: String, stampThreshold: Int?)

    private static let prefix = "MYFIDPASS_REDEEM:"

    var encodedPoints: Int? {
        switch self {
        case .points(_, _, let pts): return pts
        case .stamps: return nil
        }
    }

    /// QR caisse « carte complète » (sans palier intermédiaire).
    static func fullCardBarcode(memberId: String) -> String {
        let id = memberId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "MYFIDPASS_REDEEM:1:\(id):s"
    }

    /// QR caisse « début du jeu » (`:s:0`) — Boisson offerte, distinct de la carte complète (`:s`).
    static func startGameBarcode(memberId: String) -> String {
        let id = memberId.trimmingCharacters(in: .whitespacesAndNewlines)
        return "MYFIDPASS_REDEEM:1:\(id):s:0"
    }

    /// QR caisse palier tampons intermédiaire (ex. 5 tampons).
    static func stampTierBarcode(memberId: String, threshold: Int) -> String {
        let id = memberId.trimmingCharacters(in: .whitespacesAndNewlines)
        let th = max(1, threshold)
        return "MYFIDPASS_REDEEM:1:\(id):s:\(th)"
    }

    static func parse(_ raw: String) -> RewardRedeemQRPayload? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.uppercased().hasPrefix(prefix.uppercased()) else { return nil }
        let rest = String(s.dropFirst(prefix.count))
        let parts = rest.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 3, Int(parts[0]) == 1 else { return nil }
        let memberId = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !memberId.isEmpty else { return nil }
        let mode = parts[2].lowercased()
        if mode == "s" {
            var stampThreshold: Int?
            if parts.count >= 4 {
                if parts[3] == "0" {
                    stampThreshold = 0
                } else if let t = Int(parts[3]), t > 0 {
                    stampThreshold = t
                }
            }
            return .stamps(memberId: memberId, stampThreshold: stampThreshold)
        }
        if mode == "p", parts.count >= 5,
           let tierIndex = Int(parts[3]), tierIndex >= 0,
           let points = Int(parts[4]), points > 0 {
            return .points(memberId: memberId, tierIndex: tierIndex, points: points)
        }
        return nil
    }
}

enum ScanRewardRedeemSheetDataBuilder {
    /// Fusionne lookup API + payload QR (les points du QR priment si l’API renvoie 0 à cause d’un index palier décalé).
    static func make(
        slug: String,
        barcode: String,
        memberName: String,
        memberId: String,
        lookup: ScanLookupResponse
    ) -> ScanRewardRedeemSheetData? {
        guard let preview = lookup.rewardRedeem,
              let apiLabel = preview.label?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiLabel.isEmpty
        else { return nil }

        let qr = RewardRedeemQRPayload.parse(barcode)
        var pointsRequired = preview.pointsRequired ?? 0
        if pointsRequired <= 0, let qrPts = qr?.encodedPoints, qrPts > 0 {
            pointsRequired = qrPts
        }
        if pointsRequired <= 0, case .stamps(_, let th?) = qr {
            pointsRequired = th
        }
        let balance = preview.pointsBalance ?? lookup.member.points ?? 0
        let eligible: Bool = {
            if let api = preview.eligible { return api }
            if pointsRequired == 0 { return true }
            guard pointsRequired > 0 else { return false }
            return balance >= pointsRequired
        }()

        return ScanRewardRedeemSheetData(
            slug: slug,
            memberId: memberId,
            memberName: memberName,
            barcode: barcode,
            rewardLabel: apiLabel,
            pointsRequired: pointsRequired,
            pointsBalance: balance,
            eligible: eligible,
            mode: preview.mode ?? "points",
            tierIndex: preview.tierIndex,
            tierImageURL: preview.tierImageURL
        )
    }
}

struct RewardRedeemScanSheet: View {
    let data: ScanRewardRedeemSheetData
    let onDismiss: () -> Void
    /// `nil` = succès ; sinon message d’erreur affiché dans la feuille.
    let onRedeem: () async -> String?

    @State private var loading = false
    @State private var errorMessage: String?
    @State private var validated = false
    @State private var slideResetID = UUID()

    private let topChrome = MerchantScanSheetTopChrome()

    private var memberFirstName: String {
        MerchantScanSheetCopy.memberFirstName(from: data.memberName)
    }

    private var balanceCaption: String {
        if data.mode == "stamps" {
            if data.pointsRequired == 0 {
                return "Début du jeu · offert"
            }
            return "\(data.pointsBalance) tampon\(data.pointsBalance > 1 ? "s" : "") · objectif \(data.pointsRequired)"
        }
        return "Coût : \(data.pointsRequired) pts · Solde : \(data.pointsBalance) pts"
    }

    private var heroLeadLine: String {
        if validated { return "RÉCOMPENSE VALIDÉE" }
        if !data.eligible { return "NON ÉLIGIBLE" }
        return "À VALIDER EN CAISSE"
    }

    private var canSlideToRedeem: Bool {
        data.eligible
            && !validated
            && !loading
            && (data.mode == "stamps" || data.pointsRequired > 0)
    }

    private var qrTierIndex: Int? {
        guard let qrPayload else { return nil }
        if case .points(_, let tier, _) = qrPayload { return tier }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                merchantScanDarkRadialBackground(
                    width: merchantScanSanitizeDimension(proxy.size.width),
                    height: merchantScanSanitizeDimension(proxy.size.height)
                )
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
                    .disabled(loading)

                    rewardGiftIcon
                        .padding(.top, 24)

                    MerchantScanRewardHero(
                        leadLine: heroLeadLine,
                        rewardLabel: data.rewardLabel,
                        emphasizeLead: data.eligible && !validated,
                        chrome: topChrome
                    )

                    if let errorMessage {
                        statusMessage(errorMessage, tint: .red)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else if !data.eligible {
                        statusMessage(ineligibleMessage, tint: topChrome.secondary)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                    } else if data.pointsRequired <= 0, data.mode != "stamps" {
                        statusMessage(
                            "Coût invalide (0 pts). Demandez au client de régénérer le QR depuis sa carte.",
                            tint: Color.orange
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 8)

                    if canSlideToRedeem {
                        slideFooter
                            .padding(.horizontal, 20)
                            .padding(.bottom, bottomPad + 8)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .ignoresSafeArea(edges: [.top, .bottom])

            if loading {
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

    private var ineligibleMessage: String {
        if data.mode == "stamps" {
            return "Pas assez de tampons pour valider cette récompense."
        }
        return "Solde insuffisant : il manque \(max(0, data.pointsRequired - data.pointsBalance)) pts."
    }

    private var rewardGiftIcon: some View {
        RewardGiftImageView(
            tierIndex: data.tierIndex,
            mode: data.mode,
            pointsRequired: data.pointsRequired,
            qrTierIndex: qrTierIndex,
            customImageURL: data.tierImageURL,
            size: 96
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, y: 5)
        .accessibilityLabel(data.rewardLabel)
    }

    private func statusMessage(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(tint)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private var slideFooter: some View {
        let idle = "Glisser pour valider la récompense"
        let cfg = SlideToConfirm.Config(
            idleText: idle,
            onSwipeText: "Valider",
            confirmationText: "Récompense validée",
            tint: AppTheme.Colors.success,
            foregroundColor: .white,
            height: MerchantScanSheetTheme.slideHeight,
            knobPadding: 6,
            disabled: !canSlideToRedeem
        )
        return SlideToConfirm(config: cfg) {
            guard canSlideToRedeem else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Task {
                loading = true
                errorMessage = nil
                if let err = await onRedeem() {
                    errorMessage = err
                    loading = false
                    slideResetID = UUID()
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                } else {
                    validated = true
                    loading = false
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    onDismiss()
                }
            }
        }
        .id(slideResetID)
    }
}
