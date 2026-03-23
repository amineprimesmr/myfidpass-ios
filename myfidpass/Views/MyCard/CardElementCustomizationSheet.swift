//
//  CardElementCustomizationSheet.swift
//  myfidpass
//
//  Feuille modale de personnalisation par zone de la carte (tap sur l’aperçu).
//

import SwiftUI
import Photos
import PhotosUI
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
    let headerRightText: Binding<String>
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
    let stampRewardLabel: Binding<String>
    let stampMidRewardLabel: Binding<String>
    let stampSkipMidReward: Binding<Bool>
    let stampIconPhotoItem: Binding<PhotosPickerItem?>
    let backTerms: Binding<String>
    let backContact: Binding<String>
    let notificationTitleOverride: Binding<String>
    let notificationChangeMessage: Binding<String>
}

struct CardCustomizationActions {
    let loadLogoFromPicker: (PhotosPickerItem?) async -> Void
    let loadLogoFromPhotoAsset: (PHAsset) async -> Void
    let loadCardBackgroundFromPicker: (PhotosPickerItem?) async -> Void
    let loadCardBackgroundFromPhotoAsset: (PHAsset) async -> Void
    let loadStampIconFromPicker: (PhotosPickerItem?) async -> Void
    let removeCardBackground: () -> Void
    let removeLogo: () -> Void
    let resetStampIcon: () -> Void
}

// MARK: - Feuille

struct CardElementCustomizationSheet: View {
    let zone: CardPreviewEditZone
    let pack: CardCustomizationBindPack
    let actions: CardCustomizationActions
    var logoDominantColors: [String]
    var dashboardSettingsHydrated: Bool
    var onClose: () -> Void
    var onSave: () async -> Bool

    @State private var isSaving = false
    @State private var savedFlash = false

    @State private var flyerAPIBusy = false
    @State private var flyerBootstrapBase64: String?
    @State private var flyerPreviewFailed = false
    @State private var flyerWebRendering = true

    /// Même gabarit de feuille que le logo : pas de sélecteurs de couleur, hauteur initiale compacte.
    private var usesCompactImagePickerSheet: Bool {
        zone == .logoBand || zone == .backgroundImage
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: usesCompactImagePickerSheet ? 12 : 18) {
                    zoneBody
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.vertical, usesCompactImagePickerSheet ? 10 : 16)
                .padding(.bottom, usesCompactImagePickerSheet ? 12 : 28)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle(zone.customizationSheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") {
                        onClose()
                    }
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            guard !isSaving else { return }
                            isSaving = true
                            let ok = await onSave()
                            await MainActor.run {
                                isSaving = false
                                if ok {
                                    savedFlash = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                        onClose()
                                    }
                                }
                            }
                        }
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else if savedFlash {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Text("Enregistrer")
                        }
                    }
                    .disabled(isSaving)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents(
            usesCompactImagePickerSheet
                ? [.height(zone == .backgroundImage ? 400 : 340), .large]
                : [.medium, .large]
        )
        .presentationDragIndicator(.visible)
        .modifier(LiquidGlassSheetModifier())
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
        case .rewardColumn:
            rewardColumnBlock
        case .memberColumn:
            memberColumnBlock
        case .qrCode:
            qrCodeBlock
        case .walletPassBack:
            walletPassBackBlock
        }
    }

    // MARK: - Logo (carrousel récents + liste d’actions type iOS)

    private var logoBandBlock: some View {
        Group {
            if pack.stripDisplayMode.wrappedValue == "text" {
                logoBandTextModeContent
            } else {
                logoBandImageModeContent
            }
        }
    }

    private var logoBandTextModeContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Nom affiché sur la carte", text: pack.stripText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                )
            logoImageModeActionShell {
                Button {
                    pack.stripDisplayMode.wrappedValue = "logo"
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title3)
                            .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            .frame(width: 36, alignment: .center)
                        Text("Utiliser une image")
                            .font(.body)
                            .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .padding(.vertical, 16)
                    .padding(.horizontal, 14)
                }
                .accessibilityLabel(Text("Utiliser une image à la place du texte"))
            }
        }
    }

    private var logoBandImageModeContent: some View {
        let logoRef = pack.logoURL.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasLogo = !logoRef.isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            LogoRecentPhotosCarousel(
                currentLogoRef: pack.logoURL.wrappedValue,
                hasLogo: hasLogo
            ) { asset in
                Task { await actions.loadLogoFromPhotoAsset(asset) }
            }
            logoImageModeActionShell {
                VStack(spacing: 0) {
                    Button {
                        pack.stripDisplayMode.wrappedValue = "text"
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "textformat")
                                .font(.title3)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .frame(width: 36, alignment: .center)
                            Text("Texte")
                                .font(.body)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                    }
                    .accessibilityLabel(Text("Afficher un texte à la place du logo"))

                    Divider()
                        .padding(.leading, 64)

                    PhotosPicker(selection: pack.logoPhotoItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 36, alignment: .center)
                            Text("Choisir depuis la galerie")
                                .font(.body)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                    }
                    .accessibilityLabel(Text("Choisir depuis la galerie"))
                    .onChange(of: pack.logoPhotoItem.wrappedValue) { _, new in
                        Task { await actions.loadLogoFromPicker(new) }
                    }

                    if hasLogo {
                        Divider()
                            .padding(.leading, 64)
                        Button {
                            actions.removeLogo()
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
                        .accessibilityLabel(Text("Supprimer le logo"))
                    }
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

    private var logoDominantSwatchesRow: some View {
        HStack(spacing: 12) {
            ForEach(logoDominantColors, id: \.self) { hex in
                let normalized = hex.hasPrefix("#") ? hex : "#" + hex
                let primNorm = pack.primaryHex.wrappedValue.trimmingCharacters(in: CharacterSet(charactersIn: "#").inverted)
                let hexNorm = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#").inverted)
                let isSelected = primNorm.lowercased() == hexNorm.lowercased()
                Button {
                    pack.primaryHex.wrappedValue = normalized
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().strokeBorder(isSelected ? AppTheme.Colors.primary : Color.clear, lineWidth: 3))
                }
            }
        }
    }

    // MARK: - Haut droite

    private var headerRightBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Texte affiché en haut à droite du bandeau (ex. lien récompenses).")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Récompenses ↗", text: pack.headerRightText)
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1))
        }
    }

    // MARK: - Image de fond (même logique que le logo : carrousel + liste, sans couleurs)

    private var backgroundImageBlock: some View {
        let path = pack.cardBackgroundImagePath.wrappedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let remote = pack.cardBackgroundRemoteURL.wrappedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let bgRef = !path.isEmpty ? path : remote
        let hasBackground = !bgRef.isEmpty
        return VStack(alignment: .leading, spacing: 14) {
            Text("L’image remplace la zone visuelle points / tampons sur la carte (comme sur le web). Les couleurs se règlent via « Autres réglages » → Couleurs.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            LogoRecentPhotosCarousel(
                currentLogoRef: bgRef,
                hasLogo: hasBackground
            ) { asset in
                Task { await actions.loadCardBackgroundFromPhotoAsset(asset) }
            }
            logoImageModeActionShell {
                VStack(spacing: 0) {
                    PhotosPicker(selection: pack.cardBackgroundPhotoItem, matching: .images, photoLibrary: .shared()) {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                                .frame(width: 36, alignment: .center)
                            Text("Choisir depuis la galerie")
                                .font(.body)
                                .foregroundStyle(Color(red: 0, green: 0.48, blue: 1))
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                    }
                    .accessibilityLabel(Text("Choisir une image de fond depuis la galerie"))
                    .onChange(of: pack.cardBackgroundPhotoItem.wrappedValue) { _, new in
                        Task { await actions.loadCardBackgroundFromPicker(new) }
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

    // MARK: - Règles du programme (tap zone points / tampons)

    private var mainMetricsBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Type de programme", selection: pack.programType) {
                Text("Points").tag("points")
                Text("Tampons").tag("stamps")
            }
            .pickerStyle(.segmented)
            .onChange(of: pack.programType.wrappedValue) { _, new in
                if new == "stamps" {
                    pack.requiredStamps.wrappedValue = 10
                    if pack.previewStampsCount.wrappedValue > 10 { pack.previewStampsCount.wrappedValue = 10 }
                }
            }

            if pack.programType.wrappedValue == "points" {
                pointsRulesContent
            } else {
                stampsRulesContent
            }
        }
    }

    // MARK: - Couleurs (menu Autres réglages)

    private var cardAppearanceBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !logoDominantColors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggestions depuis votre logo")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    logoDominantSwatchesRow
                }
            }
            ColorPickerRow(title: "Fond", hex: pack.primaryHex)
            ColorPickerRow(title: "Texte principal", hex: pack.accentHex)
            ColorPickerRow(title: "Libellés", hex: pack.labelHex)
        }
    }

    private var pointsRulesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Paliers sur la carte")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            ForEach(0..<5, id: \.self) { i in
                pointsTierRow(index: i)
            }
        }
    }

    private static let tierSeuilExamples = ["10", "50", "100", "200", "500"]
    private static let tierRewardExamples = [
        "1 café offert",
        "Menu midi offert",
        "-10 % sur l’addition",
        "Dessert au choix",
        "Carte VIP 1 mois"
    ]

    private func pointsTierRow(index: Int) -> some View {
        let seuilPrompt = "ex. \(Self.tierSeuilExamples[index])"
        let rewardPrompt = "ex. \(Self.tierRewardExamples[index])"
        return VStack(alignment: .leading, spacing: 8) {
            Text("Palier \(index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
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

    private var stampsRulesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("La grille compte 10 tampons par carte (comme sur le web).")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Emoji ou icône sur les tampons")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StampEmojiPresets.all, id: \.self) { emoji in
                        Button {
                            pack.stampEmoji.wrappedValue = pack.stampEmoji.wrappedValue == emoji ? "" : emoji
                        } label: {
                            StampIconView(stampEmoji: emoji, size: 36, tint: AppTheme.Colors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background((pack.stampEmoji.wrappedValue == emoji ? AppTheme.Colors.primary.opacity(0.2) : Color.clear))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    Button {
                        pack.stampEmoji.wrappedValue = ""
                    } label: {
                        Text("Aucun")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 60, height: 44)
                            .background(pack.stampEmoji.wrappedValue.isEmpty ? AppTheme.Colors.primary.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.vertical, 4)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Icône tampon personnalisée (image)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                HStack(spacing: 12) {
                    PhotosPicker(selection: pack.stampIconPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Label("Importer", systemImage: "photo")
                            .font(.callout)
                    }
                    .onChange(of: pack.stampIconPhotoItem.wrappedValue) { _, new in
                        Task { await actions.loadStampIconFromPicker(new) }
                    }
                    Button("Réinitialiser") {
                        actions.resetStampIcon()
                    }
                    .font(.caption)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("5ᵉ tampon")
                    .font(.caption.weight(.semibold))
                Toggle("Pas de récompense à la 5ᵉ visite", isOn: pack.stampSkipMidReward)
                    .font(.subheadline)
                    .onChange(of: pack.stampSkipMidReward.wrappedValue) { _, skip in
                        if skip { pack.stampMidRewardLabel.wrappedValue = "" }
                    }
                TextField("Récompense intermédiaire (5ᵉ)", text: pack.stampMidRewardLabel)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(pack.stampSkipMidReward.wrappedValue)
                    .opacity(pack.stampSkipMidReward.wrappedValue ? 0.45 : 1)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("10ᵉ tampon — récompense carte complète")
                    .font(.caption.weight(.semibold))
                TextField("ex. Menu offert", text: pack.stampRewardLabel)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(AppTheme.Colors.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Récompenses (sous-ensemble règles)

    private var rewardColumnBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Contenu affiché sous « Récompense » sur la carte.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if pack.programType.wrappedValue == "points" {
                ForEach(0..<5, id: \.self) { i in
                    pointsTierRow(index: i)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Pas de récompense à la 5ᵉ visite", isOn: pack.stampSkipMidReward)
                        .font(.subheadline)
                        .onChange(of: pack.stampSkipMidReward.wrappedValue) { _, skip in
                            if skip { pack.stampMidRewardLabel.wrappedValue = "" }
                        }
                    TextField("Récompense intermédiaire (5ᵉ)", text: pack.stampMidRewardLabel)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .disabled(pack.stampSkipMidReward.wrappedValue)
                        .opacity(pack.stampSkipMidReward.wrappedValue ? 0.45 : 1)
                    TextField("Récompense 10ᵉ tampon", text: pack.stampRewardLabel)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            Text("Couleur de fond : touchez une zone vide du fond coloré (autour du QR, sous les champs…) ou « Autres réglages » → Couleurs. Règles du programme : touchez uniquement Points ou la grille de tampons.")
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
    }

    // MARK: - Membre

    private var memberColumnBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Nom du commerce (aperçu carte)")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Ma Carte Fidélité", text: pack.displayName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Titre au-dessus du nom client (colonne droite)")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Membre", text: pack.labelMember)
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text("Libellé mode tampons (ex. tampons restants)")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            TextField("Restants", text: pack.labelRestants)
                .textFieldStyle(.plain)
                .padding(10)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            ColorPickerRow(title: "Couleur des libellés", hex: pack.labelHex)
        }
    }

    // MARK: - QR / lien

    private var qrCodeBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let slug = AuthStorage.currentBusinessSlug,
               let pageURL = LegalURLs.fidelityCardPage(slug: slug) {
                Text("Lien où vos clients ajoutent la carte (identique au QR).")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(pageURL.absoluteString)
                    .font(.caption)
                    .textSelection(.enabled)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = pageURL.absoluteString
                    } label: {
                        Label("Copier le lien", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    ShareLink(item: pageURL) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                qrFlyerPreviewSection(slug: slug)
            } else {
                Text("Connectez-vous et chargez un commerce pour afficher votre lien FidPass.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    @ViewBuilder
    private func qrFlyerPreviewSection(slug: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flyer QR code")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.top, 8)
            Text("Même design que l’onglet « Flyer QR » du tableau de bord : synchronisé sur le serveur. Modifiez-le sur le web ou dans le SaaS ; l’aperçu se met à jour à la réouverture de cette feuille.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if flyerPreviewFailed {
                Text("Impossible de charger l’aperçu du flyer. Vérifiez la connexion ou réessayez.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            } else if flyerAPIBusy && flyerBootstrapBase64 == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if let b64 = flyerBootstrapBase64, !b64.isEmpty {
                ZStack {
                    FlyerPreviewWebView(bootstrapBase64: b64, isLoading: $flyerWebRendering)
                        .aspectRatio(2400 / 3600, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    if flyerWebRendering {
                        ProgressView()
                            .padding(20)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                .frame(maxHeight: 440)
            }

            if let url = URL(string: "https://myfidpass.fr/app#flyer-qr") {
                Link(destination: url) {
                    Label("Personnaliser le flyer sur le web", systemImage: "safari")
                }
                .font(.subheadline)
            }
        }
        .onAppear {
            Task { await refreshFlyerBootstrapIfNeeded(slug: slug) }
        }
    }

    private func refreshFlyerBootstrapIfNeeded(slug: String) async {
        guard AuthStorage.isLoggedIn, !slug.isEmpty else { return }
        await MainActor.run {
            flyerAPIBusy = true
            flyerPreviewFailed = false
        }
        do {
            let data = try await APIClient.shared.requestData(.dashboardFlyerGet(slug: slug))
            let b64 = data.base64EncodedString()
            await MainActor.run {
                flyerBootstrapBase64 = b64
                flyerWebRendering = true
                flyerAPIBusy = false
            }
        } catch {
            await MainActor.run {
                flyerPreviewFailed = true
                flyerBootstrapBase64 = nil
                flyerAPIBusy = false
            }
        }
    }

    // MARK: - Verso pass

    private var walletPassBackBlock: some View {
        Group {
            if dashboardSettingsHydrated {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Conditions / mentions (verso du pass)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    TextEditor(text: pack.backTerms)
                        .frame(minHeight: 72)
                        .padding(8)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Text("Contact (verso)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    TextEditor(text: pack.backContact)
                        .frame(minHeight: 56)
                        .padding(8)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    TextField("Titre notification pass (optionnel)", text: pack.notificationTitleOverride)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    TextField("Message changement pass", text: pack.notificationChangeMessage)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(AppTheme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text("Chargement des réglages…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
    }
}
