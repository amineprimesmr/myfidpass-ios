//
//  CardPreviewSnapshotBuilder.swift
//  myfidpass
//
//  Construction / réparation du snapshot d’aperçu carte (aligné Android CardPreviewSnapshotSync).
//

import Foundation

enum CardPreviewSnapshotBuilder {

    /// Snapshot depuis GET settings — paliers points via la même logique que « Ma carte ».
    static func fromSettings(
        _ settings: BusinessSettingsResponse,
        slug: String,
        preserving existing: CardPreviewDisplaySnapshot? = nil
    ) -> CardPreviewDisplaySnapshot {
        var programType = (settings.programType ?? "points").lowercased()
        if programType != "points" && programType != "stamps" { programType = "points" }
        let primary = (settings.backgroundColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.backgroundHex)")
            .replacingOccurrences(of: "#", with: "")
        let accent = (settings.foregroundColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.bodyTextHex)")
            .replacingOccurrences(of: "#", with: "")
        let label = (settings.labelColor ?? "#\(AppTheme.WalletCardAppearanceDefaults.labelTitlesHex)")
            .replacingOccurrences(of: "#", with: "")
        var stripMode = (settings.stripDisplayMode ?? "logo").lowercased()
        if stripMode != "text" { stripMode = "logo" }
        let req = max(1, settings.requiredStamps ?? 10)
        let logoStrip = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let logoIcon = settings.logoIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let logoCombined = logoStrip.isEmpty ? logoIcon : logoStrip

        var hasRemote = false
        var bgURL: String?
        if settings.hasCardBackground == true, programType == "points" {
            hasRemote = true
            let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
            var bgURLStr = "\(base)/api/businesses/\(enc)/card-background"
            if let v = settings.cardBackgroundUpdatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                let q = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                bgURLStr += "?v=\(q)"
            }
            bgURL = bgURLStr
        }

        let split = MyCardProgramDefaults.splitPointsTiersFromAPI(
            settings.pointsRewardTiers,
            apiStartGameLabel: settings.startGameRewardLabel
        )

        return CardPreviewDisplaySnapshot(
            programType: programType,
            displayName: settings.organizationName ?? existing?.displayName ?? "Ma Carte",
            primaryHex: primary,
            accentHex: accent,
            labelHex: label,
            stripHex: "",
            stripDisplayMode: stripMode,
            stripText: settings.stripText ?? "",
            logoURL: logoCombined,
            stampEmoji: settings.stampEmoji ?? "",
            requiredStamps: req,
            headerRightText: CardRewardsHeaderLink.displayText,
            labelMember: settings.labelMember ?? "",
            hasRemoteCardBackground: hasRemote,
            cardBackgroundRemoteURL: bgURL,
            hasLocalCardBackground: existing?.hasLocalCardBackground == true,
            stampRewardLabel: settings.stampRewardLabel ?? "",
            stampMidRewardLabel: settings.stampMidRewardLabel,
            startGameRewardLabel: split.startGameRewardLabel,
            labelRestants: settings.labelRestants,
            tierPoints: split.tierPoints,
            tierLabels: split.tierLabels,
            stampIconPendingBase64: existing?.stampIconPendingBase64,
            stampIconWasRemoved: existing?.stampIconWasRemoved,
            hasServerStampIcon: settings.hasStampIcon == true
        )
    }
}
