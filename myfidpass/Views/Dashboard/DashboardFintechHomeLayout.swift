//
//  DashboardFintechHomeLayout.swift
//  myfidpass
//
//  Accueil type « neo-banque » : carte fidélité (même rendu que Ma Carte),
//  liste « Dernières transactions » en pastilles.
//

import SwiftUI

// MARK: - Même cadrage que `MyCardView.previewSection` (hauteur mini + ombre).

enum DashboardHomeCardChrome {
    static let previewMinHeight: CGFloat = 438
    /// Accueil : carte un peu plus compacte que « Ma carte » (pas le même cadrage plein écran).
    static let homeCardScale: CGFloat = 0.80
}

// MARK: - Métriques alignement (scroll + section transactions)

enum DashboardHomeLayoutMetrics {
    /// Padding horizontal du `ScrollView` accueil.
    static let scrollHorizontalPadding: CGFloat = 16
    /// Aligné sur le bloc carte (`AppTheme.Spacing.lg`) : même bord gauche/droit, plus d’étroitissement excessif du titre.
    static let transactionsSectionExtraHorizontal: CGFloat = AppTheme.Spacing.lg
    /// Barre du haut alignée sur ce bloc : scroll + même extra que la section transactions (lg).
    static var topBarHorizontalInset: CGFloat { scrollHorizontalPadding + transactionsSectionExtraHorizontal }
}

// MARK: - Pastilles type barre nav / fiche membre (Liquid Glass iOS 26)

/// Fallback avant iOS 26 : même idée que le bouton retour d’`AddPointsAmountSheet` (matériau + trait).
private struct DashboardHomeGlassCircleBackground: View {
    let diameter: CGFloat
    var strokeColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: diameter, height: diameter)
            Circle()
                .strokeBorder(strokeColor, lineWidth: 1)
                .frame(width: diameter, height: diameter)
        }
    }
}

struct DashboardHomeGlassIconButton: View {
    let palette: DashboardRevolutPalette
    let systemName: String
    var iconPointSize: CGFloat = 18
    var iconWeight: Font.Weight = .semibold
    var diameter: CGFloat = 40
    var accessibilityLabel: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) {
                    Image(systemName: systemName)
                        .font(.system(size: iconPointSize, weight: iconWeight))
                        .foregroundStyle(palette.onCanvasPrimary)
                        .frame(width: diameter, height: diameter)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
            } else {
                Button(action: action) {
                    ZStack {
                        DashboardHomeGlassCircleBackground(diameter: diameter, strokeColor: palette.searchFieldStroke)
                        Image(systemName: systemName)
                            .font(.system(size: iconPointSize, weight: iconWeight))
                            .foregroundStyle(palette.onCanvasPrimary.opacity(0.88))
                    }
                    .frame(width: diameter, height: diameter)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Modèle carte (snapshot API + Core Data)

struct DashboardHomeCardModel {
    var displayName: String
    var programType: String
    var primaryHex: String
    var accentHex: String
    var labelHex: String
    var stripDisplayMode: String
    var stripText: String
    var logoURL: String?
    var stampEmoji: String?
    var requiredStamps: Int32
    var previewStampsCount: Int32
    var previewPointsCount: Int32
    var cardBackgroundImagePath: String?
    var cardBackgroundRemoteURL: String?
    var headerRightText: String?
    var memberPreviewText: String
    var labelRestants: String
    var memberColumnTitle: String
    /// Récompenses tampons (aperçu « Prochaine récompense ») — depuis le snapshot « Ma carte » / sync.
    var stampMidRewardLabel: String
    var stampRewardLabel: String
    var fidelityQRPayloadURL: String?

    @MainActor
    static func resolve(dataService: DataService) -> DashboardHomeCardModel? {
        _ = dataService.updateTrigger
        guard let template = dataService.currentCardTemplate() else { return nil }
        let slug = AuthStorage.currentBusinessSlug ?? ""
        let snap = slug.isEmpty ? nil : CardPreviewDisplaySnapshotStore.load(slug: slug)

        let displayName = snap?.displayName ?? template.displayName ?? "Ma Carte Fidélité"
        let programType = (snap?.programType ?? "points").lowercased()
        let pt = (programType == "points") ? "points" : "stamps"
        let primaryHex = normalizeHex(
            snap?.primaryHex ?? template.primaryColorHex,
            fallback: AppTheme.WalletCardAppearanceDefaults.backgroundHex
        )
        let accentHex = normalizeHex(
            snap?.accentHex ?? template.accentColorHex,
            fallback: AppTheme.WalletCardAppearanceDefaults.bodyTextHex
        )
        let labelHex = normalizeHex(
            snap?.labelHex,
            fallback: AppTheme.WalletCardAppearanceDefaults.labelTitlesHex
        )
        var stripDisplayMode = (snap?.stripDisplayMode ?? "logo").lowercased()
        if stripDisplayMode != "text" { stripDisplayMode = "logo" }
        let stripText = snap?.stripText ?? ""
        // Bandeau Wallet = logo commerce (comme Ma carte), pas la petite icône en priorité.
        let logoRaw: String
        if let s = snap?.logoURL, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logoRaw = s
        } else {
            let strip = template.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let icon = template.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            logoRaw = strip.isEmpty ? icon : strip
        }
        let logoURL = logoRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : logoRaw
        let stampRaw = snap?.stampEmoji ?? template.stampEmoji ?? ""
        let stampEmoji = stampRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : stampRaw
        let req = snap?.requiredStamps ?? Int(template.requiredStamps)
        let requiredStamps: Int32 = Int32(max(1, req))
        let cap = max(1, Int(requiredStamps))
        let uniqueCards = dataService.uniqueClientCards(for: template)
        let firstNonPreview = uniqueCards.first { card in
            !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: card.clientEmail)
        }
        // Comme Ma carte : solde / nom du 1er membre réel ; si seul l’aperçu Wallet existe, même source que `uniqueClientCards.first`.
        let firstForBalance = firstNonPreview ?? uniqueCards.first
        let balance = firstForBalance.map { Int($0.stampsCount) } ?? 0
        let previewStamps: Int32
        let previewPoints: Int32
        if pt == "points" {
            previewStamps = 0
            previewPoints = Int32(max(0, balance))
        } else {
            previewPoints = 0
            previewStamps = Int32(min(max(0, balance), cap))
        }
        // Fond distant : snapshot (rempli après sync, ou créé depuis settings si jamais « Ma carte ») ; repli cache scan si course entre vues.
        let bgRemote: String?
        if let snap, snap.hasRemoteCardBackground, let u = snap.cardBackgroundRemoteURL, !u.isEmpty {
            bgRemote = u
        } else if let cached = ScanFlowSettingsCache.cached(for: slug), cached.hasCardBackground == true {
            bgRemote = Self.buildCardBackgroundRemoteURL(slug: slug, updatedAt: cached.cardBackgroundUpdatedAt)
        } else {
            bgRemote = nil
        }
        /// Fond local : `false` = absent explicitement. `nil` = snapshot ancien (champ absent) → on vérifie le fichier.
        /// `true` = confirmé présent. On n’affiche jamais un fichier d’un autre compte car `removeAllLocalCardAssets()`
        /// est appelé à la déconnexion.
        let localCardBgRelative: String? = {
            if snap?.hasLocalCardBackground == false { return nil }
            let rel = CardLogoStorage.relativeCardBackgroundPath
            guard let full = CardLogoStorage.fullPath(forRelative: rel),
                  FileManager.default.fileExists(atPath: full) else { return nil }
            return rel
        }()
        let headerRightTrimmed = snap.map { $0.headerRightText.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let headerRightText = headerRightTrimmed.isEmpty ? nil : headerRightTrimmed
        let labelMember = snap.map { $0.labelMember.trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let memberColumnTitle = labelMember.isEmpty ? "MEMBRE" : labelMember
        let labelRestantsResolved: String = {
            let raw = snap?.labelRestants?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return raw.isEmpty ? "Restants" : raw
        }()
        let memberPreviewText: String
        if let first = firstForBalance,
           let n = first.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !n.isEmpty {
            memberPreviewText = n
        } else {
            memberPreviewText = "Prévisualisation"
        }
        let fidelityURL = slug.isEmpty ? nil : LegalURLs.fidelityCardPage(slug: slug)?.absoluteString
        let stampRewardResolved = snap?.stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let stampMidResolved = snap?.stampMidRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return DashboardHomeCardModel(
            displayName: displayName,
            programType: pt,
            primaryHex: primaryHex,
            accentHex: accentHex,
            labelHex: labelHex,
            stripDisplayMode: stripDisplayMode,
            stripText: stripText,
            logoURL: logoURL,
            stampEmoji: stampEmoji,
            requiredStamps: requiredStamps,
            previewStampsCount: previewStamps,
            previewPointsCount: previewPoints,
            cardBackgroundImagePath: localCardBgRelative,
            cardBackgroundRemoteURL: bgRemote,
            headerRightText: headerRightText,
            memberPreviewText: memberPreviewText,
            labelRestants: labelRestantsResolved,
            memberColumnTitle: memberColumnTitle,
            stampMidRewardLabel: stampMidResolved,
            stampRewardLabel: stampRewardResolved,
            fidelityQRPayloadURL: fidelityURL
        )
    }

    /// Aperçu carte tampons après scan QR : mêmes couleurs / logo que l’accueil « Ma carte », nom et solde du client scanné.
    @MainActor
    static func resolveStampScanPreview(
        dataService: DataService,
        memberName: String,
        memberStampBalance: Int?,
        settings: BusinessSettingsResponse
    ) -> DashboardHomeCardModel? {
        guard var model = resolve(dataService: dataService) else { return nil }
        let fromSettings: Int? = {
            guard let r = settings.requiredStamps, r > 0 else { return nil }
            return r
        }()
        let cap = max(1, fromSettings ?? Int(model.requiredStamps))
        model.programType = "stamps"
        model.requiredStamps = Int32(cap)
        let bal = memberStampBalance ?? 0
        model.previewStampsCount = Int32(Swift.min(Swift.max(0, bal), cap))
        model.previewPointsCount = 0
        let n = memberName.trimmingCharacters(in: .whitespacesAndNewlines)
        model.memberPreviewText = n.isEmpty ? "Client" : n
        return model
    }

    private static func buildCardBackgroundRemoteURL(slug: String, updatedAt: String?) -> String {
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        var url = "\(base)/api/businesses/\(enc)/card-background"
        if let v = updatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
            let q = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
            url += "?v=\(q)"
        }
        return url
    }

    private static func normalizeHex(_ raw: String?, fallback: String) -> String {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = t.isEmpty ? fallback : t
        if base.hasPrefix("#") { return String(base.dropFirst()) }
        return base
    }

}

// MARK: - Carte (aperçu fidélité)

struct FintechHomeLoyaltyCardBlock: View {
    let model: DashboardHomeCardModel
    let palette: DashboardRevolutPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.shadow)
                .blur(radius: 18)
                .offset(y: 6)
                .opacity(0.4)

            Group {
                if model.programType == "stamps" {
                    CafeDesArtsCardPreview(
                        displayName: model.displayName.isEmpty ? "Ma Carte Fidélité" : model.displayName,
                        requiredStamps: model.requiredStamps,
                        stampsCount: model.previewStampsCount,
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
                        compact: false,
                        onEditZoneTap: nil,
                        fidelityQRPayloadURL: model.fidelityQRPayloadURL
                    )
                } else {
                    WalletCardPreview(
                        displayName: model.displayName.isEmpty ? "Ma Carte Fidélité" : model.displayName,
                        requiredStamps: model.requiredStamps,
                        stampsCount: model.previewPointsCount,
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
                        compact: false,
                        onEditZoneTap: nil,
                        fidelityQRPayloadURL: model.fidelityQRPayloadURL
                    )
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .frame(minHeight: DashboardHomeCardChrome.previewMinHeight)
        }
        .scaleEffect(DashboardHomeCardChrome.homeCardScale, anchor: .top)
        .padding(.bottom, -22)
        .padding(.vertical, AppTheme.Spacing.xs)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ligne transaction (pastille type neo-banque)

struct FintechTransactionRow: View {
    let entry: DashboardActivityEntry
    let palette: DashboardRevolutPalette
    /// `true` quand le programme fidélité est en points (pas tampons) — aligné sur `CardPreviewDisplaySnapshot.programType`.
    var isPointsProgram: Bool = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// Flèche haut-droite ≈ mouvement « sortant », bas-gauche ≈ « entrant » (comme les maquettes banking).
    private var iconName: String {
        switch entry.kind {
        case .scan: return "arrow.down.left"
        case .newCard: return "arrow.up.right"
        }
    }

    private var amountLine: String {
        switch entry.kind {
        case .scan:
            if isPointsProgram, let pts = entry.scanPointsGranted {
                return "+\(pts) pts"
            }
            return "+ Visite"
        case .newCard: return "+ Carte"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(palette.transactionIconDisc)
                    .frame(width: 44, height: 44)
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(palette.onCanvasPrimary.opacity(0.72))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.clientName)
                    .font(.body.weight(.bold))
                    .foregroundStyle(palette.onCanvasPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(Self.dateFormatter.string(from: entry.date))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryText)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Text(amountLine)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.onCanvasPrimary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .background(palette.transactionPillBG, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

// MARK: - Section titres

struct FintechTransactionsSectionHeader: View {
    let palette: DashboardRevolutPalette
    /// Tap sur le titre « Dernières / Transactions » → liste complète.
    var onSeeAll: () -> Void
    /// Bouton scanner à droite.
    var onOpenScanner: () -> Void

    /// Deux lignes, deux styles (évite `Text` + `Text`, déprécié en iOS 26).
    private var titleText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dernières")
                .foregroundStyle(palette.secondaryText)
            Text("Transactions")
                .foregroundStyle(palette.onCanvasPrimary)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: onSeeAll) {
                titleText
                    .font(.system(.title, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .layoutPriority(1)
            .accessibilityLabel("Dernières transactions")
            .accessibilityHint("Affiche toute l’activité.")

            scannerButton
                .layoutPriority(0)
                /// Légèrement plus haut et à gauche pour équilibrer le titre deux lignes + grossir le touch target.
                .offset(x: Self.scannerVisualOffset.width, y: Self.scannerVisualOffset.height)
        }
    }

    /// Accueil : bouton scanner plus grand que les icônes glass standard (40 pt).
    private static let scannerButtonDiameter: CGFloat = 68
    private static let scannerIconPointSize: CGFloat = 28

    /// Léger décalage visuel du bouton scanner (remonté + déplacé à gauche pour équilibrer le titre sur 2 lignes).
    /// Appliqué en `.offset` côté appelant → purement visuel, non reflété par `frame(in: .global)`.
    static let scannerVisualOffset = CGSize(width: -10, height: -8)

    private var scannerButton: some View {
        DashboardHomeGlassIconButton(
            palette: palette,
            systemName: "qrcode.viewfinder",
            iconPointSize: Self.scannerIconPointSize,
            diameter: Self.scannerButtonDiameter,
            accessibilityLabel: "Scanner un code QR",
            action: onOpenScanner
        )
    }
}

// MARK: - Barre haute minimaliste

struct DashboardHomeMinimalTopBar: View {
    let palette: DashboardRevolutPalette
    var onOpenProfile: () -> Void
    var onOpenScan: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            DashboardHomeGlassIconButton(
                palette: palette,
                systemName: "person.crop.circle.fill",
                iconPointSize: 19,
                accessibilityLabel: "Commerce",
                action: onOpenProfile
            )

            Spacer(minLength: 12)

            DashboardHomeGlassIconButton(
                palette: palette,
                systemName: "qrcode.viewfinder",
                iconPointSize: 18,
                accessibilityLabel: "Scanner un code QR",
                action: onOpenScan
            )
        }
    }
}
