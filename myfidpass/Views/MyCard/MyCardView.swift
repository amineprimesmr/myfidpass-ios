//
//  MyCardView.swift
//  myfidpass
//
//  Aperçu en direct et personnalisation de la carte wallet. UX centrée sur le rendu temps réel.
//

import SwiftUI
import CoreData
import PassKit
import Photos
import PhotosUI
import UIKit

enum CardPreviewFormat: String, CaseIterable {
    case wallet
    case creditCard
    case stampGrid
    /// Design dédié avec grille de tampons visible (Café des Arts).
    case cafeDesArts
}

/// Modifier pour adopter le style Liquid Glass natif des sheets sur iOS 26 (coins système, pas de fond opaque).
struct LiquidGlassSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.presentationCornerRadius(nil)
        } else {
            content
        }
    }
}

/// Aperçu d’une image depuis une URL (http) ou un chemin local (logo ou image de fond).
struct CardImagePreviewView: View {
    let urlOrPath: String
    var body: some View {
        let trimmed = urlOrPath.trimmingCharacters(in: .whitespaces)
        Group {
            if trimmed.isEmpty {
                EmptyView()
            } else if let filePath = resolvedFilePath(trimmed) {
                LocalImagePreviewView(path: filePath)
            } else if let url = resolvedHTTPURL(trimmed), isAPILogoURL(url) {
                AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed), isAPICardBackgroundURL(url) {
                AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        Color.gray.opacity(0.2)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                LocalImagePreviewView(path: urlOrPath)
            }
        }
        .id(trimmed)
    }

    /// URL absolue ou chemin `/api/...` renvoyé seul par le backend.
    private func resolvedHTTPURL(_ s: String) -> URL? {
        if let u = URL(string: s), u.scheme == "http" || u.scheme == "https" { return u }
        if s.hasPrefix("/"), let u = URL(string: s, relativeTo: APIConfig.baseURL)?.absoluteURL,
           u.scheme == "http" || u.scheme == "https" {
            return u
        }
        return nil
    }
    private func resolvedFilePath(_ path: String) -> String? {
        if path.contains("CardLogos"), let full = CardLogoStorage.fullPath(forRelative: path) { return full }
        if path.hasPrefix("/") { return path }
        if path.hasPrefix("file:"), let p = URL(string: path)?.path { return p }
        if let full = CardLogoStorage.fullPath(forRelative: path) { return full }
        return nil
    }
    private func isAPILogoURL(_ url: URL) -> Bool {
        (url.scheme == "http" || url.scheme == "https") && url.host() == APIConfig.baseURL.host() && url.path.contains("/logo")
    }

    private func isAPICardBackgroundURL(_ url: URL) -> Bool {
        (url.scheme == "http" || url.scheme == "https") && url.host() == APIConfig.baseURL.host() && url.path.contains("card-background")
    }
}

private struct LocalImagePreviewView: View {
    let path: String
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .onAppear { loadImage() }
        .onChange(of: path) { _, _ in loadImage() }
    }
    private func loadImage() {
        let fullPath = path.hasPrefix("/") || path.hasPrefix("file:") ? (path.hasPrefix("file:") ? (URL(string: path)?.path ?? path) : path) : (CardLogoStorage.fullPath(forRelative: path) ?? path)
        image = UIImage(contentsOfFile: fullPath)
    }
}

struct MyCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var displayName: String = ""
    @State private var requiredStamps: Int = 10
    @State private var primaryHex: String = "2563EB"
    @State private var accentHex: String = "F59E0B"
    /// Couleur des libellés (RÉCOMPENSE, MEMBRE, etc.). Si vide, blanc/opacité par défaut.
    @State private var labelHex: String = ""
    /// "logo" = image logo, "text" = texte à la place du logo dans le bandeau.
    @State private var stripDisplayMode: String = "logo"
    /// Texte affiché dans le bandeau quand stripDisplayMode == "text".
    @State private var stripText: String = ""
    @State private var logoURL: String = ""
    @State private var stampEmoji: String = ""
    @State private var logoPhotoItem: PhotosPickerItem?
    /// Image de fond de carte (strip Wallet) — chemin local après import.
    @State private var cardBackgroundImagePath: String?
    @State private var cardBackgroundPhotoItem: PhotosPickerItem?
    /// True si l'utilisateur a supprimé l'image de fond (pour envoyer "" au backend à l'enregistrement).
    @State private var cardBackgroundWasRemoved = false
    /// Aperçu simulé : nombre de tampons affichés (mode tampons).
    @State private var previewStampsCount: Int = 0
    /// Aperçu simulé : nombre de points affichés (mode points).
    @State private var previewPointsCount: Int = 50
    /// Données du pass pour afficher la feuille « Ajouter à l’Apple Wallet ».
    /// Feuille ouverte pour une zone de la carte (tap sur l’aperçu).
    @State private var customizationZone: CardPreviewEditZone?
    @State private var walletPassData: Data?
    @State private var walletLoading = false
    @State private var walletErrorMessage: String?
    @State private var saveLogoError: String?
    /// Fond carte hébergé sur l’API (GET …/card-background, Bearer) quand défini dans le SaaS.
    @State private var cardBackgroundRemoteURL: String?
    /// Couleurs dominantes extraites du logo, pour les proposer comme fond (comme sur le SaaS).
    @State private var logoDominantColors: [String] = []
    // Règles de la carte (points vs tampons, récompenses)
    @State private var programType: String = "stamps"
    @State private var pointsPerEuro: Int = 1
    @State private var pointsPerVisit: Int = 0
    @State private var pointsMinAmountEur: String = ""
    /// Paliers points (jusqu’à 5), alignés sur le SaaS web.
    @State private var tierPoints: [String] = Array(repeating: "", count: 5)
    @State private var tierLabels: [String] = Array(repeating: "", count: 5)
    @State private var stampRewardLabel: String = ""
    @State private var expiryMonths: String = ""
    @State private var sector: String = ""
    @State private var rulesLoadedFromAPI = false
    /// True après un GET settings réussi : permet d’envoyer les champs avancés sans écraser le serveur avant chargement.
    @State private var dashboardSettingsHydrated = false
    @State private var backTerms: String = ""
    @State private var backContact: String = ""
    @State private var stampMidRewardLabel: String = ""
    @State private var labelRestants: String = ""
    /// Non éditables dans l’UI (fixes sur le SaaS) : conservés pour ne pas écraser l’API au PATCH.
    @State private var labelMember: String = ""
    @State private var headerRightText: String = ""
    @State private var stampSkipMidReward = false
    @State private var notificationTitleOverride: String = ""
    @State private var notificationChangeMessage: String = ""
    @State private var stampIconPhotoItem: PhotosPickerItem?
    @State private var stampIconWasRemoved = false
    @State private var stampIconPendingBase64: String?

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    /// Marge basse pour que le contenu reste visible au-dessus de la barre d’onglets.
    private let bottomScrollPadding: CGFloat = 100

    /// Design dédié « Café des Arts » (grille tampons visible) quand le nom correspond.
    private var isCafeDesArts: Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        return name.localizedCaseInsensitiveContains("Café des Arts") || name == "Cafe des Arts"
    }

    /// Texte récompense / palier pour l’aperçu (aligné sur le SaaS : premier palier ou libellé tampon).
    private var cardRewardPreviewText: String {
        if programType == "stamps" {
            let s = stampRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            return s.isEmpty ? "Paliers en magasin" : s
        }
        for i in 0..<5 {
            let lab = tierLabels[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let pts = tierPoints[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if !lab.isEmpty, Int(pts) != nil { return lab }
        }
        return "Paliers en magasin"
    }

    private var cardMemberPreviewText: String {
        let n = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Prévisualisation" : n
    }

    /// `label_member` API (SaaS) — texte au-dessus du nom client à droite.
    private var previewMemberColumnTitle: String {
        let m = labelMember.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "MEMBRE" : m
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    previewSection
                    actionsSection
                }
                .padding(.bottom, bottomScrollPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.Colors.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                loadCurrentTemplate()
                if let slug = AuthStorage.currentBusinessSlug,
                   let snap = CardPreviewDisplaySnapshotStore.load(slug: slug) {
                    applyDisplaySnapshot(snap)
                    Task { await prefetchCardMediaURLs(logoURLString: snap.logoURL, backgroundURLString: snap.cardBackgroundRemoteURL) }
                }
                Task { await loadCardSettingsFromAPI() }
            }
            .onChange(of: syncService.lastSyncDate) { _, newDate in
                guard newDate != nil else { return }
                Task { await loadCardSettingsFromAPI() }
            }
            .task(id: logoURL) {
                await refreshLogoColors()
            }
            .onChange(of: requiredStamps) { _, new in
                if previewStampsCount > new { previewStampsCount = new }
            }
            .sheet(item: $customizationZone) { zone in
                CardElementCustomizationSheet(
                    zone: zone,
                    pack: cardCustomizationBindPack,
                    actions: cardCustomizationActions,
                    logoDominantColors: logoDominantColors,
                    dashboardSettingsHydrated: dashboardSettingsHydrated,
                    onClose: { customizationZone = nil },
                    onSave: {
                        let ok = await saveTemplate()
                        if ok { await MainActor.run { triggerSavedFeedback() } }
                        return ok
                    }
                )
                .task(id: zone.id) {
                    if zone == .walletPassBack {
                        await loadCardSettingsFromAPI()
                    }
                }
            }
            .overlay {
                if walletPassData != nil {
                    AddToWalletPresenter(passData: walletPassData) {
                        walletPassData = nil
                    }
                    .frame(width: 1, height: 1)
                }
            }
            .alert("Apple Wallet", isPresented: .constant(walletErrorMessage != nil)) {
                Button("Réessayez") {
                    walletErrorMessage = nil
                    addToWalletTapped()
                }
                Button("OK", role: .cancel) { walletErrorMessage = nil }
            } message: {
                if let msg = walletErrorMessage {
                    Text("\(msg)\n\nSi l’erreur revient, le problème vient du serveur (certificats ou configuration). Consultez les logs Railway.")
                }
            }
            .alert("Enregistrement", isPresented: .constant(saveLogoError != nil)) {
                Button("OK") { saveLogoError = nil }
            } message: {
                if let msg = saveLogoError { Text(msg) }
            }
        }
    }

    // MARK: - Aperçu carte (Wallet uniquement)

    private let previewMinHeight: CGFloat = 438

    /// Même URL que le lien « Lien et QR code » / page carte publique.
    private var fidelityCardPageURLString: String? {
        guard let slug = AuthStorage.currentBusinessSlug,
              let url = LegalURLs.fidelityCardPage(slug: slug) else { return nil }
        return url.absoluteString
    }

    private var previewSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.shadow)
                    .blur(radius: 18)
                    .offset(y: 6)
                    .opacity(0.4)

                Group {
                    if programType == "stamps" {
                        CafeDesArtsCardPreview(
                            displayName: displayName.isEmpty ? "Ma Carte Fidélité" : displayName,
                            requiredStamps: Int32(requiredStamps),
                            stampsCount: Int32(previewStampsCount),
                            primaryColorHex: primaryHex,
                            accentColorHex: accentHex,
                            stripColorHex: nil,
                            logoURL: logoURL.isEmpty ? nil : logoURL,
                            stripDisplayMode: stripDisplayMode,
                            stripText: stripText.isEmpty ? nil : stripText,
                            stampEmoji: stampEmoji.isEmpty ? nil : stampEmoji,
                            cardBackgroundImagePath: cardBackgroundImagePath.flatMap { $0.isEmpty ? nil : CardLogoStorage.fullPath(forRelative: $0) },
                            cardBackgroundRemoteURL: cardBackgroundRemoteURL,
                            labelColorHex: labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelHex,
                            headerRightText: headerRightText.isEmpty ? nil : headerRightText,
                            rewardPreviewText: cardRewardPreviewText,
                            memberPreviewText: cardMemberPreviewText,
                            memberColumnTitle: previewMemberColumnTitle,
                            restantsCaption: labelRestants.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restants" : labelRestants.trimmingCharacters(in: .whitespacesAndNewlines),
                            compact: false,
                            fidelityQRPayloadURL: fidelityCardPageURLString,
                            onEditZoneTap: { handleCardPreviewZoneTap($0) }
                        )
                    } else {
                        WalletCardPreview(
                            displayName: displayName.isEmpty ? "Ma Carte Fidélité" : displayName,
                            requiredStamps: Int32(requiredStamps),
                            stampsCount: Int32(previewPointsCount),
                            primaryColorHex: primaryHex,
                            accentColorHex: accentHex,
                            stripColorHex: nil,
                            logoURL: logoURL.isEmpty ? nil : logoURL,
                            stripDisplayMode: stripDisplayMode,
                            stripText: stripText.isEmpty ? nil : stripText,
                            stampEmoji: stampEmoji.isEmpty ? nil : stampEmoji,
                            cardBackgroundImagePath: cardBackgroundImagePath.flatMap { $0.isEmpty ? nil : CardLogoStorage.fullPath(forRelative: $0) },
                            cardBackgroundRemoteURL: cardBackgroundRemoteURL,
                            labelColorHex: labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelHex,
                            headerRightText: headerRightText.isEmpty ? nil : headerRightText,
                            rewardPreviewText: cardRewardPreviewText,
                            memberPreviewText: cardMemberPreviewText,
                            memberColumnTitle: previewMemberColumnTitle,
                            compact: false,
                            fidelityQRPayloadURL: fidelityCardPageURLString,
                            onEditZoneTap: { handleCardPreviewZoneTap($0) }
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .frame(minHeight: previewMinHeight)
            }
            .id(
                "\(programType)-\(primaryHex)-\(accentHex)-\(labelHex)-\(logoURL)-\(stripDisplayMode)-\(stripText)-\(headerRightText)-\(displayName)-\(requiredStamps)-\(previewStampsCount)-\(previewPointsCount)-\(cardBackgroundImagePath ?? "")-\(cardBackgroundRemoteURL ?? "")-\(cardRewardPreviewText)-\(cardMemberPreviewText)-\(previewMemberColumnTitle)"
            )
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .padding(.top, AppTheme.Spacing.xl + AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private func handleCardPreviewZoneTap(_ zone: CardPreviewEditZone) {
        customizationZone = zone
    }

    /// Bindings passés à la feuille de personnalisation (une seule construction à la présentation).
    private var cardCustomizationBindPack: CardCustomizationBindPack {
        CardCustomizationBindPack(
            primaryHex: $primaryHex,
            accentHex: $accentHex,
            labelHex: $labelHex,
            stripDisplayMode: $stripDisplayMode,
            stripText: $stripText,
            logoURL: $logoURL,
            logoPhotoItem: $logoPhotoItem,
            headerRightText: $headerRightText,
            labelMember: $labelMember,
            labelRestants: $labelRestants,
            displayName: $displayName,
            cardBackgroundPhotoItem: $cardBackgroundPhotoItem,
            cardBackgroundImagePath: $cardBackgroundImagePath,
            cardBackgroundRemoteURL: $cardBackgroundRemoteURL,
            programType: $programType,
            tierPoints: $tierPoints,
            tierLabels: $tierLabels,
            requiredStamps: $requiredStamps,
            previewStampsCount: $previewStampsCount,
            previewPointsCount: $previewPointsCount,
            stampEmoji: $stampEmoji,
            stampRewardLabel: $stampRewardLabel,
            stampMidRewardLabel: $stampMidRewardLabel,
            stampSkipMidReward: $stampSkipMidReward,
            stampIconPhotoItem: $stampIconPhotoItem,
            backTerms: $backTerms,
            backContact: $backContact,
            notificationTitleOverride: $notificationTitleOverride,
            notificationChangeMessage: $notificationChangeMessage
        )
    }

    private var cardCustomizationActions: CardCustomizationActions {
        CardCustomizationActions(
            loadLogoFromPicker: { item in await loadLogoFromPicker(item) },
            loadLogoFromPhotoAsset: { asset in await loadLogoFromPhotoAsset(asset) },
            loadCardBackgroundFromPicker: { item in await loadCardBackgroundFromPicker(item) },
            loadCardBackgroundFromPhotoAsset: { asset in await loadCardBackgroundFromPhotoAsset(asset) },
            loadStampIconFromPicker: { item in await loadStampIconFromPicker(item) },
            removeCardBackground: {
                cardBackgroundImagePath = nil
                cardBackgroundPhotoItem = nil
                cardBackgroundRemoteURL = nil
                cardBackgroundWasRemoved = true
            },
            removeLogo: {
                logoURL = ""
                logoPhotoItem = nil
            },
            resetStampIcon: {
                stampIconWasRemoved = true
                stampIconPendingBase64 = nil
                stampIconPhotoItem = nil
            }
        )
    }

    // MARK: - Actions sous l’aperçu

    private var actionsSection: some View {
        VStack(spacing: 14) {
            Text("Touchez un élément sur la carte pour ouvrir ses réglages (texte, couleurs, image ou règles).")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppTheme.Spacing.sm)

            Menu {
                Button {
                    customizationZone = .cardAppearance
                } label: {
                    Label("Couleurs de la carte", systemImage: "paintpalette")
                }
                Button {
                    customizationZone = .walletPassBack
                } label: {
                    Label("Verso du pass & notifications", systemImage: "doc.text")
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                    Text("Autres réglages")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)

            addToWalletButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.lg)
    }

    private var addToWalletButton: some View {
        Button {
            addToWalletTapped()
        } label: {
            HStack(spacing: 10) {
                if walletLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image("AppleWalletAppIcon")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6.5, style: .continuous))
                }
                Text(walletLoading ? "Chargement…" : "Tester dans l’Apple Wallet")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black)
        .disabled(walletLoading || !PKAddPassesViewController.canAddPasses())
    }

    private func addToWalletTapped() {
        walletErrorMessage = nil
        Task {
            await MainActor.run { walletLoading = true }
            defer {
                Task { @MainActor in
                    walletLoading = false
                }
            }
            // Enregistrer d’abord le design actuel pour que le pass reflète l’aperçu.
            await loadCardSettingsFromAPI()
            let saved = await saveTemplate()
            guard saved else { return }

            var slug = AuthStorage.currentBusinessSlug
            if slug == nil, AuthStorage.isLoggedIn {
                await syncService.syncIfNeeded()
                slug = AuthStorage.currentBusinessSlug
            }
            guard let slug else {
                await MainActor.run {
                    walletErrorMessage = "Votre commerce n’a pas encore été chargé. Vérifiez votre connexion, tirez pour actualiser le tableau de bord puis réessayez."
                }
                return
            }
            guard let template = dataService.currentCardTemplate() else {
                await MainActor.run {
                    walletErrorMessage = "Données du commerce manquantes. Actualisez le tableau de bord puis réessayez."
                }
                return
            }
            let members = dataService.uniqueClientCards(for: template)
            guard let memberId = members.first?.qrCodeValue, !memberId.isEmpty else {
                await MainActor.run {
                    walletErrorMessage = "Aucun membre. Synchronisez le tableau de bord (tirez pour actualiser) ou ajoutez un client pour tester le pass."
                }
                return
            }
            let bgHex = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
            let design = WalletPassDesign(
                organizationName: displayName.trimmingCharacters(in: .whitespaces).isEmpty ? "Ma Carte Fidélité" : displayName.trimmingCharacters(in: .whitespaces),
                backgroundColor: bgHex,
                foregroundColor: accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex,
                stampEmoji: stampEmoji,
                requiredStamps: programType == "stamps" ? 10 : requiredStamps,
                programType: programType,
                stripColor: bgHex,
                stripDisplayMode: stripDisplayMode,
                stripText: stripText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : stripText.trimmingCharacters(in: .whitespaces),
                template: isCafeDesArts ? "cafe" : nil
            )
            do {
                let data = try await APIClient.shared.requestData(.walletPass(slug: slug, memberId: memberId, design: design))
                await MainActor.run {
                    walletErrorMessage = nil
                    walletPassData = data
                }
            } catch APIError.notFound {
                await MainActor.run {
                    walletErrorMessage = "Pass non trouvé pour ce membre. Réessayez ou ajoutez un client."
                }
            } catch {
                await MainActor.run {
                    walletErrorMessage = (error as? APIError)?.errorDescription ?? "Impossible de charger le pass. Réessayez plus tard."
                }
            }
        }
    }

    private func loadLogoFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await applyLogoImage(image)
    }

    private func loadLogoFromPhotoAsset(_ asset: PHAsset) async {
        guard let image = await asset.myfid_exportUIImage() else { return }
        await applyLogoImage(image)
    }

    private func applyLogoImage(_ image: UIImage) async {
        let path = CardLogoStorage.saveImage(image)
        let colors = LogoColorExtractor.dominantColors(from: image, maxColors: 4).map { h in h.hasPrefix("#") ? h : "#" + h }
        await MainActor.run {
            logoURL = path ?? ""
            logoDominantColors = colors
            if path != nil { logoPhotoItem = nil }
        }
    }

    /// Charge une UIImage depuis une URL (http) ou un chemin relatif (fichier local). Utilise le token pour l’API.
    private func loadLogoImage(from urlOrPath: String) async -> UIImage? {
        let trimmed = urlOrPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.lowercased().hasPrefix("http"), let url = URL(string: trimmed) {
            if url.host() == APIConfig.baseURL.host(), url.path.contains("/logo") {
                return try? await AuthenticatedMediaLoader.loadAuthenticatedImage(from: url)
            }
            let request = URLRequest(url: url)
            guard let (data, resp) = try? await URLSession.shared.data(for: request),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let image = UIImage(data: data) else { return nil }
            return image
        }
        let fullPath: String
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("file:") {
            fullPath = trimmed.hasPrefix("file:") ? (URL(string: trimmed)?.path ?? trimmed) : trimmed
        } else {
            guard let fp = CardLogoStorage.fullPath(forRelative: trimmed) else { return nil }
            fullPath = fp
        }
        return UIImage(contentsOfFile: fullPath)
    }

    private func refreshLogoColors() async {
        guard !logoURL.trimmingCharacters(in: .whitespaces).isEmpty else {
            await MainActor.run { logoDominantColors = [] }
            return
        }
        guard let image = await loadLogoImage(from: logoURL) else {
            await MainActor.run { logoDominantColors = [] }
            return
        }
        let colors = LogoColorExtractor.dominantColors(from: image, maxColors: 4).map { h in h.hasPrefix("#") ? h : "#" + h }
        await MainActor.run { logoDominantColors = colors }
    }

    private func loadCardBackgroundFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await applyCardBackgroundImage(image)
    }

    private func loadCardBackgroundFromPhotoAsset(_ asset: PHAsset) async {
        guard let image = await asset.myfid_exportUIImage() else { return }
        await applyCardBackgroundImage(image)
    }

    private func applyCardBackgroundImage(_ image: UIImage) async {
        let path = CardLogoStorage.saveCardBackground(image)
        await MainActor.run {
            cardBackgroundImagePath = path
            if path != nil {
                cardBackgroundPhotoItem = nil
                cardBackgroundWasRemoved = false
                cardBackgroundRemoteURL = nil
            }
        }
    }

    private func loadStampIconFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else { return }
        let b64 = jpeg.base64EncodedString()
        let maxLen = 512 * 1024
        guard jpeg.count <= maxLen else { return }
        let payload = "data:image/jpeg;base64,\(b64)"
        await MainActor.run {
            stampIconPendingBase64 = payload
            stampIconWasRemoved = false
            stampIconPhotoItem = nil
        }
    }

    private func loadCurrentTemplate() {
        let t = dataService.createOrGetCurrentCardTemplate()
        displayName = t.displayName ?? "Ma Carte Fidélité"
        requiredStamps = Int(t.requiredStamps)
        primaryHex = t.primaryColorHex ?? "2563EB"
        accentHex = t.accentColorHex ?? "F59E0B"
        logoURL = t.logoURL ?? ""
        stampEmoji = t.stampEmoji ?? ""
        previewStampsCount = min(3, max(0, requiredStamps))
    }

    /// Restaure le dernier rendu connu du serveur (évite tampons vs points ou couleurs obsolètes le temps du GET).
    private func applyDisplaySnapshot(_ s: CardPreviewDisplaySnapshot) {
        programType = s.programType
        if programType != "points" && programType != "stamps" { programType = "stamps" }
        displayName = s.displayName.isEmpty ? displayName : s.displayName
        primaryHex = s.primaryHex.isEmpty ? primaryHex : s.primaryHex
        accentHex = s.accentHex.isEmpty ? accentHex : s.accentHex
        labelHex = s.labelHex
        stripDisplayMode = s.stripDisplayMode
        if stripDisplayMode != "text" { stripDisplayMode = "logo" }
        stripText = s.stripText
        logoURL = s.logoURL
        stampEmoji = s.stampEmoji
        requiredStamps = max(1, s.requiredStamps)
        headerRightText = s.headerRightText
        labelMember = s.labelMember
        stampRewardLabel = s.stampRewardLabel
        let localBG = !(cardBackgroundImagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !localBG {
            if s.hasRemoteCardBackground, let u = s.cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                cardBackgroundRemoteURL = u
            } else {
                cardBackgroundRemoteURL = nil
            }
        }
        previewStampsCount = min(previewStampsCount, requiredStamps)
        if previewStampsCount < 0 { previewStampsCount = 0 }
    }

    private func buildDisplaySnapshot(slug: String) -> CardPreviewDisplaySnapshot {
        let hasBG = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return CardPreviewDisplaySnapshot(
            programType: programType,
            displayName: displayName,
            primaryHex: primaryHex,
            accentHex: accentHex,
            labelHex: labelHex,
            stripHex: "",
            stripDisplayMode: stripDisplayMode,
            stripText: stripText,
            logoURL: logoURL,
            stampEmoji: stampEmoji,
            requiredStamps: requiredStamps,
            headerRightText: headerRightText,
            labelMember: labelMember,
            hasRemoteCardBackground: hasBG,
            cardBackgroundRemoteURL: hasBG ? cardBackgroundRemoteURL : nil,
            stampRewardLabel: stampRewardLabel
        )
    }

    private func persistDisplaySnapshot(slug: String) {
        CardPreviewDisplaySnapshotStore.save(buildDisplaySnapshot(slug: slug), slug: slug)
    }

    private func prefetchCardMediaURLs(logoURLString: String, backgroundURLString: String?) async {
        let logo = logoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !logo.isEmpty, let u = URL(string: logo), u.host() == APIConfig.baseURL.host() {
            await AuthenticatedMediaLoader.prefetch(url: u)
        }
        if let bg = backgroundURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !bg.isEmpty,
           let u = URL(string: bg), u.host() == APIConfig.baseURL.host() {
            await AuthenticatedMediaLoader.prefetch(url: u)
        }
    }

    private func prefetchCardMediaFromCurrentState() async {
        await prefetchCardMediaURLs(logoURLString: logoURL, backgroundURLString: cardBackgroundRemoteURL)
    }

    /// Charge les réglages complets depuis l’API (design + règles) pour que l’aperçu et le pass « Tester dans l’Apple Wallet » reflètent les changements faits sur le SaaS ou ailleurs.
    private func loadCardSettingsFromAPI() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            await MainActor.run {
                if let name = settings.organizationName, !name.isEmpty {
                    displayName = name
                }
                if let bg = settings.backgroundColor, !bg.isEmpty {
                    primaryHex = bg.hasPrefix("#") ? bg : "#" + bg
                }
                if let fg = settings.foregroundColor, !fg.isEmpty {
                    accentHex = fg.hasPrefix("#") ? fg : "#" + fg
                }
                if let label = settings.labelColor, !label.isEmpty {
                    labelHex = label.hasPrefix("#") ? label : "#" + label
                } else {
                    labelHex = ""
                }
                stripDisplayMode = (settings.stripDisplayMode ?? "logo").lowercased()
                if stripDisplayMode != "text" { stripDisplayMode = "logo" }
                stripText = settings.stripText ?? ""
                programType = (settings.programType ?? "stamps").lowercased()
                if programType != "points" && programType != "stamps" { programType = "stamps" }
                if programType == "stamps" {
                    requiredStamps = 10
                } else if let rs = settings.requiredStamps, rs > 0 {
                    requiredStamps = rs
                }
                pointsPerEuro = settings.pointsPerEuro ?? 1
                pointsPerVisit = settings.pointsPerVisit ?? 0
                pointsMinAmountEur = settings.pointsMinAmountEur.map { String(format: "%.2f", $0) } ?? ""
                if let tiers = settings.pointsRewardTiers, !tiers.isEmpty {
                    let sorted = tiers.sorted { $0.points < $1.points }
                    for i in 0..<5 {
                        if i < sorted.count {
                            tierPoints[i] = String(sorted[i].points)
                            tierLabels[i] = sorted[i].label
                        } else {
                            tierPoints[i] = ""
                            tierLabels[i] = ""
                        }
                    }
                } else {
                    tierPoints = Array(repeating: "", count: 5)
                    tierLabels = Array(repeating: "", count: 5)
                }
                stampRewardLabel = settings.stampRewardLabel ?? ""
                let midSaved = settings.stampMidRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if midSaved.isEmpty {
                    stampSkipMidReward = true
                    stampMidRewardLabel = ""
                } else {
                    stampSkipMidReward = false
                    stampMidRewardLabel = midSaved
                }
                expiryMonths = settings.expiryMonths.map { String($0) } ?? ""
                sector = settings.sector ?? ""
                backTerms = settings.backTerms ?? ""
                backContact = settings.backContact ?? ""
                labelRestants = settings.labelRestants ?? ""
                labelMember = settings.labelMember ?? ""
                headerRightText = settings.headerRightText ?? ""
                notificationTitleOverride = settings.notificationTitleOverride ?? ""
                notificationChangeMessage = settings.notificationChangeMessage ?? ""
                stampIconWasRemoved = false
                stampIconPendingBase64 = nil
                let apiLogo = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                logoURL = apiLogo
                if settings.hasCardBackground == true {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
                    cardBackgroundRemoteURL = "\(base)/api/businesses/\(enc)/card-background"
                    cardBackgroundWasRemoved = false
                } else {
                    cardBackgroundRemoteURL = nil
                }
                dashboardSettingsHydrated = true
                rulesLoadedFromAPI = true
                if let t = dataService.currentCardTemplate() {
                    t.displayName = displayName
                    t.primaryColorHex = primaryHex
                    t.accentColorHex = accentHex
                    t.logoURL = apiLogo.isEmpty ? nil : apiLogo
                    try? viewContext.save()
                }
                persistDisplaySnapshot(slug: slug)
                Task { await prefetchCardMediaFromCurrentState() }
            }
        } catch {
            await MainActor.run {
                rulesLoadedFromAPI = true
                dashboardSettingsHydrated = false
            }
        }
    }

    /// Retourne `false` si l’envoi des réglages au serveur a échoué (réseau, validation, etc.).
    @discardableResult
    private func saveTemplate() async -> Bool {
        let nameToSave = displayName.trimmingCharacters(in: .whitespaces)
        let nameFinal = nameToSave.isEmpty ? "Ma Carte Fidélité" : nameToSave
        let bgHex = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
        let fgHex = accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex

        dataService.updateCardTemplate(
            displayName: nameFinal,
            requiredStamps: Int32(programType == "stamps" ? 10 : requiredStamps),
            primaryColorHex: primaryHex,
            accentColorHex: accentHex,
            logoURL: logoURL.isEmpty ? nil : logoURL,
            stampEmoji: stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(8))
        )
        UserDefaults.standard.set(Date(), forKey: "myfidpass.templateLastSavedAt")

        guard let slug = AuthStorage.currentBusinessSlug else {
            return true
        }
        var logoBase64: String? = nil
        var logoUrl: String? = nil
        var cardBackgroundBase64: String? = nil
        if cardBackgroundWasRemoved {
            cardBackgroundBase64 = ""
        } else if let bgPath = cardBackgroundImagePath, !bgPath.isEmpty {
            cardBackgroundBase64 = CardLogoStorage.compressedBase64FromFile(path: bgPath)
        }
        if !logoURL.isEmpty {
            let trimmed = logoURL.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                let url = URL(string: trimmed)
                if let url, url.host() != APIConfig.baseURL.host() || !url.path.contains("/logo") {
                    logoUrl = trimmed
                }
            } else if trimmed.contains("CardLogos") || trimmed.hasPrefix("/") {
                logoBase64 = CardLogoStorage.compressedBase64FromFile(path: trimmed)
            }
        } else {
            logoBase64 = ""
        }
        var rewardTiers: [PointsRewardTierPayload]? = nil
        if programType == "points" {
            var tiers: [PointsRewardTierPayload] = []
            for i in 0..<5 {
                let ptsStr = tierPoints[i].trimmingCharacters(in: .whitespaces)
                let lab = tierLabels[i].trimmingCharacters(in: .whitespaces)
                guard let pts = Int(ptsStr), pts >= 0, !lab.isEmpty else { continue }
                tiers.append(PointsRewardTierPayload(points: pts, label: String(lab.prefix(120))))
            }
            tiers.sort { $0.points < $1.points }
            if !tiers.isEmpty { rewardTiers = tiers }
        }
        let ptsMinEur: Double? = Double(pointsMinAmountEur.trimmingCharacters(in: .whitespaces)).flatMap { $0 >= 0 ? $0 : nil }
        let sectorVal = sector.trimmingCharacters(in: .whitespaces)
        do {
                let labelHexNorm = labelHex.trimmingCharacters(in: .whitespaces)
                let labelForAPI = labelHexNorm.isEmpty ? nil : (labelHexNorm.hasPrefix("#") ? String(labelHexNorm.dropFirst()) : labelHexNorm)
                var patch = FullDashboardSettingsPatch()
                patch.organizationName = nameFinal
                patch.backgroundColor = bgHex
                patch.foregroundColor = fgHex
                patch.labelColor = labelForAPI
                patch.requiredStamps = programType == "stamps" ? 10 : max(0, requiredStamps)
                patch.logoBase64 = logoBase64
                patch.logoUrl = logoUrl
                patch.stampEmoji = stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(8))
                patch.cardBackgroundBase64 = cardBackgroundBase64
                patch.programType = programType
                patch.pointsPerEuro = programType == "points" ? pointsPerEuro : nil
                patch.pointsPerVisit = programType == "points" ? pointsPerVisit : nil
                patch.pointsMinAmountEur = programType == "points" ? ptsMinEur : nil
                patch.pointsRewardTiers = programType == "points" ? rewardTiers : nil
                patch.stampRewardLabel = stampRewardLabel.isEmpty ? nil : String(stampRewardLabel.prefix(120))
                patch.sector = sectorVal.isEmpty ? nil : String(sectorVal.prefix(64))
                patch.stripColor = bgHex
                patch.stripDisplayMode = stripDisplayMode
                patch.stripText = stripText.trimmingCharacters(in: .whitespaces)
                if programType == "points" {
                    patch.loyaltyMode = "points_cash"
                }
                if dashboardSettingsHydrated {
                    patch.backTerms = backTerms
                    patch.backContact = backContact
                    if programType == "stamps" {
                        if stampSkipMidReward {
                            patch.stampMidRewardLabelIsExplicitNull = true
                        } else {
                            let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespaces)
                            if mid.isEmpty {
                                patch.stampMidRewardLabelIsExplicitNull = true
                            } else {
                                patch.stampMidRewardLabel = String(mid.prefix(120))
                            }
                        }
                    }
                    patch.labelRestants = labelRestants.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(labelRestants.prefix(64))
                    patch.labelMember = labelMember.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(labelMember.prefix(64))
                    patch.headerRightText = headerRightText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(headerRightText.prefix(64))
                    patch.notificationTitleOverride = notificationTitleOverride.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(notificationTitleOverride.prefix(80))
                    patch.notificationChangeMessage = notificationChangeMessage.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(notificationChangeMessage.prefix(200))
                    if stampIconWasRemoved {
                        patch.stampIconBase64 = ""
                    } else if let pending = stampIconPendingBase64 {
                        patch.stampIconBase64 = pending
                    }
                }
                _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
                await MainActor.run {
                    saveLogoError = nil
                    if cardBackgroundBase64 == "" { cardBackgroundWasRemoved = false }
                    if stampIconWasRemoved || stampIconPendingBase64 != nil {
                        stampIconWasRemoved = false
                        stampIconPendingBase64 = nil
                    }
                }
                await loadCardSettingsFromAPI()
                if let sentBase64 = logoBase64, !sentBase64.isEmpty {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let apiLogoURL = "\(base)/api/businesses/\(slug)/logo"
                    if let t = dataService.currentCardTemplate() {
                        t.logoURL = apiLogoURL
                        t.updatedAt = Date()
                    }
                    let b = dataService.createOrGetCurrentBusiness()
                    b.logoURL = apiLogoURL
                    try? viewContext.save()
                    logoURL = apiLogoURL
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoUploadAtKey)
                }
            return true
        } catch {
            await MainActor.run {
                saveLogoError = "Impossible d'enregistrer la carte sur le serveur. Vérifiez la connexion puis réessayez."
            }
            return false
        }
    }

    private func triggerSavedFeedback() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

// MARK: - Ligne de choix de couleur (palette + sélection) — partagé avec MyCardEditView

struct ColorPickerRow: View {
    let title: String
    /// Sous-titre optionnel (éviter les noms techniques type `background_color` en prod).
    var subtitle: String? = nil
    @Binding var hex: String

    private static func hexDigits(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .uppercased()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let subtitle, !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(MyCardPresetColors.all, id: \.hex) { preset in
                        let presetNorm = preset.hex.hasPrefix("#") ? preset.hex : "#" + preset.hex
                        let selected = Self.hexDigits(hex) == Self.hexDigits(preset.hex)
                        ColorPresetButton(hex: presetNorm, name: preset.name, isSelected: selected) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hex = presetNorm
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            ColorPicker(selection: Binding(
                get: {
                    let d = Self.hexDigits(hex)
                    let six = d.count == 6 ? d : "000000"
                    return Color(hex: six)
                },
                set: { newColor in
                    hex = newColor.toHexRGBString()
                }
            ), supportsOpacity: false) {
                Label("Nuancier (toutes les couleurs)", systemImage: "eyedropper.halffull")
                    .font(.subheadline)
            }

            TextField("#RRGGBB", text: $hex)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(10)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct ColorPresetButton: View {
    let hex: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                    Circle()
                        .strokeBorder(isSelected ? Color(hex: hex).opacity(0.6) : Color.clear, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                    }
                }
                Text(name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
    }
}

// MARK: - Emojis pour la carte (points / tampons)

enum StampEmojiPresets {
    static let all: [String] = ["☕", "🍔", "⭐", "🎁", "🍕", "🌸", "💄", "✂️", "🍰", "🛍️"]
}

// MARK: - Palette de couleurs

enum MyCardPresetColors {
    static let all: [(name: String, hex: String)] = [
        ("Bleu", "2563EB"),
        ("Vert", "10B981"),
        ("Violet", "8B5CF6"),
        ("Ambre", "F59E0B"),
        ("Rouge", "EF4444"),
        ("Indigo", "4F46E5"),
        ("Teal", "14B8A6"),
        ("Rose", "EC4899"),
    ]
}

#Preview {
    MyCardView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(container: PersistenceController.preview.container))
}
