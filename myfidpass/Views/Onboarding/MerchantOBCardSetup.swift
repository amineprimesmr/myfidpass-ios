//
//  MerchantOBCardSetup.swift
//  myfidpass
//
//  Onboarding carte : mode → logo → fond/tampons → couleurs → aperçu.
//

import PhotosUI
import SwiftUI
import UIKit

// MARK: - Persistance API

enum MerchantOBCardSettingsSaver {
    @MainActor
    static func resolveSlug(authService: AuthService) async -> String? {
        await APIClient.shared.ensureValidAccessToken()
        await authService.bootstrapAuthenticatedSessionIfNeeded(force: true)
        await authService.refreshBusinessesIfNeeded(force: true)
        if let saved = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
           !saved.isEmpty {
            return saved
        }
        if let first = authService.businesses.first?.slug.trimmingCharacters(in: .whitespacesAndNewlines),
           !first.isEmpty {
            AuthStorage.currentBusinessSlug = first
            return first
        }
        return nil
    }

    @MainActor
    static func saveBestEffort(from draft: MerchantOBCardDraft, authService: AuthService) async {
        guard let slug = await resolveSlug(authService: authService) else { return }
        try? await save(from: draft, slug: slug)
    }

    static func save(from draft: MerchantOBCardDraft, slug: String) async throws {
        let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSlug.isEmpty else {
            throw AuthError.apiMessage("Commerce introuvable. Réessayez.")
        }

        var working = draft
        working.applyDefaultRewardsForCurrentMode()

        let nameFinal = working.resolvedDisplayName
        let bgHex = working.primaryHex.strippingHash
        let fgHex = working.accentHex.strippingHash
        let labelForAPI = working.labelHex.strippingHash

        var patch = FullDashboardSettingsPatch()
        patch.organizationName = nameFinal
        patch.backgroundColor = bgHex
        patch.foregroundColor = fgHex
        patch.labelColor = labelForAPI
        patch.programType = working.programType
        patch.stripColor = bgHex
        patch.stripDisplayMode = "logo"
        patch.welcomeBonusEnabled = 1
        patch.welcomeBonusAmount = working.programType == "stamps" ? 1 : 10

        if working.programType == "stamps" {
            patch.requiredStamps = max(1, working.requiredStamps)
            patch.stampRewardLabel = String(working.stampRewardLabel.prefix(120))
            let mid = working.stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            if working.requiredStamps > 5 {
                patch.stampMidRewardLabel = mid.isEmpty ? nil : String(mid.prefix(120))
            } else {
                patch.stampMidRewardLabelIsExplicitNull = true
            }
            patch.stampEmoji = working.stampEmoji.isEmpty ? "cafe" : String(working.stampEmoji.prefix(32))
            // Tampons : pas d’image de fond carte (réservée au mode points).
            patch.cardBackgroundBase64 = ""
        } else {
            patch.pointsPerEuro = 1
            patch.pointsPerVisit = 1
            patch.loyaltyMode = "points_cash"
            patch.pointsRewardTiers = working.resolvedPointsTiers
        }

        if let path = working.logoLocalPath?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty,
           let b64 = CardLogoStorage.compressedWalletStripLogoBase64FromFile(path: path) {
            patch.logoBase64 = b64
            if let iconB64 = CardLogoStorage.compressedBase64LogoIconFromFile(path: path) {
                patch.logoIconBase64 = iconB64
            }
        }

        if working.programType == "points",
           let bgPath = working.cardBackgroundLocalPath?.trimmingCharacters(in: .whitespacesAndNewlines),
           !bgPath.isEmpty,
           let bg64 = CardLogoStorage.compressedBase64FromFile(path: bgPath) {
            patch.cardBackgroundBase64 = bg64
        }

        struct PatchOk: Decodable { let ok: Bool? }
        _ = try await APIClient.shared.request(
            .patchDashboardSettings(slug: trimmedSlug, patch: patch),
            responseType: PatchOk.self
        )
        let snapshotDraft = working
        await persistDisplaySnapshot(from: snapshotDraft, slug: trimmedSlug)
    }

    @MainActor
    private static func persistDisplaySnapshot(from draft: MerchantOBCardDraft, slug: String) {
        var working = draft
        working.applyDefaultRewardsForCurrentMode()
        let hasLocalBG = working.programType == "points"
            && (working.cardBackgroundLocalPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
        let snap = CardPreviewDisplaySnapshot(
            programType: working.programType,
            displayName: working.resolvedDisplayName,
            primaryHex: working.primaryHex.strippingHash,
            accentHex: working.accentHex.strippingHash,
            labelHex: working.labelHex.strippingHash,
            stripHex: "",
            stripDisplayMode: "logo",
            stripText: "",
            logoURL: working.logoLocalPath ?? "",
            stampEmoji: working.stampEmoji,
            requiredStamps: max(1, working.requiredStamps),
            headerRightText: CardRewardsHeaderLink.displayText,
            labelMember: "",
            hasRemoteCardBackground: false,
            cardBackgroundRemoteURL: nil,
            hasLocalCardBackground: hasLocalBG ? true : nil,
            stampRewardLabel: working.stampRewardLabel,
            stampMidRewardLabel: working.stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? nil : working.stampMidRewardLabel,
            startGameRewardLabel: nil,
            labelRestants: nil,
            tierPoints: nil,
            tierLabels: nil,
            stampIconPendingBase64: nil,
            stampIconWasRemoved: nil,
            hasServerStampIcon: false
        )
        CardPreviewDisplaySnapshotStore.save(snap, slug: slug)
    }
}

struct MerchantOBCardDraft {
    var displayName: String = ""
    var programType: String = "points"
    var requiredStamps: Int = 10
    var stampRewardLabel: String = ""
    var stampMidRewardLabel: String = ""
    var heroTier1Points: String = "50"
    var heroTier1Label: String = ""
    var heroTier2Points: String = "100"
    var heroTier2Label: String = ""
    var stampEmoji: String = "cafe"
    var logoLocalPath: String?
    var cardBackgroundLocalPath: String?
    var primaryHex: String = AppTheme.WalletCardAppearanceDefaults.backgroundHex
    var accentHex: String = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
    var labelHex: String = AppTheme.WalletCardAppearanceDefaults.labelTitlesHex

    var resolvedDisplayName: String {
        let t = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Ma Carte Fidélité" : t
    }

    mutating func applyDefaultRewardsForCurrentMode() {
        if programType == "stamps" {
            if stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stampRewardLabel = "Une récompense offerte"
            }
            if requiredStamps < 5 { requiredStamps = 10 }
            if requiredStamps > 5,
               stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stampMidRewardLabel = "−50 % sur un article"
            }
            if stampEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                stampEmoji = "cafe"
            }
        } else {
            if heroTier1Label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                heroTier1Label = "Un café offert"
                heroTier1Points = "50"
            }
            if heroTier2Label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                heroTier2Label = "Un dessert offert"
                heroTier2Points = "100"
            }
        }
    }

    var resolvedPointsTiers: [PointsRewardTierPayload] {
        var working = self
        working.applyDefaultRewardsForCurrentMode()
        let presets: [(String, String)] = [
            (working.heroTier1Points, working.heroTier1Label),
            (working.heroTier2Points, working.heroTier2Label),
            ("150", "10 % de réduction"),
            ("200", "15 % de réduction"),
            ("250", "Un repas offert"),
        ]
        var tiers: [PointsRewardTierPayload] = []
        for (ptsStr, lab) in presets {
            guard let pts = Int(ptsStr.trimmingCharacters(in: .whitespaces)) else { continue }
            let labT = lab.trimmingCharacters(in: .whitespaces)
            guard !labT.isEmpty else { continue }
            tiers.append(.init(points: pts, label: String(labT.prefix(120))))
        }
        return tiers.sorted { $0.points < $1.points }
    }

    var hasLogo: Bool {
        !(logoLocalPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    var hasBackground: Bool {
        !(cardBackgroundLocalPath?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
}

private extension String {
    var strippingHash: String {
        hasPrefix("#") ? String(dropFirst()) : self
    }
}

// MARK: - Aperçu live

struct MerchantOBCardLivePreview: View {
    let draft: MerchantOBCardDraft

    private var effectiveDraft: MerchantOBCardDraft {
        var copy = draft
        copy.applyDefaultRewardsForCurrentMode()
        return copy
    }

    var body: some View {
        let d = effectiveDraft
        Group {
            if d.programType == "stamps" {
                CafeDesArtsCardPreview(
                    displayName: d.resolvedDisplayName,
                    requiredStamps: Int32(max(1, d.requiredStamps)),
                    stampsCount: min(3, Int32(max(1, d.requiredStamps))),
                    primaryColorHex: d.primaryHex,
                    accentColorHex: d.accentHex,
                    logoURL: d.logoLocalPath,
                    stampEmoji: d.stampEmoji,
                    labelColorHex: d.labelHex,
                    stampMidRewardLabel: d.stampMidRewardLabel,
                    stampRewardLabel: d.stampRewardLabel,
                    compact: true
                )
            } else {
                WalletCardPreview(
                    displayName: d.resolvedDisplayName,
                    requiredStamps: 10,
                    stampsCount: 0,
                    primaryColorHex: d.primaryHex,
                    accentColorHex: d.accentHex,
                    logoURL: d.logoLocalPath,
                    cardBackgroundImagePath: d.cardBackgroundLocalPath,
                    labelColorHex: d.labelHex,
                    compact: true
                )
            }
        }
        .frame(maxWidth: 320)
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
        .padding(.vertical, 8)
    }
}

// MARK: - Étape 1 — Mode (points / tampons)

struct MerchantOBCardProgramStepContent: View {
    @Binding var draft: MerchantOBCardDraft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                MerchantOBCardLivePreview(draft: draft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                MyfidpassOnboardingStepContainer(
                    title: "Mode de la carte",
                    subtitle: "Choisissez comment vos clients cumulent leurs avantages."
                ) {
                    VStack(spacing: 12) {
                        programCard(
                            type: "points",
                            title: "Points",
                            subtitle: "Cumulez des points à chaque passage ou achat.",
                            symbol: "star.circle.fill"
                        )
                        programCard(
                            type: "stamps",
                            title: "Tampons",
                            subtitle: "Une case tamponnée à chaque visite.",
                            symbol: "square.grid.3x3.fill"
                        )
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private func programCard(type: String, title: String, subtitle: String, symbol: String) -> some View {
        let selected = draft.programType == type
        return Button {
            withAnimation(.onboardingTransitionFast) {
                draft.programType = type
            }
            HapticManager.shared.impact(.light)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(selected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary.opacity(0.35))
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? AppTheme.Colors.primary.opacity(0.08) : Color.white.opacity(0.72))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(selected ? AppTheme.Colors.primary.opacity(0.45) : Color.black.opacity(0.06), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Étape 2 — Logo

struct MerchantOBCardLogoStepContent: View {
    @Binding var draft: MerchantOBCardDraft
    @Binding var logoPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                MerchantOBCardLivePreview(draft: draft)
                    .frame(maxWidth: .infinity)

                MyfidpassOnboardingStepContainer(
                    title: "Votre logo",
                    subtitle: "Il apparaît en haut de la carte dans le Wallet."
                ) {
                    VStack(spacing: 16) {
                        PhotosPicker(selection: $logoPhotoItem, matching: .images) {
                            logoPickerTile
                        }
                        .buttonStyle(.plain)

                        Text("Vous pourrez le remplacer à tout moment dans Ma carte.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private var logoPickerTile: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                    .frame(height: 140)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(
                                draft.hasLogo ? AppTheme.Colors.success.opacity(0.45) : Color.black.opacity(0.08),
                                lineWidth: draft.hasLogo ? 2 : 1
                            )
                    }

                if draft.hasLogo, let path = draft.logoLocalPath,
                   let ui = UIImage(contentsOfFile: path) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                        Text("Appuyez pour ajouter")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }

            HStack {
                Text(draft.hasLogo ? "Logo ajouté — toucher pour changer" : "Ajouter le logo du commerce")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer()
                if draft.hasLogo {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
        }
    }
}

// MARK: - Étape 3 — Fond (points) ou tampons

struct MerchantOBCardMediaStepContent: View {
    @Binding var draft: MerchantOBCardDraft
    @Binding var backgroundPhotoItem: PhotosPickerItem?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                MerchantOBCardLivePreview(draft: draft)
                    .frame(maxWidth: .infinity)

                MyfidpassOnboardingStepContainer(
                    title: draft.programType == "stamps" ? "Icône des tampons" : "Image de fond",
                    subtitle: draft.programType == "stamps"
                        ? "Choisissez l’icône affichée sur chaque case."
                        : "Une photo qui habille le centre de votre carte points."
                ) {
                    if draft.programType == "stamps" {
                        stampIconGrid
                    } else {
                        backgroundPicker
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private var backgroundPicker: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $backgroundPhotoItem, matching: .images) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                        .frame(height: 160)
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(
                                    draft.hasBackground ? AppTheme.Colors.success.opacity(0.45) : Color.black.opacity(0.08),
                                    lineWidth: draft.hasBackground ? 2 : 1
                                )
                        }

                    if draft.hasBackground, let path = draft.cardBackgroundLocalPath,
                       let ui = UIImage(contentsOfFile: path) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 30, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.primary)
                            Text("Choisir une photo")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Text("Optionnel — une image par défaut sera utilisée si vous passez cette étape.")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var stampIconGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(minimum: 34, maximum: 56), spacing: 10), count: 5)
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(StampIconCatalog.selectableKeys.prefix(15), id: \.self) { key in
                Button {
                    draft.stampEmoji = key
                    HapticManager.shared.impact(.light)
                } label: {
                    StampIconView(stampEmoji: key, size: 34, tint: AppTheme.Colors.textPrimary)
                        .frame(height: 52)
                        .frame(maxWidth: .infinity)
                        .background(
                            draft.stampEmoji == key
                                ? AppTheme.Colors.primary.opacity(0.16)
                                : Color.white.opacity(0.82),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    draft.stampEmoji == key ? AppTheme.Colors.primary.opacity(0.5) : Color.black.opacity(0.06),
                                    lineWidth: draft.stampEmoji == key ? 2 : 1
                                )
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Étape 4 — Couleurs

struct MerchantOBCardColorsStepContent: View {
    @Binding var draft: MerchantOBCardDraft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                MerchantOBCardLivePreview(draft: draft)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                MyfidpassOnboardingStepContainer(
                    title: "Couleurs de la carte",
                    subtitle: "Ajustez le fond, le texte et les titres — l’aperçu se met à jour en direct."
                ) {
                    VStack(alignment: .leading, spacing: 22) {
                        colorSection(title: "Fond de la carte", hex: $draft.primaryHex)
                        colorSection(title: "Texte principal", hex: $draft.accentHex)
                        colorSection(title: "Titres (Points, Membre…)", hex: $draft.labelHex)
                    }
                }
            }
            .padding(.bottom, 120)
        }
    }

    private func colorSection(title: String, hex: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            CanvaStylePaletteRow(hex: hex, compactEmbedded: true)
        }
    }
}

// MARK: - Étape 5 — Aperçu final

struct MerchantOBCardPreviewStepContent: View {
    let draft: MerchantOBCardDraft
    var infoMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                MyfidpassOnboardingStepContainer(
                    title: "Votre carte est prête",
                    subtitle: "Elle apparaîtra ainsi dans le Wallet de vos clients."
                ) {
                    EmptyView()
                }

                MerchantOBCardLivePreview(draft: draft)
                    .scaleEffect(1.04)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)

                if let infoMessage, !infoMessage.isEmpty {
                    Text(infoMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Text("Vous pourrez affiner paliers, notifications et récompenses dans Ma carte.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }
            .padding(.bottom, 120)
        }
    }
}
