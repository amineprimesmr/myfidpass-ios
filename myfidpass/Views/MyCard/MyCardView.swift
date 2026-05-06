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
                AuthenticatedLogoView(url: MerchantLogoAssetCache.stripeLogoDisplayURL(url), stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed), isAPICardBackgroundURL(url) {
                AuthenticatedLogoView(url: url, stripBackgroundFill: false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let url = resolvedHTTPURL(trimmed) {
                DecodedURLImage(url: url, contentMode: .fit, maxPixelDimension: 1200)
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
        APIResourceURL.localImageFilePathIfPresent(path)
            ?? CardLogoStorage.fullPath(forRelative: path)
    }
    private func isAPILogoURL(_ url: URL) -> Bool {
        guard url.scheme == "http" || url.scheme == "https" else { return false }
        guard url.host() == APIConfig.baseURL.host() else { return false }
        // Bandeau carte uniquement (`…/logo`), pas `logo-icon` ni chemins ambigus.
        return url.path.hasSuffix("/logo")
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
        Task {
            let fp = fullPath
            let img = await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromFile(at: fp, maxPixelDimension: 1400)
            }.value
            await MainActor.run { image = img }
        }
    }
}

/// Nombre de paliers points **éditables** dans « Récompenses » (ex. 30 € / 60 € / 100 €), hors « Début du jeu ».
enum MyCardPointsRewardTiers {
    static let slotCount = 5
}

/// État comparé pour savoir si « Enregistrer » doit apparaître (aligné sur ce que `saveTemplate` envoie).

private struct MyCardPersistedSnapshot: Equatable {
    var displayName: String
    var requiredStamps: Int
    var primaryHex: String
    var accentHex: String
    var labelHex: String
    var stripDisplayMode: String
    var stripText: String
    var logoURL: String
    /// Contenu du fichier logo local : le chemin ne change pas quand on remplace l’image (`cardLogo.png`).
    var localLogoFileModification: Date?
    var stampEmoji: String
    var cardBackgroundImagePath: String?
    /// Idem fond carte : même chemin `cardBackground.png` si l’utilisateur change seulement l’image.
    var localCardBackgroundFileModification: Date?
    var cardBackgroundRemoteURL: String?
    var cardBackgroundWasRemoved: Bool
    var programType: String
    var pointsPerEuro: Int
    var pointsPerVisit: Int
    var pointsMinAmountEur: String
    var tierPoints: [String]
    var tierLabels: [String]
    var stampRewardLabel: String
    var expiryMonths: String
    var sector: String
    var stampMidRewardLabel: String
    /// Récompense « Début du jeu » (1ʳᵉ tour de roue avant tout palier).
    var startGameRewardLabel: String
    var backTerms: String
    var backContact: String
    var labelRestants: String
    var labelMember: String
    var notificationTitleOverride: String
    var notificationChangeMessage: String
    var stampIconWasRemoved: Bool
    var stampIconPendingBase64: String?
}

struct MyCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @StateObject private var dataService: DataService
    @State private var displayName: String = ""
    @State private var requiredStamps: Int = 10
    @State private var primaryHex: String = AppTheme.WalletCardAppearanceDefaults.backgroundHex
    @State private var accentHex: String = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
    /// Couleur des libellés (RÉCOMPENSE, MEMBRE, etc.).
    @State private var labelHex: String = AppTheme.WalletCardAppearanceDefaults.labelTitlesHex
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
    /// Aperçu aligné sur le solde du 1er membre sync. (pas une valeur fictive fixe).
    @State private var previewPointsCount: Int = 0
    /// Données du pass pour afficher la feuille « Ajouter à l’Apple Wallet ».
    /// Feuille ouverte pour une zone de la carte (tap sur l’aperçu).
    @State private var customizationZone: CardPreviewEditZone?
    @State private var walletPassData: Data?
    @State private var walletLoading = false
    @State private var walletErrorMessage: String?
    @State private var saveLogoError: String?
    /// Fond carte hébergé sur l’API (GET …/card-background, Bearer) quand défini dans le SaaS.
    @State private var cardBackgroundRemoteURL: String?
    /// Couleurs extraites du logo **et** du fond de carte (pastilles supplémentaires sur les palettes).
    @State private var cardImageSuggestedColors: [String] = []
    // Règles de la carte (points vs tampons, récompenses)
    @State private var programType: String = "points"
    @State private var pointsPerEuro: Int = 1
    @State private var pointsPerVisit: Int = 0
    @State private var pointsMinAmountEur: String = ""
    /// Paliers points (5, hors ligne « 10 pts » / début de jeu), alignés sur le SaaS web.
    @State private var tierPoints: [String] = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
    @State private var tierLabels: [String] = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
    @State private var stampRewardLabel: String = ""
    /// Récompense « Début du jeu » (1ʳᵉ tour de roue à l’ouverture de la carte) — persiste localement via `CardPreviewDisplaySnapshot`.
    @State private var startGameRewardLabel: String = ""
    /// Bonus d'inscription : 1 = actif, 0 = désactivé.
    @State private var welcomeBonusEnabled: Bool = true
    /// Nombre de points (mode points) offerts à l'inscription. Toujours 1 en mode tampons.
    @State private var welcomeBonusAmount: Int = 10
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
    @State private var notificationTitleOverride: String = ""
    @State private var notificationChangeMessage: String = ""
    @State private var stampIconWasRemoved = false
    @State private var stampIconPendingBase64: String?
    @State private var stampIconPhotoItem: PhotosPickerItem?
    /// Dernier GET dashboard : le serveur a une icône tampon personnalisée (hors emoji seul).
    @State private var serverHasStampIconAsset = false
    /// Dernière URL d’icône tampon renvoyée par l’API (aperçu + grille quand le brouillon a été enregistré).
    @State private var serverStampIconURLString: String?
    /// Dernière version enregistrée (ou chargée depuis l’API) — pour afficher « Enregistrer » seulement si l’état a divergé.
    @State private var lastPersistedSnapshot: MyCardPersistedSnapshot?
    @State private var cardSettingsSaveInFlight = false
    @State private var touchPillBlink = false
    /// Alerte avant de quitter la page si des changements ne sont pas enregistrés.
    @State private var showUnsavedLeaveAlert = false
    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    /// True si des changements locaux ne sont pas encore envoyés au serveur / Core Data « sauvé ».
    private var hasUnsavedCardChanges: Bool {
        guard let baseline = lastPersistedSnapshot else { return false }
        return baseline != makePersistedSnapshot()
    }

    /// Zones de l’aperçu à mettre en évidence (pastilles) quand des éléments obligatoires manquent.
    private var cardCompletionPreviewZones: Set<CardPreviewEditZone> {
        Set(cardMissingRequirements.map(\.suggestedEditZone))
    }

    /// Les pastilles « Configurer » doivent être visibles dès l’ouverture si la carte n’est pas complète,
    /// même sans changement local (première visite de « Ma carte »).
    private var shouldShowCompletionPills: Bool {
        !cardMissingRequirements.isEmpty
    }

    /// Blocage enregistrement / Wallet tant que la checklist obligatoire n’est pas remplie.
    private var cardMissingRequirements: [CardMissingRequirement] {
        MyCardCompletionRequirements.missingRequirements(
            primaryHex: primaryHex,
            accentHex: accentHex,
            labelHex: labelHex,
            stripDisplayMode: stripDisplayMode,
            stripText: stripText,
            displayName: displayName,
            logoURL: logoURL,
            programType: programType,
            cardBackgroundImagePath: cardBackgroundImagePath,
            cardBackgroundRemoteURL: cardBackgroundRemoteURL,
            cardBackgroundWasRemoved: cardBackgroundWasRemoved,
            stampEmoji: stampEmoji,
            stampIconPendingBase64: stampIconPendingBase64,
            stampIconWasRemoved: stampIconWasRemoved,
            serverHasStampIcon: serverHasStampIconAsset,
            tierPoints: tierPoints,
            tierLabels: tierLabels,
            requiredStamps: requiredStamps,
            stampRewardLabel: stampRewardLabel,
            stampMidRewardLabel: stampMidRewardLabel
        )
    }

    private var canPersistCardDraft: Bool {
        !hasUnsavedCardChanges || cardMissingRequirements.isEmpty
    }

    /// Marge basse du scroll (la tab bar est masquée sur cette page).
    private let bottomScrollPadding: CGFloat = 28

    /// Design dédié « Café des Arts » (grille tampons visible) quand le nom correspond.
    private var isCafeDesArts: Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        return name.localizedCaseInsensitiveContains("Café des Arts") || name == "Cafe des Arts"
    }

    /// Nom affiché à droite : **membre** réel (sync), comme sur le pass — pas le nom du commerce.
    private var cardMemberPreviewText: String {
        if let t = dataService.currentCardTemplate(),
           let first = dataService.uniqueClientCards(for: t).first,
           let n = first.clientDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !n.isEmpty {
            return n
        }
        return "Prévisualisation"
    }

    /// `label_member` API (SaaS) — texte au-dessus du nom client à droite.
    private var previewMemberColumnTitle: String {
        let m = labelMember.trimmingCharacters(in: .whitespacesAndNewlines)
        return m.isEmpty ? "MEMBRE" : m
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: AppTheme.Spacing.lg) {
                programModePickerSection
                previewSection
                actionsSection
            }
            .padding(.bottom, bottomScrollPadding)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(AppTheme.Colors.background)
        .background(MyCardNavigationPopGate(blockInteractivePop: hasUnsavedCardChanges))
        .onAppear {
            loadCurrentTemplate()
            restoreLocalBackgroundFromSnapshot()
            mergeStampIconFromDisplaySnapshotIfNeeded()
            Task {
                await loadCardSettingsFromAPI()
                await MainActor.run {
                    syncPreviewBalancesFromSyncedMembers()
                    // Si le GET a échoué, dernier snapshot local (sans réécraser le logo : applyDisplaySnapshot ne touche plus à logoURL).
                    if !dashboardSettingsHydrated,
                       let slug = AuthStorage.currentBusinessSlug,
                       let snap = CardPreviewDisplaySnapshotStore.load(slug: slug) {
                        applyDisplaySnapshot(snap, restoreLogoFromSnapshot: true)
                        syncPreviewBalancesFromSyncedMembers()
                    }
                    capturePersistedBaseline()
                }
                await prefetchCardMediaFromCurrentState()
            }
        }
        .onChange(of: syncService.lastSyncDate) { _, newDate in
            guard newDate != nil else { return }
            Task {
                await loadCardSettingsFromAPI()
                await MainActor.run { syncPreviewBalancesFromSyncedMembers() }
            }
        }
        .task(id: "\(logoURL)|\(cardBackgroundImagePath ?? "")|\(cardBackgroundRemoteURL ?? "")|\(cardBackgroundWasRemoved)") {
            await refreshCardImageSuggestedColors()
        }
        .onChange(of: requiredStamps) { _, new in
            if previewStampsCount > new { previewStampsCount = new }
        }
        .sheet(item: $customizationZone) { zone in
            CardElementCustomizationSheet(
                zone: zone,
                pack: cardCustomizationBindPack,
                actions: cardCustomizationActions,
                cardImageSuggestedColors: cardImageSuggestedColors,
                dashboardSettingsHydrated: dashboardSettingsHydrated,
                onCropComplete: { cropped, spec in await applyMyCardCroppedImage(cropped, spec: spec) }
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
        .alert(cardMissingRequirements.isEmpty ? "Aperçu Wallet indisponible" : "Carte incomplète", isPresented: .constant(walletErrorMessage != nil)) {
            Button("OK", role: .cancel) { walletErrorMessage = nil }
        } message: {
            if let msg = walletErrorMessage {
                Text(msg)
            }
        }
        .alert("Enregistrement", isPresented: .constant(saveLogoError != nil)) {
            Button("OK") { saveLogoError = nil }
        } message: {
            if let msg = saveLogoError { Text(msg) }
        }
        .alert("Modifications non enregistrées", isPresented: $showUnsavedLeaveAlert) {
            Button("Enregistrer") {
                Task {
                    cardSettingsSaveInFlight = true
                    let ok = await saveTemplate()
                    await MainActor.run {
                        cardSettingsSaveInFlight = false
                        if ok {
                            triggerSavedFeedback()
                            dismiss()
                        }
                    }
                }
            }
            .disabled(cardSettingsSaveInFlight || !canPersistCardDraft)
            Button("Ne pas enregistrer", role: .destructive) {
                if let snap = lastPersistedSnapshot {
                    applyPersistedSnapshotForLeave(snap)
                    syncPreviewBalancesFromSyncedMembers()
                    Task { await refreshCardImageSuggestedColors() }
                }
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Voulez-vous enregistrer les modifications avant de quitter ?")
        }
        .navigationTitle("Ma carte")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    requestLeaveMyCard()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel("Retour")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if hasUnsavedCardChanges {
                    Button {
                        Task {
                            cardSettingsSaveInFlight = true
                            let ok = await saveTemplate()
                            await MainActor.run {
                                cardSettingsSaveInFlight = false
                                if ok { triggerSavedFeedback() }
                            }
                        }
                    } label: {
                        Group {
                            if cardSettingsSaveInFlight {
                                ProgressView()
                            } else {
                                Text("Enregistrer")
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(cardSettingsSaveInFlight || !canPersistCardDraft)
                }
            }
        }
    }

    /// Quitter la page : alerte si brouillon non sauvé (le swipe natif est désactivé dans ce cas).
    private func requestLeaveMyCard() {
        customizationZone = nil
        if hasUnsavedCardChanges {
            Task {
                cardSettingsSaveInFlight = true
                _ = await saveTemplate()
                await MainActor.run {
                    cardSettingsSaveInFlight = false
                    dismiss()
                }
            }
        } else {
            dismiss()
        }
    }

    /// Rétablit l’état affiché comme au dernier enregistrement / chargement API (sans nouvel appel réseau).
    private func applyPersistedSnapshotForLeave(_ snap: MyCardPersistedSnapshot) {
        displayName = snap.displayName
        requiredStamps = snap.requiredStamps
        primaryHex = snap.primaryHex
        accentHex = snap.accentHex
        labelHex = snap.labelHex
        stripDisplayMode = snap.stripDisplayMode
        stripText = snap.stripText
        logoURL = snap.logoURL
        stampEmoji = snap.stampEmoji
        cardBackgroundImagePath = snap.cardBackgroundImagePath
        cardBackgroundRemoteURL = snap.cardBackgroundRemoteURL
        cardBackgroundWasRemoved = snap.cardBackgroundWasRemoved
        programType = snap.programType
        pointsPerEuro = snap.pointsPerEuro
        pointsPerVisit = snap.pointsPerVisit
        pointsMinAmountEur = snap.pointsMinAmountEur
        tierPoints = Self.normalizeTierStrings(snap.tierPoints)
        tierLabels = Self.normalizeTierStrings(snap.tierLabels)
        stampRewardLabel = snap.stampRewardLabel
        expiryMonths = snap.expiryMonths
        sector = snap.sector
        stampMidRewardLabel = snap.stampMidRewardLabel
        startGameRewardLabel = snap.startGameRewardLabel
        backTerms = snap.backTerms
        backContact = snap.backContact
        labelRestants = snap.labelRestants
        labelMember = snap.labelMember
        notificationTitleOverride = snap.notificationTitleOverride
        notificationChangeMessage = snap.notificationChangeMessage
        stampIconWasRemoved = snap.stampIconWasRemoved
        stampIconPendingBase64 = snap.stampIconPendingBase64
        logoPhotoItem = nil
        cardBackgroundPhotoItem = nil
        stampIconPhotoItem = nil
        if let slug = AuthStorage.currentBusinessSlug {
            persistDisplaySnapshot(slug: slug)
        }
    }

    private static func normalizeTierStrings(_ arr: [String]) -> [String] {
        var out = Array(arr.prefix(MyCardPointsRewardTiers.slotCount))
        while out.count < MyCardPointsRewardTiers.slotCount { out.append("") }
        return out
    }

    // MARK: - Aperçu carte (Wallet uniquement)

    private let previewMinHeight: CGFloat = 438

    /// Choix Points / Tampons : au-dessus de la carte (plus simple que dans les feuilles de modification).
    private var programModePickerSection: some View {
        Picker("", selection: $programType) {
            Text("Points").tag("points")
            Text("Tampons").tag("stamps")
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("Type de programme : Points ou Tampons"))
        .onChange(of: programType) { _, new in
            welcomeBonusEnabled = true
            welcomeBonusAmount = new == "points" ? 10 : 1
            if new == "stamps" {
                requiredStamps = 10
                if previewStampsCount > 10 { previewStampsCount = 10 }
                CardLogoStorage.removeLocalCardBackgroundFile()
                cardBackgroundImagePath = nil
                cardBackgroundPhotoItem = nil
                cardBackgroundRemoteURL = nil
                cardBackgroundWasRemoved = true
                if let slug = AuthStorage.currentBusinessSlug {
                    persistDisplaySnapshot(slug: slug)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
    }

    /// Même URL que le lien « Lien et QR code » / page carte publique.
    private var fidelityCardPageURLString: String? {
        guard let slug = AuthStorage.currentBusinessSlug,
              let url = LegalURLs.fidelityCardPage(slug: slug) else { return nil }
        return url.absoluteString
    }

    private var previewSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            GeometryReader { geo in
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
                                stampIconDataURL: stampIconPendingBase64,
                                stampIconRemoteURL: stampIconRemoteURLForPreview(),
                                cardBackgroundImagePath: CardLogoStorage.resolvedDisplayPath(forStoredPath: cardBackgroundImagePath),
                                cardBackgroundRemoteURL: cardBackgroundRemoteURL,
                                labelColorHex: labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelHex,
                                headerRightText: CardRewardsHeaderLink.displayText,
                                memberPreviewText: cardMemberPreviewText,
                                memberColumnTitle: previewMemberColumnTitle,
                                stampMidRewardLabel: stampMidRewardLabel,
                                stampRewardLabel: stampRewardLabel,
                                restantsCaption: labelRestants.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restants" : labelRestants.trimmingCharacters(in: .whitespacesAndNewlines),
                                compact: false,
                                onEditZoneTap: { handleCardPreviewZoneTap($0) },
                                fidelityQRPayloadURL: fidelityCardPageURLString,
                                completionHighlightZones: shouldShowCompletionPills ? cardCompletionPreviewZones : []
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
                                cardBackgroundImagePath: CardLogoStorage.resolvedDisplayPath(forStoredPath: cardBackgroundImagePath),
                                cardBackgroundRemoteURL: cardBackgroundRemoteURL,
                                labelColorHex: labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelHex,
                                headerRightText: CardRewardsHeaderLink.displayText,
                                memberPreviewText: cardMemberPreviewText,
                                memberColumnTitle: previewMemberColumnTitle,
                                compact: false,
                                onEditZoneTap: { handleCardPreviewZoneTap($0) },
                                fidelityQRPayloadURL: fidelityCardPageURLString,
                                completionHighlightZones: shouldShowCompletionPills ? cardCompletionPreviewZones : []
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .frame(minHeight: previewMinHeight)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .id(
                    "\(programType)-\(primaryHex)-\(accentHex)-\(labelHex)-\(logoURL)-\(stripDisplayMode)-\(stripText)-\(displayName)-\(requiredStamps)-\(previewStampsCount)-\(previewPointsCount)-\(cardBackgroundImagePath ?? "")-\(cardBackgroundRemoteURL ?? "")-\(cardMemberPreviewText)-\(previewMemberColumnTitle)-\(stampEmoji)-\(stampRewardLabel)-\(stampMidRewardLabel)-\(labelRestants)-\(stampIconPendingBase64?.prefix(32) ?? "")-\(serverStampIconURLString ?? "")-\(stampIconWasRemoved)"
                )
                .overlay(alignment: .bottomLeading) {
                    if shouldShowCompletionPills {
                        HStack(spacing: 5) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text("Touchez")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.82))
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                        .padding(.leading, AppTheme.Spacing.lg + 10)
                        .padding(.bottom, 90)
                        .opacity(touchPillBlink ? 1 : 0.45)
                        .scaleEffect(touchPillBlink ? 1 : 0.96)
                        .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: touchPillBlink)
                        .onAppear { touchPillBlink = true }
                        .onDisappear { touchPillBlink = false }
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: previewMinHeight + 36)
            .padding(.vertical, AppTheme.Spacing.xs)
        }
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private func handleCardPreviewZoneTap(_ zone: CardPreviewEditZone) {
        if zone == .qrCode {
            guard let slug = AuthStorage.currentBusinessSlug,
                  let url = LegalURLs.fidelityCardPage(slug: slug) else { return }
            openURL(url)
            return
        }
        if zone == .backgroundImage && programType != "points" {
            return
        }
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
            stampIconPhotoItem: $stampIconPhotoItem,
            stampIconPendingBase64: $stampIconPendingBase64,
            stampIconWasRemoved: $stampIconWasRemoved,
            serverStampIconURL: serverStampIconURLString,
            serverHasStampIconAsset: serverHasStampIconAsset,
            stampRewardLabel: $stampRewardLabel,
            stampMidRewardLabel: $stampMidRewardLabel,
            startGameRewardLabel: $startGameRewardLabel,
            backTerms: $backTerms,
            backContact: $backContact,
            notificationTitleOverride: $notificationTitleOverride,
            notificationChangeMessage: $notificationChangeMessage,
            welcomeBonusEnabled: $welcomeBonusEnabled,
            welcomeBonusAmount: $welcomeBonusAmount
        )
    }

    private var cardCustomizationActions: CardCustomizationActions {
        CardCustomizationActions(
            loadLogoFromPhotoAsset: { asset in await loadLogoFromPhotoAsset(asset) },
            loadCardBackgroundFromPhotoAsset: { asset in await loadCardBackgroundFromPhotoAsset(asset) },
            removeCardBackground: {
                CardLogoStorage.removeLocalCardBackgroundFile()
                cardBackgroundImagePath = nil
                cardBackgroundPhotoItem = nil
                cardBackgroundRemoteURL = nil
                cardBackgroundWasRemoved = true
                if let slug = AuthStorage.currentBusinessSlug {
                    persistDisplaySnapshot(slug: slug)
                }
            },
            removeLogo: {
                logoURL = ""
                logoPhotoItem = nil
                persistLocalCardVisualsAfterImageChange()
            },
            resetStampIcon: { selectedCatalogKey in
                stampIconWasRemoved = true
                stampIconPendingBase64 = nil
                stampIconPhotoItem = nil
                if let slug = AuthStorage.currentBusinessSlug {
                    persistDisplaySnapshot(slug: slug)
                }
                persistLocalCardVisualsAfterImageChange(stampEmojiOverride: selectedCatalogKey)
            }
        )
    }

    // MARK: - Actions sous l’aperçu

    private var actionsSection: some View {
        addToWalletButton
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
            // Hydratation minimale : pas de GET si les réglages sont déjà chargés et rien à pousser.
            if !dashboardSettingsHydrated {
                await loadCardSettingsFromAPI()
            }
            if hasUnsavedCardChanges {
                if !cardMissingRequirements.isEmpty {
                    await MainActor.run {
                        let missing = cardMissingRequirements.map(\.title).joined(separator: " · ")
                        walletErrorMessage =
                            "Pour tester dans Apple Wallet, complétez d’abord ces éléments : \(missing). Ensuite, enregistrez la carte."
                    }
                    return
                }
                let saved = await saveTemplate(skipPostSaveReload: true)
                guard saved else { return }
            }

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
            let memberId: String
            if let localId = members.first?.qrCodeValue?.trimmingCharacters(in: .whitespacesAndNewlines), !localId.isEmpty {
                memberId = localId
            } else {
                do {
                    memberId = try await ensurePreviewMemberIdForWallet(slug: slug)
                    Task(priority: .utility) { await syncService.syncAfterServerMutation() }
                } catch {
                    await MainActor.run {
                        walletErrorMessage = (error as? APIError)?.errorDescription
                            ?? "Impossible de préparer un aperçu Wallet. Réessayez."
                    }
                    return
                }
            }
            let bgHex = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
            let labelHexForPass = labelHex.trimmingCharacters(in: .whitespacesAndNewlines)
            let previewBalance = programType == "points" ? previewPointsCount : previewStampsCount
            /// Sans image perso locale en attente : si pas d’asset serveur OU tampon perso retiré (catalogue), le pass doit suivre `stamp_emoji` — sinon le .pkpass gardait l’ancienne image uploadée.
            let catalogStampOnly = programType == "stamps"
                && stampIconPendingBase64 == nil
                && (!serverHasStampIconAsset || stampIconWasRemoved)
            let design = WalletPassDesign(
                organizationName: displayName.trimmingCharacters(in: .whitespaces).isEmpty ? "Ma Carte Fidélité" : displayName.trimmingCharacters(in: .whitespaces),
                backgroundColor: bgHex,
                foregroundColor: accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex,
                stampEmoji: stampEmoji,
                requiredStamps: max(1, requiredStamps),
                programType: programType,
                stripColor: bgHex,
                stripDisplayMode: stripDisplayMode,
                stripText: stripText.trimmingCharacters(in: .whitespaces).isEmpty ? nil : stripText.trimmingCharacters(in: .whitespaces),
                template: isCafeDesArts ? "cafe" : nil,
                labelColor: labelHexForPass.isEmpty ? nil : (labelHexForPass.hasPrefix("#") ? String(labelHexForPass.dropFirst()) : labelHexForPass),
                previewPoints: previewBalance,
                catalogStampOnly: catalogStampOnly
            )
            do {
                let data = try await APIClient.shared.requestData(.walletPass(slug: slug, memberId: memberId, design: design))
                await MainActor.run {
                    walletErrorMessage = nil
                    walletPassData = data
                }
            } catch APIError.notFound {
                await MainActor.run {
                    walletErrorMessage = "Pass non trouvé pour ce membre. Réessayez."
                }
            } catch {
                await MainActor.run {
                    walletErrorMessage = (error as? APIError)?.errorDescription ?? "Impossible de charger le pass. Réessayez plus tard."
                }
            }
        }
    }

    /// Crée côté API un membre « Aperçu Wallet » (e-mail fixe par commerce) si aucun client n’est en local — idempotent.
    private func ensurePreviewMemberIdForWallet(slug: String) async throws -> String {
        let safeSlug = Self.sanitizeSlugForPreviewEmail(slug)
        let email = "wallet-apercu.\(safeSlug)@example.com"
        let createResp = try await APIClient.shared.request(
            .createMember(slug: slug, email: email, name: "Aperçu Wallet"),
            responseType: CreateMemberResponse.self
        )
        let mid = createResp.memberId ?? createResp.member?.id
        guard let id = mid, !id.isEmpty else {
            throw APIError.noData
        }
        return id
    }

    private static func sanitizeSlugForPreviewEmail(_ slug: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-")
        let folded = slug.map { allowed.contains($0) ? $0 : "-" }
        let joined = String(folded)
        let parts = joined.split(separator: "-", omittingEmptySubsequences: true)
        let compact = parts.joined(separator: "-")
        return compact.isEmpty ? "carte" : String(compact.prefix(80))
    }

    private func loadLogoFromPhotoAsset(_ asset: PHAsset) async {
        guard let image = await asset.myfid_exportUIImage() else { return }
        await applyLogoImage(image)
    }

    private func applyLogoImage(_ image: UIImage) async {
        let path = CardLogoStorage.saveImage(image)
        await MainActor.run {
            logoURL = path ?? ""
            stripDisplayMode = "logo"
            if path != nil { logoPhotoItem = nil }
            persistLocalCardVisualsAfterImageChange()
        }
    }

    /// Fusionne deux listes de hex (#RRGGBB), sans doublons, ordre = logo puis fond.
    private static func mergeSuggestedHexColors(logoPart: [String], backgroundPart: [String], maxTotal: Int) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in logoPart + backgroundPart {
            let stripped = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "").uppercased()
            guard stripped.count == 6, stripped.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { continue }
            if seen.insert(stripped).inserted {
                out.append("#" + stripped)
                if out.count >= maxTotal { break }
            }
        }
        return out
    }

    /// Charge une UIImage depuis une URL (http) ou un chemin relatif (fichier local). Utilise le token pour l’API.
    private func loadLogoImage(from urlOrPath: String) async -> UIImage? {
        let trimmed = urlOrPath.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        if let u = APIResourceURL.resolved(from: trimmed), APIResourceURL.isOurAPIHost(u), u.path.hasSuffix("/logo") {
            let bust = MerchantLogoAssetCache.stripeLogoDisplayURL(u)
            return try? await AuthenticatedMediaLoader.loadAuthenticatedImage(from: bust)
        }
        if let u = APIResourceURL.resolved(from: trimmed), let scheme = u.scheme, scheme == "http" || scheme == "https" {
            let request = URLRequest(url: u)
            guard let (data, resp) = try? await URLSession.shared.data(for: request),
                  let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromData(data, maxPixelDimension: 2400)
            }.value
        }
        if let fp = APIResourceURL.localImageFilePathIfPresent(trimmed) {
            return await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromFile(at: fp, maxPixelDimension: 2400)
            }.value
        }
        if let fp = CardLogoStorage.fullPath(forRelative: trimmed) {
            return await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromFile(at: fp, maxPixelDimension: 2400)
            }.value
        }
        return nil
    }

    private func loadCardBackgroundUIImage() async -> UIImage? {
        let local = cardBackgroundImagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !local.isEmpty {
            if let displayPath = CardLogoStorage.resolvedDisplayPath(forStoredPath: local),
               FileManager.default.fileExists(atPath: displayPath) {
                return await Task.detached(priority: .userInitiated) {
                    ImageIODownsampling.imageFromFile(at: displayPath, maxPixelDimension: 2400)
                }.value
            }
            if local.hasPrefix("/"), FileManager.default.fileExists(atPath: local) {
                return await Task.detached(priority: .userInitiated) {
                    ImageIODownsampling.imageFromFile(at: local, maxPixelDimension: 2400)
                }.value
            }
        }
        if cardBackgroundWasRemoved { return nil }
        let remote = cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !remote.isEmpty else { return nil }
        if let u = APIResourceURL.resolved(from: remote),
           APIResourceURL.isOurAPIHost(u),
           u.path.contains("card-background") {
            return try? await AuthenticatedMediaLoader.loadAuthenticatedImage(from: u, maxPixelDimension: 900)
        }
        if let u = APIResourceURL.resolved(from: remote),
           let sc = u.scheme, sc == "http" || sc == "https" {
            let req = URLRequest(url: u)
            guard let (data, resp) = try? await URLSession.shared.data(for: req),
                  let http = resp as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else { return nil }
            return await Task.detached(priority: .userInitiated) {
                ImageIODownsampling.imageFromData(data, maxPixelDimension: 2400)
            }.value
        }
        return nil
    }

    private func refreshCardImageSuggestedColors() async {
        let logoTrim = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        var logoPart: [String] = []
        if !logoTrim.isEmpty, let image = await loadLogoImage(from: logoURL) {
            let forColors = image.preparingThumbnail(of: CGSize(width: 160, height: 160)) ?? image
            logoPart = LogoColorExtractor.dominantColors(from: forColors, maxColors: 5).map { h in h.hasPrefix("#") ? h : "#" + h }
        }
        var bgPart: [String] = []
        if let bgImage = await loadCardBackgroundUIImage() {
            let forColors = bgImage.preparingThumbnail(of: CGSize(width: 220, height: 220)) ?? bgImage
            bgPart = LogoColorExtractor.dominantColors(from: forColors, maxColors: 5).map { h in h.hasPrefix("#") ? h : "#" + h }
        }
        let merged = Self.mergeSuggestedHexColors(logoPart: logoPart, backgroundPart: bgPart, maxTotal: 8)
        await MainActor.run { cardImageSuggestedColors = merged }
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
            persistLocalCardVisualsAfterImageChange()
        }
    }

    private func applyMyCardCroppedImage(_ cropped: UIImage, spec: ImageCropSpec) async {
        switch spec {
        case .walletStripLogo:
            await applyLogoImage(cropped)
        case .walletCardBackground:
            await applyCardBackgroundImage(cropped)
        case .squareIcon:
            break
        case .stampIcon:
            await applyStampIconJPEGFromCroppedImage(cropped)
        case .flyerPromoLogo:
            break
        case .flyerCustomBackground:
            break
        }
    }

    private func applyStampIconJPEGFromCroppedImage(_ image: UIImage) async {
        /// Même cible 500 Ko max que l’icône logo (refus silencieux si l’on garde un seul JPEG 0,85).
        guard let payload = CardLogoStorage.compressedBase64ForLogoIconAPI(image: image) else { return }
        await MainActor.run {
            stampIconPendingBase64 = payload
            stampIconWasRemoved = false
            if let slug = AuthStorage.currentBusinessSlug {
                persistDisplaySnapshot(slug: slug)
            }
        }
    }

    private func stampIconRemoteURLForPreview() -> URL? {
        if let p = stampIconPendingBase64?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty { return nil }
        if stampIconWasRemoved { return nil }
        if !serverHasStampIconAsset { return nil }
        let s = serverStampIconURLString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if s.isEmpty { return nil }
        return APIResourceURL.resolved(from: s)
    }

    private func loadCurrentTemplate() {
        let t = dataService.createOrGetCurrentCardTemplate()
        displayName = t.displayName ?? "Ma Carte Fidélité"
        requiredStamps = Int(t.requiredStamps)
        primaryHex = t.primaryColorHex ?? AppTheme.WalletCardAppearanceDefaults.backgroundHex
        accentHex = t.accentColorHex ?? AppTheme.WalletCardAppearanceDefaults.bodyTextHex
        logoURL = t.logoURL ?? ""
        stampEmoji = t.stampEmoji ?? ""
        previewStampsCount = min(3, max(0, requiredStamps))
        syncPreviewBalancesFromSyncedMembers()
    }

    /// Aligne points / tampons de l’aperçu sur le 1er `ClientCard` (même source que le Wallet après sync).
    private func syncPreviewBalancesFromSyncedMembers() {
        guard let t = dataService.currentCardTemplate(),
              let first = dataService.uniqueClientCards(for: t).first else {
            previewPointsCount = 0
            previewStampsCount = 0
            return
        }
        let balance = Int(first.stampsCount)
        if programType == "points" {
            previewPointsCount = max(0, balance)
        } else {
            let cap = max(1, requiredStamps)
            previewStampsCount = min(max(0, balance), cap)
        }
    }

    /// Restaure le dernier rendu connu (GET échoué). Quand le GET réussit, on n’applique pas ce snapshot pour éviter d’écraser le SaaS.
    /// - Parameter restoreLogoFromSnapshot: `true` seulement si `dashboard/settings` a échoué (sinon `logoURL` vient de l’API).
    private func applyDisplaySnapshot(_ s: CardPreviewDisplaySnapshot, restoreLogoFromSnapshot: Bool = false) {
        programType = s.programType
        if programType != "points" && programType != "stamps" { programType = "points" }
        displayName = s.displayName.isEmpty ? displayName : s.displayName
        primaryHex = s.primaryHex.isEmpty ? primaryHex : s.primaryHex
        accentHex = s.accentHex.isEmpty ? accentHex : s.accentHex
        labelHex = s.labelHex
        stripDisplayMode = s.stripDisplayMode
        if stripDisplayMode != "text" { stripDisplayMode = "logo" }
        stripText = s.stripText
        if restoreLogoFromSnapshot {
            logoURL = s.logoURL
        }
        stampEmoji = s.stampEmoji
        requiredStamps = max(1, s.requiredStamps)
        labelMember = s.labelMember
        stampRewardLabel = s.stampRewardLabel
        stampMidRewardLabel = s.stampMidRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        startGameRewardLabel = s.startGameRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if let lr = s.labelRestants?.trimmingCharacters(in: .whitespacesAndNewlines), !lr.isEmpty {
            labelRestants = lr
        }
        if let tp = s.tierPoints { tierPoints = Self.normalizeTierStrings(tp) }
        if let tl = s.tierLabels { tierLabels = Self.normalizeTierStrings(tl) }
        let localBG = !(cardBackgroundImagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !localBG {
            // Restaurer le fichier local si le snapshot indique qu'il existe sur disque.
            if s.hasLocalCardBackground == true {
                let rel = CardLogoStorage.relativeCardBackgroundPath
                if let full = CardLogoStorage.fullPath(forRelative: rel),
                   FileManager.default.fileExists(atPath: full) {
                    cardBackgroundImagePath = rel
                }
            }
            if s.hasRemoteCardBackground, let u = s.cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                cardBackgroundRemoteURL = u
            } else {
                cardBackgroundRemoteURL = nil
            }
        }
        previewStampsCount = min(previewStampsCount, requiredStamps)
        if previewStampsCount < 0 { previewStampsCount = 0 }
        if let p = s.stampIconPendingBase64?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            stampIconPendingBase64 = p
            stampIconWasRemoved = false
        } else if s.stampIconWasRemoved == true {
            stampIconWasRemoved = true
            stampIconPendingBase64 = nil
        }
        if let has = s.hasServerStampIcon {
            serverHasStampIconAsset = has
        }
    }

    /// Restaure `cardBackgroundImagePath` depuis le snapshot si le fichier local existe encore sur disque.
    /// Appelé synchroniquement dans `onAppear` pour que l'aperçu s'affiche immédiatement, avant même
    /// que `loadCardSettingsFromAPI()` ne complète — empêche `buildDisplaySnapshot()` d'écraser
    /// `hasLocalCardBackground` avec `false` alors que le fichier est présent.
    private func restoreLocalBackgroundFromSnapshot() {
        guard let slug = AuthStorage.currentBusinessSlug,
              let snap = CardPreviewDisplaySnapshotStore.load(slug: slug),
              snap.hasLocalCardBackground == true,
              cardBackgroundImagePath == nil else { return }
        let rel = CardLogoStorage.relativeCardBackgroundPath
        guard let full = CardLogoStorage.fullPath(forRelative: rel),
              FileManager.default.fileExists(atPath: full) else { return }
        cardBackgroundImagePath = rel
    }

    private func mergeStampIconFromDisplaySnapshotIfNeeded() {
        guard let slug = AuthStorage.currentBusinessSlug,
              let snap = CardPreviewDisplaySnapshotStore.load(slug: slug) else { return }
        if let p = snap.stampIconPendingBase64?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
            stampIconPendingBase64 = p
            stampIconWasRemoved = false
        } else if snap.stampIconWasRemoved == true {
            stampIconWasRemoved = true
            stampIconPendingBase64 = nil
        } else if snap.hasServerStampIcon == true {
            serverHasStampIconAsset = true
        }
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
            headerRightText: CardRewardsHeaderLink.displayText,
            labelMember: labelMember,
            hasRemoteCardBackground: hasBG,
            cardBackgroundRemoteURL: hasBG ? cardBackgroundRemoteURL : nil,
            hasLocalCardBackground: !(cardBackgroundImagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            stampRewardLabel: stampRewardLabel,
            stampMidRewardLabel: stampMidRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : stampMidRewardLabel,
            startGameRewardLabel: startGameRewardLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : startGameRewardLabel,
            labelRestants: labelRestants.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : labelRestants,
            tierPoints: tierPoints,
            tierLabels: tierLabels,
            stampIconPendingBase64: stampIconPendingBase64,
            stampIconWasRemoved: stampIconWasRemoved,
            hasServerStampIcon: serverHasStampIconAsset
        )
    }

    private func persistDisplaySnapshot(slug: String) {
        CardPreviewDisplaySnapshotStore.save(buildDisplaySnapshot(slug: slug), slug: slug)
    }

    /// Met à jour Core Data + snapshot UserDefaults pour l’aperçu Accueil et le prochain retour sur Ma carte (chemins locaux `CardLogos/…` inclus).
    private func persistLocalCardVisualsAfterImageChange(stampEmojiOverride: String? = nil) {
        let nameToSave = displayName.trimmingCharacters(in: .whitespaces)
        let nameFinal = nameToSave.isEmpty ? "Ma Carte Fidélité" : nameToSave
        let stampResolved = (stampEmojiOverride ?? stampEmoji).trimmingCharacters(in: .whitespacesAndNewlines)
        dataService.updateCardTemplate(
            displayName: nameFinal,
            requiredStamps: Int32(max(1, requiredStamps)),
            primaryColorHex: primaryHex,
            accentColorHex: accentHex,
            logoURL: logoURL.isEmpty ? nil : logoURL,
            stampEmoji: stampResolved.isEmpty ? nil : String(stampResolved.prefix(32))
        )
        if let slug = AuthStorage.currentBusinessSlug {
            persistDisplaySnapshot(slug: slug)
        }
    }

    private func prefetchCardMediaURLs(logoURLString: String, backgroundURLString: String?, stampIconURLString: String? = nil) async {
        let logo = logoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !logo.isEmpty, let u = APIResourceURL.resolved(from: logo),
           APIResourceURL.isOurAPIHost(u), u.path.hasSuffix("/logo") {
            let bust = MerchantLogoAssetCache.stripeLogoDisplayURL(u)
            await AuthenticatedMediaLoader.prefetch(url: bust)
        }
        if let bg = backgroundURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !bg.isEmpty,
           let u = APIResourceURL.resolved(from: bg),
           APIResourceURL.isOurAPIHost(u), u.path.contains("card-background") {
            await AuthenticatedMediaLoader.prefetch(url: u)
        }
        if let st = stampIconURLString?.trimmingCharacters(in: .whitespacesAndNewlines), !st.isEmpty,
           let u = APIResourceURL.resolved(from: st),
           APIResourceURL.isOurAPIHost(u) {
            await AuthenticatedMediaLoader.prefetch(url: u)
        }
    }

    private func prefetchCardMediaFromCurrentState() async {
        await prefetchCardMediaURLs(logoURLString: logoURL, backgroundURLString: cardBackgroundRemoteURL, stampIconURLString: serverStampIconURLString)
    }

    /// Charge les réglages complets depuis l’API (design + règles) pour que l’aperçu et le pass « Tester dans l’Apple Wallet » reflètent les changements faits sur le SaaS ou ailleurs.
    private func loadCardSettingsFromAPI() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
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
                    labelHex = AppTheme.WalletCardAppearanceDefaults.labelTitlesHex
                }
                stripDisplayMode = (settings.stripDisplayMode ?? "logo").lowercased()
                if stripDisplayMode != "text" { stripDisplayMode = "logo" }
                stripText = settings.stripText ?? ""
                programType = (settings.programType ?? "points").lowercased()
                if programType != "points" && programType != "stamps" { programType = "points" }
                if let rs = settings.requiredStamps, rs > 0 {
                    requiredStamps = rs
                }
                pointsPerEuro = settings.pointsPerEuro ?? 1
                pointsPerVisit = settings.pointsPerVisit ?? 0
                pointsMinAmountEur = settings.pointsMinAmountEur.map { String(format: "%.2f", $0) } ?? ""
                if let tiers = settings.pointsRewardTiers, !tiers.isEmpty {
                    let sorted = tiers.filter { $0.points > 0 }.sorted { $0.points < $1.points }
                    for i in 0..<MyCardPointsRewardTiers.slotCount {
                        if i < sorted.count {
                            tierPoints[i] = String(sorted[i].points)
                            tierLabels[i] = sorted[i].label.isEmpty ? "Récompense" : sorted[i].label
                        } else {
                            tierPoints[i] = ""
                            tierLabels[i] = ""
                        }
                    }
                } else {
                    tierPoints = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
                    tierLabels = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
                }
                stampRewardLabel = settings.stampRewardLabel ?? ""
                let midSaved = settings.stampMidRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                stampMidRewardLabel = midSaved
                serverHasStampIconAsset = (settings.hasStampIcon == true)
                if settings.hasStampIcon == true,
                   let su = settings.stampIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !su.isEmpty {
                    serverStampIconURLString = su
                } else {
                    serverStampIconURLString = nil
                }
                if let em = settings.stampEmoji?.trimmingCharacters(in: .whitespacesAndNewlines), !em.isEmpty {
                    stampEmoji = em
                }
                expiryMonths = settings.expiryMonths.map { String($0) } ?? ""
                sector = settings.sector ?? ""
                welcomeBonusEnabled = true
                welcomeBonusAmount = programType == "points" ? 10 : 1
                backTerms = settings.backTerms ?? ""
                backContact = settings.backContact ?? ""
                labelRestants = settings.labelRestants ?? ""
                labelMember = settings.labelMember ?? ""
                notificationTitleOverride = settings.notificationTitleOverride ?? ""
                notificationChangeMessage = settings.notificationChangeMessage ?? ""
                // Ne pas effacer un tampon / icône en cours d’édition non enregistré (le GET ne représente pas ce brouillon).
                let apiLogo = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let currentLogo = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
                let localLogoFileExists: Bool = {
                    guard let path = CardLogoStorage.fullPath(forRelative: CardLogoStorage.relativeLogoPath) else { return false }
                    return FileManager.default.fileExists(atPath: path)
                }()
                if CardLogoStorage.isLocalPendingLogoReference(currentLogo) {
                    // Conserver le fichier local jusqu’à envoi réussi — sauf si le fichier a été supprimé.
                    if !localLogoFileExists {
                        logoURL = apiLogo
                    }
                } else if !apiLogo.isEmpty {
                    // currentLogo est une URL API (ou vide). Préférer le fichier local s’il existe et
                    // est plus récent que le logo serveur (évite de basculer sur AuthenticatedLogoView
                    // lors d’une seconde navigation alors que le fichier local est toujours valide).
                    let localUploadAt = UserDefaults.standard.object(forKey: SyncService.lastLogoUploadAtKey) as? Date
                    if localUploadAt != nil && localLogoFileExists {
                        var serverIsNewer = false
                        if let serverAtStr = settings.logoUpdatedAt?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !serverAtStr.isEmpty,
                           let serverAt = ISO8601DateFormatter().date(from: serverAtStr) {
                            serverIsNewer = serverAt > localUploadAt!
                        }
                        logoURL = serverIsNewer ? apiLogo : CardLogoStorage.relativeLogoPath
                    } else {
                        logoURL = apiLogo
                    }
                } else {
                    logoURL = apiLogo
                }
                if settings.hasCardBackground == true {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
                    var bgURL = "\(base)/api/businesses/\(enc)/card-background"
                    if let v = settings.cardBackgroundUpdatedAt?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                        let q = v.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? v
                        bgURL += "?v=\(q)"
                    }
                    cardBackgroundRemoteURL = bgURL
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
                    let mergedLogo = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    t.logoURL = mergedLogo.isEmpty ? nil : logoURL
                    try? viewContext.save()
                }
                persistDisplaySnapshot(slug: slug)
                syncPreviewBalancesFromSyncedMembers()
                capturePersistedBaseline()
                Task { await prefetchCardMediaFromCurrentState() }
            }
        } catch {
            await MainActor.run {
                rulesLoadedFromAPI = true
                dashboardSettingsHydrated = false
            }
        }
    }

    private func capturePersistedBaseline() {
        lastPersistedSnapshot = makePersistedSnapshot()
    }

    /// Même chemin (`CardLogos/cardLogo.png` / `cardBackground.png`) après un nouvel import — seule la date de modification change.
    private func fileContentModificationDate(forStoredPath stored: String) -> Date? {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let resolved: String?
        if trimmed.hasPrefix("/") {
            resolved = trimmed
        } else if trimmed.lowercased().hasPrefix("file:"), let u = URL(string: trimmed) {
            resolved = u.path
        } else {
            resolved = CardLogoStorage.fullPath(forRelative: trimmed)
        }
        guard let path = resolved, FileManager.default.fileExists(atPath: path) else { return nil }
        let url = URL(fileURLWithPath: path)
        return (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func snapshotLocalLogoFileModification() -> Date? {
        let t = logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let lower = t.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return nil }
        return fileContentModificationDate(forStoredPath: t)
    }

    private func snapshotLocalCardBackgroundFileModification() -> Date? {
        guard let p = cardBackgroundImagePath?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty else { return nil }
        return fileContentModificationDate(forStoredPath: p)
    }

    private func makePersistedSnapshot() -> MyCardPersistedSnapshot {
        MyCardPersistedSnapshot(
            displayName: displayName,
            requiredStamps: requiredStamps,
            primaryHex: primaryHex,
            accentHex: accentHex,
            labelHex: labelHex,
            stripDisplayMode: stripDisplayMode,
            stripText: stripText,
            logoURL: logoURL,
            localLogoFileModification: snapshotLocalLogoFileModification(),
            stampEmoji: stampEmoji,
            cardBackgroundImagePath: cardBackgroundImagePath,
            localCardBackgroundFileModification: snapshotLocalCardBackgroundFileModification(),
            cardBackgroundRemoteURL: cardBackgroundRemoteURL,
            cardBackgroundWasRemoved: cardBackgroundWasRemoved,
            programType: programType,
            pointsPerEuro: pointsPerEuro,
            pointsPerVisit: pointsPerVisit,
            pointsMinAmountEur: pointsMinAmountEur,
            tierPoints: tierPoints,
            tierLabels: tierLabels,
            stampRewardLabel: stampRewardLabel,
            expiryMonths: expiryMonths,
            sector: sector,
            stampMidRewardLabel: stampMidRewardLabel,
            startGameRewardLabel: startGameRewardLabel,
            backTerms: backTerms,
            backContact: backContact,
            labelRestants: labelRestants,
            labelMember: labelMember,
            notificationTitleOverride: notificationTitleOverride,
            notificationChangeMessage: notificationChangeMessage,
            stampIconWasRemoved: stampIconWasRemoved,
            stampIconPendingBase64: stampIconPendingBase64
        )
    }

    /// Compresse logo / fond carte hors du thread UI (resize + JPEG peuvent prendre plusieurs centaines de ms).
    private func prepareDashboardMediaPayloadsForSave(
        cardBackgroundWasRemoved: Bool,
        cardBackgroundImagePath: String?,
        logoURL: String
    ) async -> (cardBackgroundBase64: String?, logoBase64: String?, logoUrl: String?) {
        await Task.detached(priority: .userInitiated) {
            var cardBackgroundBase64: String? = nil
            if cardBackgroundWasRemoved {
                cardBackgroundBase64 = ""
            } else if let bgPath = cardBackgroundImagePath, !bgPath.isEmpty {
                cardBackgroundBase64 = CardLogoStorage.compressedBase64FromFile(path: bgPath)
            }
            var logoBase64: String? = nil
            var logoUrl: String? = nil
            if !logoURL.isEmpty {
                let trimmed = logoURL.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                    let url = URL(string: trimmed)
                    if let url, url.host() != APIConfig.baseURL.host() || !url.path.contains("/logo") {
                        logoUrl = trimmed
                    }
                } else if trimmed.contains("CardLogos") || trimmed.hasPrefix("/") {
                    logoBase64 = CardLogoStorage.compressedWalletStripLogoBase64FromFile(path: trimmed)
                }
            } else {
                logoBase64 = ""
            }
            return (cardBackgroundBase64, logoBase64, logoUrl)
        }.value
    }

    /// Retourne `false` si l'envoi des réglages au serveur a échoué (réseau, validation, etc.).
    /// - Parameter skipPostSaveReload: si `true`, pas de `GET dashboard/settings` après succès (ex. flux Apple Wallet : évite un aller-retour réseau inutile).
    @discardableResult
    private func saveTemplate(skipPostSaveReload: Bool = false) async -> Bool {
        if !cardMissingRequirements.isEmpty {
            let titles = cardMissingRequirements.map(\.title).joined(separator: " · ")
            await MainActor.run {
                saveLogoError = "Complétez d’abord : \(titles)."
            }
            return false
        }

        let nameToSave = displayName.trimmingCharacters(in: .whitespaces)
        let nameFinal = nameToSave.isEmpty ? "Ma Carte Fidélité" : nameToSave
        let bgHex = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
        let fgHex = accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex

        dataService.updateCardTemplate(
            displayName: nameFinal,
            requiredStamps: Int32(max(1, requiredStamps)),
            primaryColorHex: primaryHex,
            accentColorHex: accentHex,
            logoURL: logoURL.isEmpty ? nil : logoURL,
            stampEmoji: stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(32))
        )
        UserDefaults.standard.set(Date(), forKey: "myfidpass.templateLastSavedAt")

        guard let slug = AuthStorage.currentBusinessSlug else {
            await MainActor.run { capturePersistedBaseline() }
            return true
        }
        let (cardBackgroundBase64, logoBase64, logoUrl) = await prepareDashboardMediaPayloadsForSave(
            cardBackgroundWasRemoved: cardBackgroundWasRemoved,
            cardBackgroundImagePath: cardBackgroundImagePath,
            logoURL: logoURL
        )
        var rewardTiers: [PointsRewardTierPayload]? = nil
        if programType == "points" {
            var tiers: [PointsRewardTierPayload] = []
            for i in 0..<MyCardPointsRewardTiers.slotCount {
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
                if programType == "stamps" {
                    patch.requiredStamps = max(1, requiredStamps)
                }
                // Mode points : ne pas envoyer required_stamps (le serveur garde la cohérence avec program_type).
                patch.logoBase64 = logoBase64
                patch.logoUrl = logoUrl
                patch.stampEmoji = stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(32))
                // Image de fond : uniquement en mode points ; en tampons on supprime le fond côté serveur.
                patch.cardBackgroundBase64 = programType == "points" ? cardBackgroundBase64 : ""
                patch.programType = programType
                patch.pointsPerEuro = programType == "points" ? pointsPerEuro : nil
                patch.pointsPerVisit = programType == "points" ? pointsPerVisit : nil
                patch.pointsMinAmountEur = programType == "points" ? ptsMinEur : nil
                patch.pointsRewardTiers = programType == "points" ? rewardTiers : nil
                patch.stampRewardLabel = stampRewardLabel.isEmpty ? nil : String(stampRewardLabel.prefix(120))
                patch.welcomeBonusEnabled = 1
                patch.welcomeBonusAmount = programType == "stamps" ? 1 : 10
                if programType == "stamps" {
                    let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespaces)
                    if mid.isEmpty {
                        patch.stampMidRewardLabelIsExplicitNull = true
                    } else {
                        patch.stampMidRewardLabel = String(mid.prefix(120))
                    }
                }
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
                    patch.labelRestants = labelRestants.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(labelRestants.prefix(64))
                    patch.labelMember = labelMember.trimmingCharacters(in: .whitespaces).isEmpty
                        ? ""
                        : String(labelMember.prefix(64))
                    patch.headerRightText = String(CardRewardsHeaderLink.displayText.prefix(64))
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
                let stampIconServerAfterPatch: Bool? = await MainActor.run {
                    guard dashboardSettingsHydrated else { return nil }
                    if stampIconWasRemoved { return false }
                    if let p = stampIconPendingBase64?.trimmingCharacters(in: .whitespacesAndNewlines), !p.isEmpty {
                        return true
                    }
                    return nil
                }
                _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
                /// Avant le GET de relecture : snapshot UserDefaults à jour pour l’accueil (évite « Finalisez » si l’utilisateur quitte pendant `loadCardSettingsFromAPI`).
                await MainActor.run {
                    saveLogoError = nil
                    if cardBackgroundBase64 == "" { cardBackgroundWasRemoved = false }
                    if let v = stampIconServerAfterPatch {
                        serverHasStampIconAsset = v
                    }
                    if stampIconWasRemoved || stampIconPendingBase64 != nil {
                        stampIconWasRemoved = false
                        stampIconPendingBase64 = nil
                    }
                    persistDisplaySnapshot(slug: slug)
                }
                if skipPostSaveReload {
                    await MainActor.run {
                        if let s = AuthStorage.currentBusinessSlug {
                            persistDisplaySnapshot(slug: s)
                        }
                        syncPreviewBalancesFromSyncedMembers()
                        capturePersistedBaseline()
                    }
                } else {
                    await loadCardSettingsFromAPI()
                    // `loadCardSettingsFromAPI` met déjà à jour l’aperçu + `syncPreviewBalancesFromSyncedMembers`.
                }
                // La sync complète (membres + transactions) peut prendre plusieurs secondes : arrière-plan.
                Task(priority: .utility) { await syncService.syncAfterServerMutation() }
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
                    // Ne pas écraser logoURL ici : le logo local est déjà visible et correct.
                    // Changer logoURL après capturePersistedBaseline() ferait réapparaître le bouton
                    // "Enregistrer" et remplacerait AsyncLocalFileImage par AuthenticatedLogoView
                    // (qui montre un ProgressView pendant le téléchargement → logo "disparu").
                    // Core Data est déjà mis à jour avec apiLogoURL pour les prochaines sessions.
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoUploadAtKey)
                }
            return true
        } catch {
            await MainActor.run {
                let detail = (error as? APIError)?.errorDescription ?? error.localizedDescription
                saveLogoError =
                    "Impossible d'enregistrer la carte sur le serveur.\n\n\(detail)"
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

    /// Ancienne teinte pas dans la grille : pastille « Actuelle » pour conserver ou remplacer par une teinte vive.
    private var legacyHexForOrphan: String? {
        let d = Self.hexDigits(hex)
        guard d.count == 6, d.allSatisfy(\.isHexDigit) else { return nil }
        if AppVibrantColorPalette.containsHex6(d) { return nil }
        return d
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
                    if let leg = legacyHexForOrphan {
                        let full = "#" + leg
                        ColorPresetButton(hex: full, name: "Actuelle", isSelected: Self.hexDigits(hex) == leg) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hex = full
                            }
                        }
                    }
                    ForEach(AppVibrantColorPalette.cardRowPresets, id: \.hex) { preset in
                        let presetNorm = "#" + CardColorPaletteUX.normalizeHex(preset.hex)
                        let selected = Self.hexDigits(hex) == CardColorPaletteUX.normalizeHex(preset.hex)
                        ColorPresetButton(hex: presetNorm, name: preset.name, isSelected: selected) {
                            withAnimation(.easeOut(duration: 0.2)) {
                                hex = presetNorm
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
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

// MARK: - Désactive le swipe « retour » si la carte a des modifications locales (évite de quitter sans choix).

private struct MyCardNavigationPopGate: UIViewControllerRepresentable {
    var blockInteractivePop: Bool

    func makeUIViewController(context: Context) -> MyCardPopAnchorViewController {
        MyCardPopAnchorViewController()
    }

    func updateUIViewController(_ vc: MyCardPopAnchorViewController, context: Context) {
        vc.blockInteractivePop = blockInteractivePop
    }
}

private final class MyCardPopAnchorViewController: UIViewController {
    var blockInteractivePop = false {
        didSet { applyPopGestureEnabled() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyPopGestureEnabled()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        applyPopGestureEnabled()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        applyPopGestureEnabled()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed {
            navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        }
    }

    private func applyPopGestureEnabled() {
        navigationController?.interactivePopGestureRecognizer?.isEnabled = !blockInteractivePop
    }
}

#Preview {
    NavigationStack {
        MyCardView(context: PersistenceController.preview.container.viewContext)
            .environmentObject(SyncService(container: PersistenceController.preview.container))
            .environmentObject(MainTabRouter())
    }
}
