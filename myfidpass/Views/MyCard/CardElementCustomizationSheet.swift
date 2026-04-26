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
    let stampRewardLabel: Binding<String>
    let stampMidRewardLabel: Binding<String>
    /// Palier « Début du jeu » (non modifiable côté seuil, récompense éditable). Commun aux modes points et tampons.
    let startGameRewardLabel: Binding<String>
    let backTerms: Binding<String>
    let backContact: Binding<String>
    let notificationTitleOverride: Binding<String>
    let notificationChangeMessage: Binding<String>
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
    /// État local pour la feuille de cadrage (évite les problèmes de présentation avec un `Binding` parent).
    @State private var cropEditorPayload: ImageCropPayload?
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
            /// Récompenses (2 lignes tampons ou paliers points) ; `.large` si besoin.
            return [.medium, .large]
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

    private var logoBandBlock: some View {
        logoBandImageModeContent
    }

    private var logoBandImageModeContent: some View {
        VStack(alignment: .leading, spacing: 10) {
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
            rewardRulesContent
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

                ForEach(StampIconCatalog.selectableKeys, id: \.self) { iconKey in
                    Button {
                        pack.stampEmoji.wrappedValue = iconKey
                        actions.resetStampIcon(iconKey)
                    } label: {
                        StampIconView(stampEmoji: iconKey, size: 40, tint: AppTheme.Colors.textPrimary)
                            .frame(height: 48)
                            .frame(maxWidth: .infinity)
                            .background(
                                (selectedIconKey == iconKey ? AppTheme.Colors.primary.opacity(0.2) : Color.clear)
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
                Text("Pastilles tout à gauche (après +) = couleurs tirées du logo et du fond ; à droite, palette générale.")
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
            startGameRewardRow
            /// 3 paliers modifiables (hors « Début du jeu ») — ex. 30 € / 60 € / 100 €.
            ForEach(0..<Self.pointsTierRowCount, id: \.self) { i in
                pointsTierRow(index: i)
            }
        }
    }

    /// Palier « Début du jeu » (1ʳᵉ récompense) : seuil verrouillé, libellé de récompense modifiable par le commerçant.
    private var startGameRewardRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("Début du jeu")
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
                prompt: Text(Self.startGameRewardPlaceholder).foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.85))
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

    private static let startGameRewardPlaceholder = "Boisson offerte"
    private static let pointsTierRowCount = 3
    /// Seuils (points) — ex. 30 / 60 / 100, librement modifiables.
    private static let tierSeuilExamples = ["30", "60", "100"]
    private static let tierRewardExamples = [
        "Dessert offert",
        "Sandwich au choix",
        "Menu + dessert offert"
    ]

    private static let stamp5PassageRewardPlaceholder = "-50% sur l’addition"
    private static let stamp10PassageRewardPlaceholder = "Menu offert"

    private func pointsTierRow(index: Int) -> some View {
        let seuilPrompt = Self.tierSeuilExamples[index]
        let rewardPrompt = Self.tierRewardExamples[index]
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
