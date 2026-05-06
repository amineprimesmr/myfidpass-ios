//
//  DashboardFintechHomeLayout.swift
//  myfidpass
//
//  Accueil type « neo-banque » : carte fidélité (même rendu que Ma Carte),
//  liste « Dernières transactions » en pastilles.
//

import SwiftUI
import UIKit

// MARK: - Même cadrage que `MyCardView.previewSection` (hauteur mini + ombre).

enum DashboardHomeCardChrome {
    /// La hauteur mini 438 forçait un rendu trop grand sur l'accueil.
    static let previewMinHeight: CGFloat = 360
    /// Accueil : carte un peu plus compacte que « Ma carte » (pas le même cadrage plein écran).
    static let homeCardScale: CGFloat = 0.66
}

// MARK: - Métriques alignement (scroll + section transactions)

enum DashboardHomeLayoutMetrics {
    /// Padding horizontal du `ScrollView` accueil.
    static let scrollHorizontalPadding: CGFloat = 16
    /// Aligné sur le bloc carte (`AppTheme.Spacing.lg`) : même bord gauche/droit, plus d’étroitissement excessif du titre.
    static let transactionsSectionExtraHorizontal: CGFloat = AppTheme.Spacing.lg
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
                .buttonStyle(.glass(.regular))
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
        .scaleEffect(DashboardHomeCardChrome.homeCardScale, anchor: .center)
        .padding(.top, 2)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Ligne transaction (pastille type neo-banque)

struct FintechTransactionRow: View {
    let entry: DashboardActivityEntry
    let palette: DashboardRevolutPalette
    /// `true` quand le programme fidélité est en points (pas tampons) — aligné sur `CardPreviewDisplaySnapshot.programType`.
    var isPointsProgram: Bool = false

    private static let timeOnlyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.dateStyle = .none
        f.timeStyle = .short
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

    /// Dernière activité : pas de coupure « à minuit » — au-delà d’hier, libellé relatif (ex. il y a 3 j).
    private var activityDateSubtitle: String {
        let d = entry.date
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            return "Aujourd’hui · \(Self.timeOnlyFormatter.string(from: d))"
        }
        if cal.isDateInYesterday(d) {
            return "Hier · \(Self.timeOnlyFormatter.string(from: d))"
        }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "fr_FR")
        rel.unitsStyle = .abbreviated
        return rel.localizedString(for: d, relativeTo: Date())
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
                Text(activityDateSubtitle)
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
    /// Action titre (optionnelle). Quand `nil`, le titre est purement informatif (aucun tap).
    var onSeeAll: (() -> Void)? = nil
    /// Bouton scanner à droite.
    var onOpenScanner: () -> Void
    /// Transitions iOS 18+ : zoom depuis le titre vers la feuille stats (optionnel).
    var statsTransitionSourceID: String? = nil
    var statsTransitionNamespace: Namespace.ID? = nil

    /// Deux lignes, deux styles (évite `Text` + `Text`, déprécié en iOS 26).
    private var titleText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Dernières")
                .foregroundStyle(palette.secondaryText)
            Text("Transactions")
                .foregroundStyle(palette.onCanvasPrimary)
        }
    }

    @ViewBuilder
    private var seeAllTitleButton: some View {
        let label = titleText
            .font(.system(.title, design: .default).weight(.semibold))
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .minimumScaleFactor(0.48)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        if let onSeeAll {
            if let sid = statsTransitionSourceID, let ns = statsTransitionNamespace {
                Button(action: onSeeAll) { label }
                    .buttonStyle(.plain)
                    .layoutPriority(1)
                    .zoomTransitionSource(id: sid, in: ns)
            } else {
                Button(action: onSeeAll) { label }
                    .buttonStyle(.plain)
                    .layoutPriority(1)
            }
        } else {
            label
                .layoutPriority(1)
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            seeAllTitleButton
                .accessibilityLabel("Dernières transactions")
                .accessibilityHint(onSeeAll == nil ? "" : "Ouvre les outils d’analyse (statistiques).")

            scannerButton
                .layoutPriority(0)
                /// Légèrement plus haut et à gauche pour équilibrer le titre deux lignes + grossir le touch target.
                .offset(x: Self.scannerVisualOffset.width, y: Self.scannerVisualOffset.height)
                .onBoarding(2, cornerRadius: 50, visualOffset: Self.scannerVisualOffset) {
                    VStack(spacing: 8) {
                        Text("Scanner les cartes de vos clients")
                            .font(.title3.weight(.semibold))
                        Text("Scannez la carte Wallet d'un client pour enregistrer son passage ou créditer ses points.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                    }
                }
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

/// Inset vertical commun au-dessus du contenu scrollé pour s’aligner sur `DashboardHomeMinimalTopBar` (Accueil, Campagnes, stats Commerce).
enum DashboardHomeMinimalTopBarLayout {
    /// Inset réduit pour remonter nettement le haut des pages (Accueil / Notifications / Commerce).
    static let scrollContentTopInset: CGFloat = 56
}

struct DashboardHomeMinimalTopBar: View {
    let title: String
    var merchantName: String? = nil
    var accountEmail: String? = nil
    var notificationIconURL: String? = nil
    var hasNotificationIcon: Bool = false
    var businesses: [BusinessDTO] = []
    var activeBusinessSlug: String? = nil
    var canCreateBusiness: Bool = true
    var onOpenSettings: (() -> Void)? = nil
    var onSelectBusiness: ((String) -> Void)? = nil
    var onAddCommerce: (() -> Void)? = nil
    var onUpgradeCommerceQuota: (() -> Void)? = nil
    @State private var showBusinessPopover = false
    @State private var localSelectedBusinessSlug: String?
    @State private var isSwitchingBusiness = false
    @Namespace private var businessSwitcherAnimation

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(-1)
            if let onOpenSettings {
                settingsButton(action: onOpenSettings)
            }
            businessSwitcherButton
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 6)
        .background(Color.black)
        .onChange(of: activeBusinessSlug) { _, newValue in
            let incoming = newValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let local = localSelectedBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !incoming.isEmpty, incoming == local {
                localSelectedBusinessSlug = nil
            }
        }
    }

    @ViewBuilder
    private func settingsButton(action: @escaping () -> Void) -> some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.roundedRectangle(radius: 20))
            .controlSize(.large)
        } else {
            Button(action: action) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var businessSwitcherButton: some View {
        Button {
            showBusinessPopover.toggle()
        } label: {
            topBarBusinessAvatar(size: 34)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showBusinessPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            businessSwitcherPopover
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Commerce actif")
        .accessibilityHint("Ouvre le menu du commerce.")
    }

    private var businessSwitcherPopover: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                topBarBusinessAvatar(size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(activeBusinessNameForDisplay)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.86))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(resolvedAccountEmail)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.66))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .id(effectiveActiveBusinessSlug)
            .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)), removal: .opacity))
            .animation(.spring(response: 0.34, dampingFraction: 0.84), value: effectiveActiveBusinessSlug)

            Button {
                showBusinessPopover = false
                onAddCommerce?()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundStyle(Color.black.opacity(0.7))
                    Text("Ajouter un commerce")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.black.opacity(0.86))
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)

            if !businesses.isEmpty {
                Divider()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(businesses, id: \.slug) { business in
                            Button {
                                guard business.slug != effectiveActiveBusinessSlug else {
                                    showBusinessPopover = false
                                    return
                                }
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                                    localSelectedBusinessSlug = business.slug
                                    isSwitchingBusiness = true
                                }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onSelectBusiness?(business.slug)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                                    isSwitchingBusiness = false
                                    showBusinessPopover = false
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(business.slug == effectiveActiveBusinessSlug ? Color.green.opacity(0.9) : Color.black.opacity(0.15))
                                        .frame(width: 9, height: 9)
                                        .overlay {
                                            if business.slug == effectiveActiveBusinessSlug {
                                                Circle()
                                                    .stroke(Color.green.opacity(0.26), lineWidth: 6)
                                                    .frame(width: 9, height: 9)
                                                    .matchedGeometryEffect(id: "activeBusinessDot", in: businessSwitcherAnimation)
                                            }
                                        }
                                    Text(business.name.isEmpty ? business.slug : business.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Color.black.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .scaleEffect(business.slug == effectiveActiveBusinessSlug && isSwitchingBusiness ? 1.01 : 1)
                            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: effectiveActiveBusinessSlug)
                        }
                    }
                }
                .frame(maxHeight: 180)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .padding(8)
    }

    @ViewBuilder
    private func topBarBusinessAvatar(size: CGFloat) -> some View {
        let appIconShape = RoundedRectangle(cornerRadius: max(10, size * 0.28), style: .continuous)
        let icon = notificationIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if hasNotificationIcon, !icon.isEmpty {
            BusinessLogoView(
                logoURL: icon,
                logoAssetContext: .campaignNotificationIcon,
                size: size,
                cornerRadius: max(10, size * 0.28)
            )
            .clipShape(appIconShape)
        } else {
            topBarBusinessAvatarFallback(size: size)
        }
    }

    private func topBarBusinessAvatarFallback(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(10, size * 0.28), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.16, blue: 0.45), Color(red: 0.41, green: 0.12, blue: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "storefront.fill")
                    .font(.system(size: max(13, size * 0.34), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: size, height: size)
    }

    private var resolvedMerchantName: String {
        let raw = (merchantName ?? title).trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Commerce" : raw
    }

    private var effectiveActiveBusinessSlug: String? {
        let local = localSelectedBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !local.isEmpty { return local }
        let remote = activeBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return remote.isEmpty ? nil : remote
    }

    private var activeBusinessNameForDisplay: String {
        if let slug = effectiveActiveBusinessSlug,
           let b = businesses.first(where: { $0.slug == slug }) {
            let name = b.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty { return name }
            return b.slug
        }
        return resolvedMerchantName
    }

    private var resolvedAccountEmail: String {
        let raw = (accountEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? "Compte connecté" : raw
    }

}
