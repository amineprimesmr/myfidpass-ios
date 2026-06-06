//
//  RewardRedeemScanSheet.swift
//  myfidpass
//
//  Validation caisse d’un QR « Utiliser en magasin » — plein écran opaque, une seule source de vérité (lookup API).
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
            tierIndex: preview.tierIndex
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

    private var displayMemberName: String {
        let n = data.memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Client" : n
    }

    private var qrPayload: RewardRedeemQRPayload? {
        RewardRedeemQRPayload.parse(data.barcode)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            memberHeader
                            rewardHeroCard
                            balanceRow
                            if let errorMessage {
                                errorBanner(errorMessage)
                            }
                            if validated {
                                successBanner
                            }
                            qrVerificationSection
                            if !data.eligible {
                                ineligibleBanner
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }

                    if data.eligible, !validated {
                        slideFooter
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                            .background {
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .ignoresSafeArea(edges: .bottom)
                            }
                    }
                }
            }
            .navigationTitle("Récompense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer", action: onDismiss)
                        .disabled(loading)
                }
            }
        }
        .presentationBackground(Color(.systemGroupedBackground))
        .interactiveDismissDisabled(loading || validated)
    }

    // MARK: - Sections

    private var memberHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.primary.opacity(0.14))
                    .frame(width: 52, height: 52)
                Text(memberInitials)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(displayMemberName)
                    .font(.title2.weight(.bold))
                Text("Récompense à valider en caisse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var memberInitials: String {
        let parts = displayMemberName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }
        if letters.isEmpty { return "?" }
        return letters.joined()
    }

    private var rewardHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(data.rewardLabel)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "gift.fill")
                    .font(.title2)
                    .foregroundStyle(Color(red: 1, green: 0.55, blue: 0.2))
            }

            if data.mode == "stamps" {
                Text("Programme tampons")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if data.pointsRequired == 0 {
                    Text("Début du jeu · offert")
                        .font(.title3.weight(.bold))
                } else {
                    Text("\(data.pointsBalance) tampon\(data.pointsBalance > 1 ? "s" : "") · objectif \(data.pointsRequired)")
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }
            } else {
                HStack(spacing: 0) {
                    costColumn(title: "Coût", value: data.pointsRequired, suffix: "pts")
                    Divider().frame(height: 44)
                    costColumn(title: "Solde client", value: data.pointsBalance, suffix: "pts")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func costColumn(title: String, value: Int, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(value)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(value > 0 ? Color.primary : Color.orange)
                Text(suffix)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var balanceRow: some View {
        Group {
            if data.pointsRequired <= 0, data.mode != "stamps" {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Le coût en points est invalide (0). Demandez au client de régénérer le QR depuis sa carte.")
                        .font(.footnote)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var qrVerificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("QR scanné")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 16) {
                if let img = QRCodeGenerator.generateQR(from: data.barcode, size: 88) {
                    Image(uiImage: img)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .padding(8)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 6) {
                    if let qrPayload {
                        switch qrPayload {
                        case .points(_, let tier, let pts):
                            Text("Palier #\(tier + 1) · \(pts) pts encodés")
                                .font(.footnote.weight(.medium))
                        case .stamps(_, let th):
                            if th == 0 {
                                Text("Récompense · Début du jeu")
                                    .font(.footnote.weight(.medium))
                            } else if let th, th > 0 {
                                Text("Palier tampons · \(th) tampon\(th > 1 ? "s" : "") encodés")
                                    .font(.footnote.weight(.medium))
                            } else {
                                Text("Récompense tampons (carte complète)")
                                    .font(.footnote.weight(.medium))
                            }
                        }
                    } else {
                        Text("Format QR non reconnu — utilisez « Utiliser en magasin » sur la carte client.")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                    Text("Une seule validation par scan.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var ineligibleBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.secondary)
            Text(
                data.mode == "stamps"
                    ? "Pas assez de tampons pour valider cette récompense."
                    : "Solde insuffisant : il manque \(max(0, data.pointsRequired - data.pointsBalance)) pts."
            )
            .font(.subheadline)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
            Text(text)
                .font(.footnote)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Récompense validée")
                    .font(.headline)
                Text("\(displayMemberName) — \(data.rewardLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var slideFooter: some View {
        let cfg = SlideToConfirm.Config(
            idleText: "Glisser pour valider la récompense",
            onSwipeText: "Valider",
            confirmationText: "Récompense validée",
            tint: AppTheme.Colors.primary,
            foregroundColor: .white,
            height: 56,
            disabled: loading || (data.pointsRequired <= 0 && data.mode != "stamps") || (data.mode == "stamps" && data.pointsRequired < 0)
        )
        return SlideToConfirm(config: cfg) {
            guard !loading else { return }
            Task {
                loading = true
                errorMessage = nil
                if let err = await onRedeem() {
                    errorMessage = err
                    loading = false
                } else {
                    validated = true
                    loading = false
                    try? await Task.sleep(nanoseconds: 900_000_000)
                    onDismiss()
                }
            }
        }
        .padding(.top, 12)
    }
}
