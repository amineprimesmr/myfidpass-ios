//
//  CardElementCustomizationSheet.swift
//  myfidpass
//
//  Feuille modale de personnalisation par zone de la carte (tap sur l’aperçu).
//

import Combine
import Photos
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Données liées (bindings + actions async)

struct CardCustomizationBindPack {
    let primaryHex: Binding<String>
    let accentHex: Binding<String>
    let labelHex: Binding<String>
    let stripDisplayMode: Binding<String>
    let stripText: Binding<String>
    let logoURL: Binding<String>
    let logoPhotoItem: Binding<PhotosPickerItem?>
    let labelMember: Binding<String>
    let labelRestants: Binding<String>
    let displayName: Binding<String>
    let cardBackgroundPhotoItem: Binding<PhotosPickerItem?>
    let cardBackgroundImagePath: Binding<String?>
    let cardBackgroundRemoteURL: Binding<String?>
    let programType: Binding<String>
    let tierPoints: Binding<[String]>
    let tierLabels: Binding<[String]>
    let requiredStamps: Binding<Int>
    let previewStampsCount: Binding<Int>
    let previewPointsCount: Binding<Int>
    let stampEmoji: Binding<String>
    let stampIconPhotoItem: Binding<PhotosPickerItem?>
    let stampIconPendingBase64: Binding<String?>
    let stampIconWasRemoved: Binding<Bool>
    /// URL renvoyée par l’API pour l’icône tampon (aperçu grille quand le brouillon a été enregistré).
    let serverStampIconURL: String?
    let serverHasStampIconAsset: Bool
    let stampRewardLabel: Binding<String>
    let stampMidRewardLabel: Binding<String>
    /// Palier « Début du jeu » (non modifiable côté seuil, récompense éditable). Commun aux modes points et tampons.
    let startGameRewardLabel: Binding<String>
    let backTerms: Binding<String>
    let backContact: Binding<String>
    let notificationTitleOverride: Binding<String>
    let notificationChangeMessage: Binding<String>
    let welcomeBonusEnabled: Binding<Bool>
    /// Nombre de points (mode points) offerts à l'inscription. Toujours 1 en mode tampons.
    let welcomeBonusAmount: Binding<Int>
}

struct CardCustomizationActions {
    let loadLogoFromPhotoAsset: (PHAsset) async -> Void
    let loadCardBackgroundFromPhotoAsset: (PHAsset) async -> Void
    let removeCardBackground: () -> Void
    let removeLogo: () -> Void
    let resetStampIcon: (String) -> Void
}

// MARK: - Feuille

struct CardElementCustomizationSheet: View {
    let zone: CardPreviewEditZone
    let pack: CardCustomizationBindPack
    let actions: CardCustomizationActions
    var cardImageSuggestedColors: [String]
    var dashboardSettingsHydrated: Bool
    /// Enregistrement API depuis la feuille « Récompenses » (nil = pas de bouton dédié).
    var onSaveRewards: (() async -> Bool)?
    var canSaveRewards: Bool = true
    var rewardsSaveInFlight: Bool = false
    /// État local pour la feuille de cadrage (évite les problèmes de présentation avec un `Binding` parent).
    @State private var cropEditorPayload: ImageCropPayload?
    /// Nombre de lignes paliers points visibles dans « Récompenses » (5 par défaut, jusqu’à 8).
    @State private var visiblePointsTierRows = MyCardPointsRewardTiers.minVisibleCount
    /// Logo sans fond persisté côté serveur (remove.bg) — proposé comme raccourci dans le sheet logo.
    @State private var flyerNobgImage: UIImage?
    @State private var flyerNobgLoading = false
    var onCropComplete: (UIImage, ImageCropSpec) async -> Void

    /// Même gabarit de feuille que le logo : pas de sélecteurs de couleur, hauteur initiale compacte.
    private var usesCompactImagePickerSheet: Bool {
        zone == .logoBand || zone == .backgroundImage
    }

    /// « Système de carte » et « Récompenses » : marges verticales alignées (segment Programme + contenu).
    private var usesTightVerticalPadding: Bool {
        zone == .mainMetrics || zone == .headerRight
    }

    private var sheetContentVerticalSpacing: CGFloat {
        if usesCompactImagePickerSheet { return 8 }
        if usesTightVerticalPadding { return 12 }
        return 18
    }

    private var sheetPresentationDetents: Set<PresentationDetent> {
        if usesCompactImagePickerSheet {
            // Marge pour la ligne de titre au-dessus du carrousel + actions.
            // Carrousel logo/fond : vignettes ~84 pt (+ marge titre + liste actions).
            return [.height(zone == .backgroundImage ? 384 : 332), .large]
        }
        if zone == .cardAppearance {
            return [.height(480), .large]
        }
        if zone == .mainMetrics {
            return [.height(430), .large]
        }
        if zone == .headerRight {
            /// Récompenses : paliers points unifiés (10 pts en 1ʳᵉ ligne) ; `.large` conseillé.
            return [.large]
        }
        return [.medium, .large]
    }

    private var sheetVerticalPadding: CGFloat {
        if usesCompactImagePickerSheet { return 6 }
        if zone == .headerRight { return 8 }
        if usesTightVerticalPadding { return 10 }
        return 16
    }

    private var sheetBottomPadding: CGFloat {
        if usesCompactImagePickerSheet { return 8 }
        if zone == .headerRight { return 12 }
        if usesTightVerticalPadding { return 14 }
        return 28
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: sheetContentVerticalSpacing) {
                    sheetHeaderRow
                    zoneBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, sheetVerticalPadding)
                .padding(.bottom, sheetBottomPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppTheme.Colors.background)
            .sheetHideNavigationBar()
        }
        .task(id: zone) {
            guard zone == .logoBand else { return }
            await loadFlyerNobgImage()
        }
        .presentationDetents(sheetPresentationDetents)
        .presentationDragIndicator(.hidden)
        .modifier(LiquidGlassSheetModifier())
        /// Plein écran : une 2e `.sheet` au-dessus d’une feuille Liquid Glass laissait voir l’aperçu carte (confusion + touches) ; le fond opaque sur l’éditeur aide aussi.
        .fullScreenCover(item: $cropEditorPayload) { payload in
            let spec = payload.spec
            ImageCropEditorView(
                spec: spec,
                sourceImage: payload.image,
                onCancel: { cropEditorPayload = nil },
                onComplete: { cropped in
                    cropEditorPayload = nil
                    Task { await onCropComplete(cropped, spec) }
                }
            )
        }
    }

    private func loadFlyerNobgImage() async {
        guard !flyerNobgLoading, flyerNobgImage == nil,
              let slug = AuthStorage.currentBusinessSlug else { return }
        flyerNobgLoading = true
        defer { flyerNobgLoading = false }
        guard let data = try? await APIClient.shared.requestData(.dashboardLogoNobg(slug: slug)),
              !data.isEmpty, let img = UIImage(data: data) else { return }
        flyerNobgImage = img
    }

    /// Galerie → cadrage : léger délai après fermeture du `PhotosPicker` pour que la feuille de cadrage s’affiche correctement.
    private func presentCropFromGallery(item: PhotosPickerItem?, spec: ImageCropSpec) async {
        guard let item else { return }
        guard let image = await loadUIImageFromPhotosPickerItem(item) else { return }
        await MainActor.run {
            switch spec {
            case .walletStripLogo:
                pack.logoPhotoItem.wrappedValue = nil
            case .walletCardBackground:
                pack.cardBackgroundPhotoItem.wrappedValue = nil
            case .squareIcon:
                break
            case .stampIcon:
                pack.stampIconPhotoItem.wrappedValue = nil
            case .flyerPromoLogo:
                break
            case .flyerCustomBackground:
                break
            }
        }
        try? await Task.sleep(nanoseconds: 320_000_000)
        await MainActor.run {
            cropEditorPayload = ImageCropPayload(image: image, spec: spec)
        }
    }

    /// Carrousel « photos récentes » → même écran de cadrage que la galerie (ne pas appliquer l’image brute).
    private func presentCropFromPhotoAsset(_ asset: PHAsset, spec: ImageCropSpec) async {
        guard let image = await asset.myfid_exportUIImage() else { return }
        try? await Task.sleep(nanoseconds: 120_000_000)
        await MainActor.run {
            cropEditorPayload = ImageCropPayload(image: image, spec: spec)
        }
    }

    /// Photo prise avec l’appareil → cadrage après fermeture de l’écran capture.
    private func presentCropFromUIImage(_ image: UIImage, spec: ImageCropSpec) async {
        try? await Task.sleep(nanoseconds: 350_000_000)
        await MainActor.run {
            cropEditorPayload = ImageCropPayload(image: image, spec: spec)
        }
    }

    private func loadUIImageFromPhotosPickerItem(_ item: PhotosPickerItem) async -> UIImage? {
        if let data = try? await item.loadTransferable(type: Data.self),
           let img = UIImage(data: data) {
            return img
        }
        if let id = item.itemIdentifier {
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
            if let asset = fetch.firstObject {
                return await asset.myfid_exportUIImage()
            }
        }
        return nil
    }

    private var sheetHeaderRow: some View {
        Text(zone.customizationSheetTitle)
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .padding(.bottom, 4)
    }

    @ViewBuilder
    private var zoneBody: some View {
        switch zone {
        case .logoBand:
            logoBandBlock
        case .headerRight:
            headerRightBlock
        case .backgroundImage:
            backgroundImageBlock
        case .cardAppearance:
            cardAppearanceBlock
        case .mainMetrics:
            mainMetricsBlock
        case .memberColumn:
            memberColumnBlock
        case .qrCode:
            // Jamais présenté : tap sur le QR dans Ma carte ouvre l’URL (MyCardView).
            EmptyView()
        case .walletPassBack:
            walletPassBackBlock
        }
    }

    // MARK: - Logo (carrousel récents + liste d’actions type iOS)

    @ViewBuilder
    private var flyerNobgSection: some View {
        if flyerNobgLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Logo flyer…")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        } else if let img = flyerNobgImage {
            VStack(alignment: .leading, spacing: 6) {
                Text("Logo sans fond (flyer)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding(.horizontal, 4)
                Button {
                    Task { await presentCropFromUIImage(img, spec: .walletStripLogo) }
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(AppTheme.Colors.textSecondary.opacity(0.08))
                                .frame(width: 48, height: 48)
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Utiliser ce logo")
                                .font(.body)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            Text("Fond supprimé automatiquement")
                                .font(.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(red: 0, green: 0.48, blue: 1).opacity(0.25), lineWidth: 1)
                )
                .accessibilityLabel(Text("Utiliser le logo sans fond issu du flyer"))
            }
        }
    }

    private var logoBandBlock: some View {
        logoBandImageModeContent
    }

    private var logoBandImageModeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            flyerNobgSection
            LogoRecentPhotosCarousel(
                onSelectAsset: { asset in
                    Task { await presentCropFromPhotoAsset(asset, spec: .walletStripLogo) }
                },
                onCameraImage: { image in
                    Task { await presentCropFromUIImage(image, spec: .walletStripLogo) }
                }
            )
            logoImageModeActionShell {
                PhotosPicker(selection: pack.logoPhotoItem, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            .frame(width: 36, alignment: .center)
                        Text("Galerie")
                            .font(.body)
                            .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                }
                .accessibilityLabel(Text("Ouvrir la galerie photo"))
                .onChange(of: pack.logoPhotoItem.wrappedValue) { _, new in
                    Task { await presentCropFromGallery(item: new, spec: .walletStripLogo) }
                }
            }
        }
    }

    private func logoImageModeActionShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
            )
    }

    // MARK: - Récompenses (paliers points / récompenses tampons — même choix Programme que « Système de carte »)

    private var headerRightBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            rewardSavePrimarySection
            welcomeBonusSection
            Divider()
            rewardRulesContent
            rewardExamplesTextButton
        }
        .onAppear {
            enforceWelcomeBonusDefaults()
            if pack.programType.wrappedValue == "points" {
                var pts = pack.tierPoints.wrappedValue
                var labs = pack.tierLabels.wrappedValue
                MyCardProgramDefaults.sanitizeEditableTierSlots(tierPoints: &pts, tierLabels: &labs)
                pack.tierPoints.wrappedValue = pts
                pack.tierLabels.wrappedValue = labs
                visiblePointsTierRows = Self.resolvedVisibleTierRows(points: pts)
                var startLabel = pack.startGameRewardLabel.wrappedValue
                MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                    startGameRewardLabel: &startLabel,
                    tierPoints: pts,
                    tierLabels: labs
                )
                pack.startGameRewardLabel.wrappedValue = startLabel
            } else {
                var startLabel = pack.startGameRewardLabel.wrappedValue
                MyCardProgramDefaults.ensureStartGameRewardLabel(&startLabel)
                pack.startGameRewardLabel.wrappedValue = startLabel
            }
        }
        .onChange(of: pack.programType.wrappedValue) { _, _ in
            enforceWelcomeBonusDefaults()
        }
    }

    /// Bonus d’inscription : toujours actif (10 pts en mode points, 1 tampon en mode tampons) — appliqué à l’ouverture et à l’enregistrement côté `MyCardView`.
    private func enforceWelcomeBonusDefaults() {
        pack.welcomeBonusEnabled.wrappedValue = true
        if pack.programType.wrappedValue == "points" {
            pack.welcomeBonusAmount.wrappedValue = 10
        } else {
            pack.welcomeBonusAmount.wrappedValue = 1
        }
    }

    @ViewBuilder
    private var rewardSavePrimarySection: some View {
        if let onSaveRewards {
            Button {
                Task {
                    _ = await onSaveRewards()
                }
            } label: {
                Group {
                    if rewardsSaveInFlight {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Enregistrer")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .buttonBorderShape(.roundedRectangle(radius: 20))
            .controlSize(.large)
            .glassStyle()
            .disabled(!canSaveRewards || rewardsSaveInFlight)
        }
    }

    private var rewardExamplesTextButton: some View {
        Button {
            applyRewardExamplePresets()
        } label: {
            Text("Appliquer les exemples")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func applyRewardExamplePresets() {
        if pack.programType.wrappedValue == "stamps" {
            pack.startGameRewardLabel.wrappedValue = "Boisson offerte"
            pack.stampMidRewardLabel.wrappedValue = "Dessert offert"
            pack.stampRewardLabel.wrappedValue = "Menu offert"
            return
        }
        let n = visiblePointsTierRows
        let examplePoints = (0..<n).map { i in
            i == 0 ? "10" : String(50 * i)
        }
        let exampleLabels = [
            "Boisson offerte",
            "Dessert offert",
            "Cheese offert",
            "Menu offert",
            "Formule du jour offerte",
            "-20 % sur l'addition",
            "Réduction sur l'addition",
            "Cadeau surprise",
        ]
        var pts = examplePoints
        var labels = exampleLabels
        while pts.count < n { pts.append("") }
        while labels.count < n { labels.append("") }
        pack.tierPoints.wrappedValue = Array(pts.prefix(n))
        pack.tierLabels.wrappedValue = Array(labels.prefix(n))
        pack.startGameRewardLabel.wrappedValue = "Boisson offerte"
    }

    private static func resolvedVisibleTierRows(points: [String]) -> Int {
        let lastFilled = points.indices.reversed().first { index in
            !points[index].trimmingCharacters(in: .whitespaces).isEmpty
        } ?? -1
        return min(
            max(MyCardPointsRewardTiers.minVisibleCount, lastFilled + 2),
            MyCardPointsRewardTiers.slotCount
        )
    }

    private func ensureTierArrayCapacity(for index: Int) {
        var pts = pack.tierPoints.wrappedValue
        var labs = pack.tierLabels.wrappedValue
        while pts.count <= index { pts.append("") }
        while labs.count <= index { labs.append("") }
        pack.tierPoints.wrappedValue = pts
        pack.tierLabels.wrappedValue = labs
    }

    // MARK: - Bonus d'inscription (affichage minimal : tampons uniquement ; points sans réglage — fixe 10 côté modèle)

    @ViewBuilder
    private var welcomeBonusSection: some View {
        if pack.programType.wrappedValue == "stamps" {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "gift.fill")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 28, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tampon de bienvenue")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("1 tampon offert au 1er ajout Wallet")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var rewardRulesContent: some View {
        if pack.programType.wrappedValue == "points" {
            pointsRulesContent
        } else {
            stampsRulesContent
        }
    }

    // MARK: - Image de fond (même gabarit que le logo : carrousel + liste)

    /// Réutilisé par la zone « Image de fond » et par « Système de carte » (mode points).
    private var cardBackgroundImagePickerSection: some View {
        let path = pack.cardBackgroundImagePath.wrappedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remote = pack.cardBackgroundRemoteURL.wrappedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bgRef = !path.isEmpty ? path : remote
        let hasBackground = !bgRef.isEmpty
        return VStack(alignment: .leading, spacing: 10) {
            LogoRecentPhotosCarousel(
                onSelectAsset: { asset in
                    Task { await presentCropFromPhotoAsset(asset, spec: .walletCardBackground) }
                },
                onCameraImage: { image in
                    Task { await presentCropFromUIImage(image, spec: .walletCardBackground) }
                }
            )
            logoImageModeActionShell {
                VStack(spacing: 0) {
                    PhotosPicker(selection: pack.cardBackgroundPhotoItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 36, alignment: .center)
                            Text("Galerie")
                                .font(.body)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                    }
                    .accessibilityLabel(Text("Ouvrir la galerie photo"))
                    .onChange(of: pack.cardBackgroundPhotoItem.wrappedValue) { _, new in
                        Task { await presentCropFromGallery(item: new, spec: .walletCardBackground) }
                    }

                    if hasBackground {
                        Divider()
                            .padding(.leading, 64)
                        Button {
                            actions.removeCardBackground()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "trash")
                                    .font(.title3)
                                    .foregroundStyle(.red)
                                    .frame(width: 36, alignment: .center)
                                Text("Supprimer")
                                    .font(.body)
                                    .foregroundStyle(.red)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 16)
                            .padding(.horizontal, 14)
                        }
                        .accessibilityLabel(Text("Supprimer l’image de fond"))
                    }
                }
            }
        }
    }

    private var backgroundImageBlock: some View {
        cardBackgroundImagePickerSection
    }

    // MARK: - Système de carte (icônes tampons / image fond points — récompenses dans l’autre feuille)

    private var mainMetricsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if pack.programType.wrappedValue == "stamps" {
                stampsStyleSection
            }
            if pack.programType.wrappedValue == "points" {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Image de fond")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    cardBackgroundImagePickerSection
                }
            }
        }
    }

    private var stampsStyleSection: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 34, maximum: 56), spacing: 8), count: 6)
        let selectedIconKey = StampIconCatalog.normalizeKey(pack.stampEmoji.wrappedValue)
        let pending = pack.stampIconPendingBase64.wrappedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let serverS = pack.serverStampIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let customOrServerActive = !pack.stampIconWasRemoved.wrappedValue
            && (!pending.isEmpty || (pack.serverHasStampIconAsset && !serverS.isEmpty))
        return VStack(alignment: .leading, spacing: 8) {
            Text("Tampons")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Choisissez l’icône affichée sur les cases tampon.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: 8) {
                PhotosPicker(selection: pack.stampIconPhotoItem, matching: .images, photoLibrary: .shared()) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                        .frame(height: 48)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                if customOrServerActive {
                    let remoteResolved: URL? = {
                        if !pending.isEmpty { return nil }
                        guard !serverS.isEmpty else { return nil }
                        return APIResourceURL.resolved(from: serverS)
                    }()
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.cardBackground)
                        .frame(height: 48)
                        .overlay {
                            StampIconDisplayView(
                                dataURL: pending.isEmpty ? nil : pending,
                                remoteURL: remoteResolved,
                                catalogEmoji: pack.stampEmoji.wrappedValue,
                                size: 40,
                                tint: AppTheme.Colors.textPrimary
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppTheme.Colors.primary.opacity(0.55), lineWidth: 2)
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("Image importée, utilisée comme picto tampon"))
                }

                ForEach(StampIconCatalog.selectableKeys, id: \.self) { iconKey in
                    Button {
                        pack.stampEmoji.wrappedValue = iconKey
                        actions.resetStampIcon(iconKey)
                    } label: {
                        StampIconView(stampEmoji: iconKey, size: 40, tint: AppTheme.Colors.textPrimary)
                            .frame(height: 48)
                            .frame(maxWidth: .infinity)
                            .background(
                                (!customOrServerActive && selectedIconKey == iconKey ? AppTheme.Colors.primary.opacity(0.2) : Color.clear)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .onChange(of: pack.stampIconPhotoItem.wrappedValue) { _, new in
            Task { await presentCropFromGallery(item: new, spec: .stampIcon) }
        }
    }

    // MARK: - Couleurs seules (menu Autres réglages — pas d’image de fond ici)

    private var cardAppearanceBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !cardImageSuggestedColors.isEmpty {
                Text("D’abord les couleurs détectées (logo, fond), puis la palette vive (même grille que le flyer).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LabeledCanvaColorPalette(title: "Fond de la carte", hex: pack.primaryHex, imageSuggestions: cardImageSuggestedColors)
            LabeledCanvaColorPalette(title: "Titres", hex: pack.labelHex, imageSuggestions: cardImageSuggestedColors)
            LabeledCanvaColorPalette(title: "Textes", hex: pack.accentHex, imageSuggestions: cardImageSuggestedColors)
        }
    }

    private var pointsRulesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(0..<visiblePointsTierRows, id: \.self) { i in
                pointsTierRow(index: i)
            }
            if visiblePointsTierRows < MyCardPointsRewardTiers.slotCount {
                Button {
                    ensureTierArrayCapacity(for: visiblePointsTierRows)
                    visiblePointsTierRows += 1
                } label: {
                    Label("Ajouter une récompense", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
    }

    /// Palier « Début du jeu » (mode tampons uniquement).
    private var startGameRewardRow: some View {
        let seuil = "Début du jeu"
        return HStack(alignment: .top, spacing: 10) {
            Text(seuil)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .frame(width: 76)
                .padding(.vertical, 12)
                .padding(.horizontal, 6)
                .background(AppTheme.Colors.cardBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                )
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel(Text("Début du jeu — palier verrouillé"))
            TextField(
                "",
                text: pack.startGameRewardLabel,
                prompt: Text("Boisson offerte").foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85))
            )
            .textFieldStyle(.plain)
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
            )
            .accessibilityLabel(Text("Récompense début du jeu"))
        }
    }

    private static let tierSeuilExamples = ["10", "50", "100", "150", "200", "250", "300", "350"]
    private static let tierRewardExamples = [
        "Boisson offerte",
        "Dessert offert",
        "Cheese offert",
        "Menu offert",
        "Formule du jour",
        "Réduction sur l'addition",
        "Cadeau surprise",
        "Offre spéciale",
    ]

    private static let stamp5PassageRewardPlaceholder = "-50% sur l’addition"
    private static let stamp10PassageRewardPlaceholder = "Menu offert"

    private func pointsTierRow(index: Int) -> some View {
        let seuilPrompt = Self.tierSeuilExamples[min(index, Self.tierSeuilExamples.count - 1)]
        let rewardPrompt = Self.tierRewardExamples[min(index, Self.tierRewardExamples.count - 1)]
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                TextField("", text: Binding(
                    get: {
                        guard index < pack.tierPoints.wrappedValue.count else { return "" }
                        return pack.tierPoints.wrappedValue[index]
                    },
                    set: { newVal in
                        var arr = pack.tierPoints.wrappedValue
                        while arr.count <= index { arr.append("") }
                        arr[index] = newVal
                        pack.tierPoints.wrappedValue = arr
                        if index == 0 {
                            var start = pack.startGameRewardLabel.wrappedValue
                            MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                                startGameRewardLabel: &start,
                                tierPoints: arr,
                                tierLabels: pack.tierLabels.wrappedValue
                            )
                            pack.startGameRewardLabel.wrappedValue = start
                        }
                    }
                ), prompt: Text(seuilPrompt).foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .frame(width: 76)
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                )
                TextField("", text: Binding(
                    get: {
                        guard index < pack.tierLabels.wrappedValue.count else { return "" }
                        return pack.tierLabels.wrappedValue[index]
                    },
                    set: { newVal in
                        var arr = pack.tierLabels.wrappedValue
                        while arr.count <= index { arr.append("") }
                        arr[index] = newVal
                        pack.tierLabels.wrappedValue = arr
                        if index == 0 {
                            var start = pack.startGameRewardLabel.wrappedValue
                            MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                                startGameRewardLabel: &start,
                                tierPoints: pack.tierPoints.wrappedValue,
                                tierLabels: arr
                            )
                            pack.startGameRewardLabel.wrappedValue = start
                        }
                    }
                ), prompt: Text(rewardPrompt).foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                )
            }
        }
    }

    private func stampsPassageRewardRow(passageLabel: String, reward: Binding<String>, prompt: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(passageLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 76)
                .padding(.vertical, 12)
                .padding(.horizontal, 8)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                )
                .accessibilityAddTraits(.isStaticText)
            TextField("", text: reward, prompt: Text(prompt).foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                .textFieldStyle(.plain)
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private var stampsRulesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            startGameRewardRow
            stampsPassageRewardRow(
                passageLabel: "5ᵉ",
                reward: pack.stampMidRewardLabel,
                prompt: Self.stamp5PassageRewardPlaceholder
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("5ᵉ passage, récompense"))
            stampsPassageRewardRow(
                passageLabel: "10ᵉ",
                reward: pack.stampRewardLabel,
                prompt: Self.stamp10PassageRewardPlaceholder
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("10ᵉ passage, récompense"))
        }
    }

    // MARK: - Membre

    private var memberColumnBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("", text: pack.labelMember, prompt: Text("Membre").foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            if !cardImageSuggestedColors.isEmpty {
                Text("Même palette que ci-dessus : couleurs détectées dans vos images.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            LabeledCanvaColorPalette(title: "Titres", hex: pack.labelHex, imageSuggestions: cardImageSuggestedColors)
            LabeledCanvaColorPalette(title: "Textes", hex: pack.accentHex, imageSuggestions: cardImageSuggestedColors)
        }
    }

    // MARK: - Verso pass

    private var walletPassBackBlock: some View {
        Group {
            if dashboardSettingsHydrated {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: pack.backTerms)
                        .frame(minHeight: 72)
                        .padding(8)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(Text("Conditions et mentions, verso du pass"))
                    TextEditor(text: pack.backContact)
                        .frame(minHeight: 56)
                        .padding(8)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .accessibilityLabel(Text("Contact, verso du pass"))
                    TextField("", text: pack.notificationTitleOverride, prompt: Text("Titre notification").foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    TextField("", text: pack.notificationChangeMessage, prompt: Text("Message changement pass").foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85)))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
        }
    }
}
