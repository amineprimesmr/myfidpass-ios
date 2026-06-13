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

struct MyCardView: View {
    /// Commerce affiché — figé à l’ouverture pour éviter de mélanger logo / couleurs entre comptes.
    private let businessSlug: String
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
    /// Zoom fluide sur le logo (coin haut-gauche de l’aperçu).
    @State private var cardLogoZoomFocused = false
    @State private var cardLogoZoomScale: CGFloat = 1
    @State private var cardLogoZoomOffsetX: CGFloat = 0
    @State private var cardLogoZoomOffsetY: CGFloat = 0
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
    /// Affichage du segmented control (peut diverger de `programType` tant que l’alerte n’est pas confirmée).
    @State private var programPickerSelection: String = "points"
    @State private var pointsPerEuro: Int = 1
    @State private var pointsPerVisit: Int = 0
    @State private var pointsMinAmountEur: String = ""
    /// Paliers points (10 pts en 1ʳᵉ ligne + paliers suivants), alignés sur le SaaS web.
    @State private var tierPoints: [String] = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
    @State private var tierLabels: [String] = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
    @State private var tierMinPurchases: [String] = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
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
    /// Récompense au 5ᵉ passage (désactivable si le programme tampons le permet).
    @State private var stampMidRewardEnabled: Bool = false
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
    /// Alerte avant de quitter la page si des changements ne sont pas enregistrés.
    @State private var showUnsavedLeaveAlert = false
    /// Confirmation bascule Points ↔ Tampons quand des clients ont déjà une carte.
    @State private var showProgramSwitchConfirm = false
    @State private var pendingProgramSwitchFrom: String?
    @State private var pendingProgramType: String?
    /// Bascule confirmée dans l’alerte mais pas encore enregistrée sur le serveur.
    @State private var programTypeSwitchAwaitingSave = false
    init(context: NSManagedObjectContext, businessSlug: String? = nil) {
        let resolved = businessSlug?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        self.businessSlug = resolved
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    /// True si des changements locaux ne sont pas encore envoyés au serveur / Core Data « sauvé ».
    private var hasUnsavedCardChanges: Bool {
        guard let baseline = lastPersistedSnapshot else { return false }
        return baseline != makePersistedSnapshot()
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
            stampMidRewardLabel: stampMidRewardLabel,
            startGameRewardLabel: startGameRewardLabel,
            stampMidRewardEnabled: stampMidRewardEnabled
        )
    }

    private var rewardsConfigurationComplete: Bool {
        MyCardCompletionRequirements.hasRecompensesCompletes(
            programType: programType,
            tierPoints: tierPoints,
            tierLabels: tierLabels,
            requiredStamps: requiredStamps,
            stampRewardLabel: stampRewardLabel,
            stampMidRewardLabel: stampMidRewardLabel,
            startGameRewardLabel: startGameRewardLabel,
            stampMidRewardEnabled: stampMidRewardEnabled
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

    private var cardCompletionPreviewZones: Set<CardPreviewEditZone> {
        var zones = Set(cardMissingRequirements.map(\.suggestedEditZone))
        if cardMissingRequirements.contains(.couleursCarte) {
            zones.insert(.cardAppearance)
        }
        return zones
    }

    private var shouldShowCompletionPills: Bool {
        !cardMissingRequirements.isEmpty
    }

    var body: some View {
        myCardNavigationContent
            .id(businessSlug)
    }

    private var myCardScrollContent: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            programModePickerSection
            previewSection
            Spacer(minLength: 0)
            actionsSection
        }
        .padding(.bottom, bottomScrollPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppTheme.Colors.background)
        .background(MyCardNavigationPopGate(blockInteractivePop: hasUnsavedCardChanges))
    }

    private var myCardInteractiveContent: some View {
        myCardScrollWithLifecycle
            .sheet(item: $customizationZone) { zone in
                MyCardCustomizationSheetContainer(
                    zone: zone,
                    pack: cardCustomizationBindPack,
                    actions: cardCustomizationActions,
                    cardImageSuggestedColors: cardImageSuggestedColors,
                    dashboardSettingsHydrated: dashboardSettingsHydrated,
                    canSaveRewards: rewardsConfigurationComplete,
                    rewardsSaveInFlight: cardSettingsSaveInFlight,
                    hasUnsavedCardChanges: hasUnsavedCardChanges,
                    onHeaderRightSave: myCardHeaderRightSaveAction,
                    onCropComplete: applyMyCardCroppedImage,
                    refreshSuggestedColors: refreshCardImageSuggestedColors,
                    reloadWalletPassBackSettings: { await loadCardSettingsFromAPI(respectingUnsavedEdits: true) }
                )
            }
            .overlay { walletPassPresenterOverlay }
    }

    private var myCardScrollWithLifecycle: some View {
        myCardScrollContent
            .onAppear {
                guard !businessSlug.isEmpty else { return }
                CardLogoStorage.migrateLegacyFlatAssetsIfNeeded(for: businessSlug)
                resetCardDraftStateForBusinessLoad()
                loadCurrentTemplate()
                restoreLocalBackgroundFromSnapshot()
                mergeStampIconFromDisplaySnapshotIfNeeded()
                if let snap = CardPreviewDisplaySnapshotStore.load(slug: businessSlug) {
                    applyDisplaySnapshot(snap, restoreLogoFromSnapshot: true)
                }
                Task {
                    await loadCardSettingsFromAPI()
                    await MainActor.run {
                        syncPreviewBalancesFromSyncedMembers()
                        if !dashboardSettingsHydrated,
                           let snap = CardPreviewDisplaySnapshotStore.load(slug: businessSlug) {
                            applyDisplaySnapshot(snap, restoreLogoFromSnapshot: true)
                            syncPreviewBalancesFromSyncedMembers()
                        }
                        capturePersistedBaseline()
                    }
                    await prefetchCardMediaFromCurrentState()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassActiveBusinessDidChange)) { note in
                guard let newSlug = note.userInfo?["slug"] as? String,
                      !newSlug.isEmpty,
                      newSlug != businessSlug else { return }
                dismiss()
            }
            .onChange(of: syncService.lastSyncDate) { _, newDate in
                guard newDate != nil else { return }
                guard !hasUnsavedCardChanges else { return }
                Task {
                    await loadCardSettingsFromAPI(respectingUnsavedEdits: true)
                    await MainActor.run { syncPreviewBalancesFromSyncedMembers() }
                }
            }
            .onChange(of: requiredStamps) { _, new in
                if previewStampsCount > new { previewStampsCount = new }
            }
            .onChange(of: customizationZone) { _, new in
                if new == nil { setCardLogoZoomFocused(false) }
            }
            .onChange(of: cardLogoZoomFocused) { _, focused in
                syncCardLogoZoomTransform(focused: focused)
            }
    }

    private func myCardHeaderRightSaveAction() async -> Bool {
        await MainActor.run { cardSettingsSaveInFlight = true }
        let ok = await saveRewardsOnly()
        await MainActor.run {
            cardSettingsSaveInFlight = false
            if ok {
                triggerSavedFeedback()
                customizationZone = nil
            }
        }
        return ok
    }

    @ViewBuilder
    private var walletPassPresenterOverlay: some View {
        if walletPassData != nil {
            AddToWalletPresenter(passData: walletPassData, onDismiss: dismissWalletPassPresenter)
                .frame(width: 1, height: 1)
        }
    }

    private func dismissWalletPassPresenter() {
        walletPassData = nil
    }

    private var myCardWalletAlertContent: some View {
        myCardInteractiveContent
        .alert(walletErrorAlertTitle, isPresented: .constant(walletErrorMessage != nil)) {
            Button("OK", role: .cancel) { walletErrorMessage = nil }
        } message: {
            if let msg = walletErrorMessage {
                Text(msg)
            }
        }
    }

    private var myCardSaveLogoAlertContent: some View {
        myCardWalletAlertContent
        .alert("Enregistrement", isPresented: .constant(saveLogoError != nil)) {
            Button("OK") { saveLogoError = nil }
        } message: {
            if let msg = saveLogoError { Text(msg) }
        }
    }

    private var myCardProgramSwitchAlertContent: some View {
        myCardSaveLogoAlertContent
        .alert("Changer le mode ?", isPresented: $showProgramSwitchConfirm) {
            Button("Annuler", role: .cancel) {
                pendingProgramType = nil
                pendingProgramSwitchFrom = nil
                programTypeSwitchAwaitingSave = false
                programPickerSelection = programType
            }
            Button("Confirmer", role: .destructive) {
                if let next = pendingProgramType {
                    programType = next
                    programPickerSelection = next
                    applyProgramTypeSideEffects(for: next)
                    programTypeSwitchAwaitingSave = true
                }
                pendingProgramType = nil
                pendingProgramSwitchFrom = nil
            }
        } message: {
            Text(programSwitchConfirmMessage)
        }
    }

    private var myCardUnsavedLeaveAlertContent: some View {
        myCardProgramSwitchAlertContent
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
    }

    private var walletErrorAlertTitle: String {
        cardMissingRequirements.isEmpty ? "Aperçu Wallet indisponible" : "Carte incomplète"
    }

    private var myCardNavigationContent: some View {
        myCardUnsavedLeaveAlertContent
        .navigationTitle("Ma carte")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(AppTheme.Colors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar { myCardToolbar }
    }

    @ToolbarContentBuilder
    private var myCardToolbar: some ToolbarContent {
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
                            if ok {
                                triggerSavedFeedback()
                                schedulePostCardFlyerPromoIfEligible()
                            }
                        }
                    }
                } label: {
                    if cardSettingsSaveInFlight {
                        ProgressView()
                            .tint(Color(red: 0, green: 122 / 255, blue: 1))
                    } else {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .tint(Color(red: 0, green: 122 / 255, blue: 1))
                .accessibilityLabel("Enregistrer")
                .disabled(cardSettingsSaveInFlight || !canPersistCardDraft)
            }
        }
    }

    /// Quitter la page : alerte si brouillon non sauvé (ne pas enregistrer ni fermer sans choix explicite).
    private func requestLeaveMyCard() {
        customizationZone = nil
        if cardLogoZoomFocused {
            setCardLogoZoomFocused(false)
            return
        }
        if hasUnsavedCardChanges {
            showUnsavedLeaveAlert = true
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
        syncProgramPickerWithCommitted()
        pointsPerEuro = snap.pointsPerEuro
        pointsPerVisit = snap.pointsPerVisit
        pointsMinAmountEur = snap.pointsMinAmountEur
        tierPoints = Self.normalizeTierStrings(snap.tierPoints)
        tierLabels = Self.normalizeTierStrings(snap.tierLabels)
        if programType == "points" {
            MyCardProgramDefaults.sanitizeEditableTierSlots(tierPoints: &tierPoints, tierLabels: &tierLabels)
        }
        stampRewardLabel = snap.stampRewardLabel
        expiryMonths = snap.expiryMonths
        sector = snap.sector
        stampMidRewardLabel = snap.stampMidRewardLabel
        stampMidRewardEnabled = snap.stampMidRewardEnabled
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
        if !businessSlug.isEmpty {
            persistDisplaySnapshot(slug: businessSlug)
        }
    }

    private static func normalizeTierStrings(_ arr: [String]) -> [String] {
        var out = Array(arr.prefix(MyCardPointsRewardTiers.slotCount))
        while out.count < MyCardPointsRewardTiers.slotCount { out.append("") }
        return out
    }

    // MARK: - Aperçu carte (Wallet uniquement)

    /// Binding dédié : les mises à jour programmatiques (`syncProgramPickerWithCommitted`) ne déclenchent pas la confirmation.
    private var programPickerBinding: Binding<String> {
        Binding(
            get: { programPickerSelection },
            set: { newValue in
                let oldValue = programPickerSelection
                guard oldValue != newValue else { return }
                if shouldConfirmProgramTypeSwitch(from: oldValue, to: newValue) {
                    pendingProgramSwitchFrom = oldValue
                    pendingProgramType = newValue
                    showProgramSwitchConfirm = true
                } else {
                    programPickerSelection = newValue
                    programType = newValue
                    applyProgramTypeSideEffects(for: newValue)
                }
            }
        )
    }

    /// Choix Points / Tampons : au-dessus de la carte (plus simple que dans les feuilles de modification).
    private var programModePickerSection: some View {
        Picker("", selection: programPickerBinding) {
            Text("Points").tag("points")
            Text("Tampons").tag("stamps")
        }
        .pickerStyle(.segmented)
        .accessibilityLabel(Text("Type de programme : Points ou Tampons"))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.sm)
        .transaction { $0.disablesAnimations = true }
    }

    private func shouldConfirmProgramTypeSwitch(from oldType: String, to newType: String) -> Bool {
        guard oldType != newType else { return false }
        return dataService.totalClientCardsCount() > 0
    }

    private var programSwitchConfirmMessage: String {
        let fromRaw = pendingProgramSwitchFrom ?? programType
        let toRaw = pendingProgramType ?? programType
        let fromLabel = fromRaw == "stamps" ? "Tampons" : "Points"
        let toLabel = toRaw == "stamps" ? "Tampons" : "Points"
        let n = dataService.totalClientCardsCount()
        return "Vous avez \(n) client\(n > 1 ? "s" : ""). Passer de \(fromLabel) à \(toLabel) remet tous les soldes à zéro et efface l’historique. Irréversible — enregistrez ensuite la carte."
    }

    private func syncProgramPickerWithCommitted() {
        programPickerSelection = programType
    }

    private func applyProgramTypeSideEffects(for new: String) {
        welcomeBonusEnabled = true
        welcomeBonusAmount = new == "points" ? 10 : 1
        if new == "points" {
            if pointsPerEuro < 1 { pointsPerEuro = 1 }
            restorePointsTiersIfSlotsEmpty()
            MyCardProgramDefaults.ensureStartGameRewardLabel(&startGameRewardLabel)
        } else if new == "stamps" {
            if requiredStamps < 5 { requiredStamps = 10 }
            if previewStampsCount > requiredStamps { previewStampsCount = requiredStamps }
            cardBackgroundPhotoItem = nil
        }
        if !businessSlug.isEmpty {
            persistDisplaySnapshot(slug: businessSlug)
        }
    }

    /// Réinjecte les paliers points depuis le snapshot local si l’API les a effacés lors d’un passage tampons.
    private func restorePointsTiersIfSlotsEmpty() {
        let empty = tierPoints.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && tierLabels.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard empty else { return }
        guard !businessSlug.isEmpty,
              let snap = CardPreviewDisplaySnapshotStore.load(slug: businessSlug) else { return }
        if let tp = snap.tierPoints, tp.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            tierPoints = Self.normalizeTierStrings(tp)
            tierLabels = Self.normalizeTierStrings(snap.tierLabels ?? [])
            if let sg = snap.startGameRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines), !sg.isEmpty {
                startGameRewardLabel = sg
            }
            MyCardProgramDefaults.sanitizeEditableTierSlots(tierPoints: &tierPoints, tierLabels: &tierLabels)
            MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                startGameRewardLabel: &startGameRewardLabel,
                tierPoints: tierPoints,
                tierLabels: tierLabels
            )
        }
    }

    /// Même URL que le lien « Lien et QR code » / page carte publique.
    private var fidelityCardPageURLString: String? {
        guard !businessSlug.isEmpty,
              let url = LegalURLs.fidelityCardPage(slug: businessSlug) else { return nil }
        return url.absoluteString
    }

    private var previewSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ZStack(alignment: .topLeading) {
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
                            cardBackgroundImagePath: nil,
                            cardBackgroundRemoteURL: nil,
                            labelColorHex: labelHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : labelHex,
                            headerRightText: CardRewardsHeaderLink.displayText,
                            memberPreviewText: cardMemberPreviewText,
                            memberColumnTitle: previewMemberColumnTitle,
                            stampMidRewardLabel: stampMidRewardLabel,
                            stampRewardLabel: stampRewardLabel,
                            restantsCaption: labelRestants.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Restants" : labelRestants.trimmingCharacters(in: .whitespacesAndNewlines),
                            compact: false,
                            onEditZoneTap: handleCardPreviewZoneTap,
                            onCompletionPillTap: openCardCustomizationZone,
                            fidelityQRPayloadURL: fidelityCardPageURLString,
                            completionHighlightZones: (shouldShowCompletionPills && !cardLogoZoomFocused) ? cardCompletionPreviewZones : []
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
                            onEditZoneTap: handleCardPreviewZoneTap,
                            onCompletionPillTap: openCardCustomizationZone,
                            fidelityQRPayloadURL: fidelityCardPageURLString,
                            completionHighlightZones: (shouldShowCompletionPills && !cardLogoZoomFocused) ? cardCompletionPreviewZones : []
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .compositingGroup()
                .scaleEffect(cardLogoZoomScale, anchor: .topLeading)
                .offset(x: cardLogoZoomOffsetX, y: cardLogoZoomOffsetY)
            }
            .id(programType)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(minHeight: 220, alignment: .topLeading)
        }
        .padding(.top, AppTheme.Spacing.md)
        .padding(.bottom, AppTheme.Spacing.sm)
    }

    private func handleCardPreviewZoneTap(_ zone: CardPreviewEditZone) {
        if zone == .logoBand {
            if cardLogoZoomFocused, customizationZone == .logoBand {
                customizationZone = nil
                setCardLogoZoomFocused(false)
                return
            }
            openCardCustomizationZone(.logoBand)
            return
        }
        if cardLogoZoomFocused {
            setCardLogoZoomFocused(false)
        }
        openCardCustomizationZone(zone)
    }

    private func setCardLogoZoomFocused(_ focused: Bool) {
        guard cardLogoZoomFocused != focused else { return }
        cardLogoZoomFocused = focused
    }

    private func syncCardLogoZoomTransform(focused: Bool) {
        let animation = focused ? MerchantMotion.cardLogoZoomIn : MerchantMotion.cardLogoZoomOut
        withAnimation(animation) {
            cardLogoZoomScale = focused ? 1.75 : 1
            cardLogoZoomOffsetX = focused ? 16 : 0
            cardLogoZoomOffsetY = focused ? 4 : 0
        }
    }

    private func openCardCustomizationZone(_ zone: CardPreviewEditZone) {
        if zone == .qrCode {
            guard !businessSlug.isEmpty,
                  let url = LegalURLs.fidelityCardPage(slug: businessSlug) else { return }
            openURL(url)
            return
        }
        if zone == .backgroundImage && programType != "points" {
            return
        }
        if zone == .logoBand {
            setCardLogoZoomFocused(true)
        } else {
            setCardLogoZoomFocused(false)
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
            tierMinPurchases: $tierMinPurchases,
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
            stampMidRewardEnabled: $stampMidRewardEnabled,
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
                guard !businessSlug.isEmpty else { return }
                CardLogoStorage.removeLocalCardBackgroundFile(for: businessSlug)
                cardBackgroundImagePath = nil
                cardBackgroundPhotoItem = nil
                cardBackgroundRemoteURL = nil
                cardBackgroundWasRemoved = true
                persistDisplaySnapshot(slug: businessSlug)
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
                if !businessSlug.isEmpty {
                    persistDisplaySnapshot(slug: businessSlug)
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

            var slug: String? = businessSlug.isEmpty ? nil : businessSlug
            if slug == nil, AuthStorage.isLoggedIn {
                await syncService.syncIfNeeded()
                slug = businessSlug.isEmpty ? AuthStorage.currentBusinessSlug : businessSlug
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
                template: programType == "stamps" ? "cafe" : (isCafeDesArts ? "cafe" : nil),
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
            } catch let e as APIError where e.isHTTPResourceMissing {
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
        guard !businessSlug.isEmpty else { return }
        let path = CardLogoStorage.saveImage(image, slug: businessSlug)
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
            let bust = MerchantLogoAssetCache.stripeLogoDisplayURL(u, slug: businessSlug)
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
        guard !businessSlug.isEmpty else { return }
        let path = CardLogoStorage.saveCardBackground(image, slug: businessSlug)
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
            if !businessSlug.isEmpty {
                persistDisplaySnapshot(slug: businessSlug)
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

    /// Vide le brouillon en mémoire avant de charger le commerce courant (évite un flash logo/couleurs d’un autre compte).
    private func resetCardDraftStateForBusinessLoad() {
        displayName = ""
        logoURL = ""
        primaryHex = AppTheme.WalletCardAppearanceDefaults.backgroundHex
        accentHex = AppTheme.WalletCardAppearanceDefaults.bodyTextHex
        labelHex = AppTheme.WalletCardAppearanceDefaults.labelTitlesHex
        stripDisplayMode = "logo"
        stripText = ""
        stampEmoji = ""
        cardBackgroundImagePath = nil
        cardBackgroundRemoteURL = nil
        cardBackgroundWasRemoved = false
        stampIconPendingBase64 = nil
        stampIconWasRemoved = false
        serverHasStampIconAsset = false
        serverStampIconURLString = nil
        dashboardSettingsHydrated = false
        lastPersistedSnapshot = nil
        logoPhotoItem = nil
        cardBackgroundPhotoItem = nil
        stampIconPhotoItem = nil
    }

    private func loadCurrentTemplate() {
        guard !businessSlug.isEmpty else { return }
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
            if programType == "points" {
                previewPointsCount = 0
            } else {
                // Aperçu commerçant sans membre sync : garder des tampons « obtenus » démo (grille colorée).
                let cap = max(1, requiredStamps)
                previewStampsCount = min(3, cap)
            }
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
        syncProgramPickerWithCommitted()
        displayName = s.displayName.isEmpty ? displayName : s.displayName
        primaryHex = s.primaryHex.isEmpty ? primaryHex : s.primaryHex
        accentHex = s.accentHex.isEmpty ? accentHex : s.accentHex
        labelHex = s.labelHex
        stripDisplayMode = s.stripDisplayMode
        if stripDisplayMode != "text" { stripDisplayMode = "logo" }
        stripText = s.stripText
        if restoreLogoFromSnapshot {
            let snapLogo = s.logoURL.trimmingCharacters(in: .whitespacesAndNewlines)
            if snapLogo.isEmpty {
                logoURL = ""
            } else if CardLogoStorage.isLocalPendingLogoReference(snapLogo) {
                logoURL = CardLogoStorage.belongsToBusiness(snapLogo, slug: businessSlug) ? snapLogo : ""
            } else {
                logoURL = snapLogo
            }
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
        if programType == "points" {
            MyCardProgramDefaults.sanitizeEditableTierSlots(tierPoints: &tierPoints, tierLabels: &tierLabels)
        }
        let localBG = !(cardBackgroundImagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if !localBG {
            // Restaurer le fichier local si le snapshot indique qu'il existe sur disque.
            if s.hasLocalCardBackground == true,
               let rel = CardLogoStorage.localCardBackgroundPathIfExists(for: businessSlug) {
                cardBackgroundImagePath = rel
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
        guard !businessSlug.isEmpty,
              let snap = CardPreviewDisplaySnapshotStore.load(slug: businessSlug),
              snap.hasLocalCardBackground == true,
              cardBackgroundImagePath == nil else { return }
        if let rel = CardLogoStorage.localCardBackgroundPathIfExists(for: businessSlug) {
            cardBackgroundImagePath = rel
        }
    }

    private func mergeStampIconFromDisplaySnapshotIfNeeded() {
        guard !businessSlug.isEmpty,
              let snap = CardPreviewDisplaySnapshotStore.load(slug: businessSlug) else { return }
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
        let hasRemoteBG = !cardBackgroundWasRemoved
            && cardBackgroundRemoteURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasLocalBG = !cardBackgroundWasRemoved
            && !(cardBackgroundImagePath ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            hasRemoteCardBackground: hasRemoteBG,
            cardBackgroundRemoteURL: hasRemoteBG ? cardBackgroundRemoteURL : nil,
            hasLocalCardBackground: hasLocalBG,
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
        if !businessSlug.isEmpty {
            persistDisplaySnapshot(slug: businessSlug)
        }
    }

    private func prefetchCardMediaURLs(logoURLString: String, backgroundURLString: String?, stampIconURLString: String? = nil) async {
        await AuthenticatedMediaLoader.prefetchCardAssets(
            logoURLString: logoURLString,
            backgroundURLString: backgroundURLString,
            stampIconURLString: stampIconURLString
        )
    }

    private func prefetchCardMediaFromCurrentState() async {
        await prefetchCardMediaURLs(logoURLString: logoURL, backgroundURLString: cardBackgroundRemoteURL, stampIconURLString: serverStampIconURLString)
    }

    /// Charge les réglages complets depuis l’API (design + règles) pour que l’aperçu et le pass « Tester dans l’Apple Wallet » reflètent les changements faits sur le SaaS ou ailleurs.
    /// - Parameter respectingUnsavedEdits: si `true`, n’écrase pas un brouillon local non enregistré.
    private func loadCardSettingsFromAPI(respectingUnsavedEdits: Bool = true) async {
        let slug = businessSlug
        guard !slug.isEmpty else { return }
        if respectingUnsavedEdits, hasUnsavedCardChanges { return }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings, slug: slug)
            await MainActor.run {
                if respectingUnsavedEdits, hasUnsavedCardChanges { return }
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
                syncProgramPickerWithCommitted()
                if programType == "stamps", let rs = settings.requiredStamps, rs > 0 {
                    requiredStamps = rs
                }
                pointsPerEuro = settings.pointsPerEuro ?? 1
                pointsPerVisit = settings.pointsPerVisit ?? 0
                pointsMinAmountEur = settings.pointsMinAmountEur.map { String(format: "%.2f", $0) } ?? ""
                if let tiers = settings.pointsRewardTiers, !tiers.isEmpty {
                    let split = MyCardProgramDefaults.splitPointsTiersFromAPI(
                        tiers,
                        apiStartGameLabel: settings.startGameRewardLabel
                    )
                    startGameRewardLabel = split.startGameRewardLabel
                    tierPoints = split.tierPoints
                    tierLabels = split.tierLabels
                    tierMinPurchases = split.tierMinPurchases
                    if programType == "points" {
                        MyCardProgramDefaults.sanitizeEditableTierSlots(tierPoints: &tierPoints, tierLabels: &tierLabels)
                        MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                            startGameRewardLabel: &startGameRewardLabel,
                            tierPoints: tierPoints,
                            tierLabels: tierLabels
                        )
                    }
                } else {
                    tierPoints = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
                    tierLabels = Array(repeating: "", count: MyCardPointsRewardTiers.slotCount)
                    if programType == "points" {
                        MyCardProgramDefaults.ensureTierArraysCapacity(tierPoints: &tierPoints, tierLabels: &tierLabels)
                    }
                    let apiStart = settings.startGameRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !apiStart.isEmpty {
                        startGameRewardLabel = apiStart
                        if programType == "points", !tierLabels.isEmpty {
                            tierLabels[0] = apiStart
                        }
                    } else {
                        startGameRewardLabel = ""
                    }
                }
                stampRewardLabel = settings.stampRewardLabel ?? ""
                let midSaved = settings.stampMidRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                stampMidRewardLabel = midSaved
                stampMidRewardEnabled = requiredStamps > 5 && !midSaved.isEmpty
                let startSaved = settings.startGameRewardLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if programType == "stamps", !startSaved.isEmpty {
                    startGameRewardLabel = startSaved
                }
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
                let localLogoRel = CardLogoStorage.localLogoPathIfExists(for: slug)
                if CardLogoStorage.isLocalPendingLogoReference(currentLogo, slug: slug) {
                    if localLogoRel == nil {
                        logoURL = apiLogo
                    }
                } else if !apiLogo.isEmpty {
                    let localUploadAt = MerchantMediaUploadOwnership.lastLogoUploadDate(for: slug)
                    if localUploadAt != nil, let localRel = localLogoRel {
                        var serverIsNewer = false
                        if let serverAtStr = settings.logoUpdatedAt?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !serverAtStr.isEmpty,
                           let serverAt = ISO8601DateFormatter().date(from: serverAtStr) {
                            serverIsNewer = serverAt > localUploadAt!
                        }
                        logoURL = serverIsNewer ? apiLogo : localRel
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
                } else if !cardBackgroundWasRemoved {
                    let localRel = cardBackgroundImagePath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasLocal = !localRel.isEmpty
                        || CardLogoStorage.localCardBackgroundPathIfExists(for: slug) != nil
                    if !hasLocal {
                        cardBackgroundRemoteURL = nil
                    }
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
            stampMidRewardEnabled: stampMidRewardEnabled,
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

    /// Enregistre uniquement les récompenses (feuille « Récompenses ») — toutes obligatoires, y compris « Début du jeu ».
    @discardableResult
    private func saveRewardsOnly() async -> Bool {
        guard rewardsConfigurationComplete else {
            await MainActor.run {
                saveLogoError = "Renseignez toutes les récompenses, y compris « Début du jeu »."
            }
            return false
        }
        guard !businessSlug.isEmpty else {
            await MainActor.run { capturePersistedBaseline() }
            return true
        }
        let slug = businessSlug

        var patch = FullDashboardSettingsPatch()
        patch.welcomeBonusEnabled = 1
        patch.welcomeBonusAmount = programType == "stamps" ? 1 : 10
        patch.programType = programType
        MyCardProgramDefaults.ensureStartGameRewardLabel(&startGameRewardLabel)
        patch.startGameRewardLabel = String(startGameRewardLabel.prefix(120))

        if programType == "points" {
            MyCardProgramDefaults.ensureTierArraysCapacity(tierPoints: &tierPoints, tierLabels: &tierLabels)
            MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                startGameRewardLabel: &startGameRewardLabel,
                tierPoints: tierPoints,
                tierLabels: tierLabels
            )
            patch.pointsRewardTiers = MyCardProgramDefaults.buildPointsRewardTiersForAPI(
                startGameRewardLabel: startGameRewardLabel,
                tierPoints: tierPoints,
                tierLabels: tierLabels,
                tierMinPurchases: tierMinPurchases
            )
            patch.loyaltyMode = "points_cash"
        } else {
            patch.requiredStamps = max(1, requiredStamps)
            patch.stampRewardLabel = stampRewardLabel.isEmpty
                ? nil
                : String(stampRewardLabel.prefix(120))
            if stampMidRewardEnabled, requiredStamps > 5 {
                let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespaces)
                patch.stampMidRewardLabel = mid.isEmpty ? nil : String(mid.prefix(120))
            } else {
                patch.stampMidRewardLabelIsExplicitNull = true
            }
            patch.loyaltyMode = "points_cash"
        }

        do {
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            await MainActor.run {
                saveLogoError = nil
                persistDisplaySnapshot(slug: slug)
                capturePersistedBaseline()
            }
            await loadCardSettingsFromAPI(respectingUnsavedEdits: true)
            return true
        } catch {
            await MainActor.run {
                saveLogoError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            return false
        }
    }

    /// Retourne `false` si l'envoi des réglages au serveur a échoué (réseau, validation, etc.).
    /// - Parameter skipPostSaveReload: si `true`, pas de `GET dashboard/settings` après succès (ex. flux Apple Wallet : évite un aller-retour réseau inutile).
    @discardableResult
    private func saveTemplate(skipPostSaveReload: Bool = false) async -> Bool {
        let previousCommittedProgramType = lastPersistedSnapshot?.programType
        let willSwitchProgramType = programTypeSwitchAwaitingSave
            || (previousCommittedProgramType.map { $0 != programType } ?? false)
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

        guard !businessSlug.isEmpty else {
            await MainActor.run { capturePersistedBaseline() }
            return true
        }
        let slug = businessSlug
        let (cardBackgroundBase64, logoBase64, logoUrl) = await prepareDashboardMediaPayloadsForSave(
            cardBackgroundWasRemoved: cardBackgroundWasRemoved,
            cardBackgroundImagePath: cardBackgroundImagePath,
            logoURL: logoURL
        )
        var rewardTiers: [PointsRewardTierPayload]? = nil
        if programType == "points" {
            MyCardProgramDefaults.ensureTierArraysCapacity(tierPoints: &tierPoints, tierLabels: &tierLabels)
            MyCardProgramDefaults.syncStartGameLabelFromFirstTier(
                startGameRewardLabel: &startGameRewardLabel,
                tierPoints: tierPoints,
                tierLabels: tierLabels
            )
            rewardTiers = MyCardProgramDefaults.buildPointsRewardTiersForAPI(
                startGameRewardLabel: startGameRewardLabel,
                tierPoints: tierPoints,
                tierLabels: tierLabels,
                tierMinPurchases: tierMinPurchases
            )
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
                // Tampons : ne pas toucher au fond points ni aux paliers en base (masqués côté pass / aperçu).
                if programType == "points" {
                    if cardBackgroundWasRemoved {
                        patch.cardBackgroundBase64 = ""
                    } else if let bg = cardBackgroundBase64 {
                        patch.cardBackgroundBase64 = bg
                    }
                }
                patch.programType = programType
                patch.pointsPerEuro = programType == "points" ? pointsPerEuro : nil
                patch.pointsPerVisit = programType == "points" ? pointsPerVisit : nil
                patch.pointsMinAmountEur = programType == "points" ? ptsMinEur : nil
                if programType == "points" {
                    patch.pointsRewardTiers = rewardTiers
                    patch.loyaltyMode = "points_cash"
                } else {
                    patch.loyaltyMode = "points_cash"
                }
                patch.stampRewardLabel = stampRewardLabel.isEmpty ? nil : String(stampRewardLabel.prefix(120))
                patch.welcomeBonusEnabled = 1
                patch.welcomeBonusAmount = programType == "stamps" ? 1 : 10
                MyCardProgramDefaults.ensureStartGameRewardLabel(&startGameRewardLabel)
                patch.startGameRewardLabel = String(startGameRewardLabel.prefix(120))
                if programType == "stamps" {
                    if stampMidRewardEnabled, requiredStamps > 5 {
                        let mid = stampMidRewardLabel.trimmingCharacters(in: .whitespaces)
                        patch.stampMidRewardLabel = mid.isEmpty ? nil : String(mid.prefix(120))
                    } else {
                        patch.stampMidRewardLabelIsExplicitNull = true
                    }
                }
                patch.sector = sectorVal.isEmpty ? nil : String(sectorVal.prefix(64))
                patch.stripColor = bgHex
                patch.stripDisplayMode = "logo"
                patch.stripText = ""
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
                    if willSwitchProgramType {
                        programTypeSwitchAwaitingSave = false
                        NotificationCenter.default.post(name: .myfidpassProgramModeDidSwitch, object: nil)
                    }
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
                        if !businessSlug.isEmpty {
                            persistDisplaySnapshot(slug: businessSlug)
                        }
                        syncPreviewBalancesFromSyncedMembers()
                        capturePersistedBaseline()
                    }
                } else {
                    await loadCardSettingsFromAPI(respectingUnsavedEdits: false)
                    // `loadCardSettingsFromAPI` met déjà à jour l’aperçu + `syncPreviewBalancesFromSyncedMembers`.
                }
                if willSwitchProgramType {
                    await syncService.syncAfterServerMutation()
                    await MainActor.run {
                        NotificationCenter.default.post(name: .myfidpassProgramModeDidSwitch, object: nil)
                    }
                } else {
                    Task(priority: .utility) { await syncService.syncAfterServerMutation() }
                }
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
                    MerchantMediaUploadOwnership.recordLogoUpload(for: slug)
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

    /// Mis en attente jusqu’à l’onglet **Accueil** — voir `DashboardView` (`PostCardFlyerPromoEligibility`).
    private func schedulePostCardFlyerPromoIfEligible() {
        guard !businessSlug.isEmpty else { return }
        guard PostCardFlyerPromoEligibility.stillNeedsFlyerPromo(for: businessSlug) else { return }
        PostCardFlyerPromoEligibility.queuePresentationOnMerchantHome(for: businessSlug)
    }

    private func triggerSavedFeedback() {
        MerchantUXFeedback.shared.play(.save)
    }
}

// MARK: - Feuille personnalisation (conteneur léger pour le type-checker Swift)

private struct MyCardCustomizationSheetContainer: View {
    let zone: CardPreviewEditZone
    let pack: CardCustomizationBindPack
    let actions: CardCustomizationActions
    let cardImageSuggestedColors: [String]
    let dashboardSettingsHydrated: Bool
    let canSaveRewards: Bool
    let rewardsSaveInFlight: Bool
    let hasUnsavedCardChanges: Bool
    let onHeaderRightSave: () async -> Bool
    let onCropComplete: (UIImage, ImageCropSpec) async -> Void
    let refreshSuggestedColors: () async -> Void
    let reloadWalletPassBackSettings: () async -> Void

    var body: some View {
        CardElementCustomizationSheet(
            zone: zone,
            pack: pack,
            actions: actions,
            cardImageSuggestedColors: cardImageSuggestedColors,
            dashboardSettingsHydrated: dashboardSettingsHydrated,
            onSaveRewards: zone == .headerRight ? onHeaderRightSave : nil,
            canSaveRewards: canSaveRewards,
            rewardsSaveInFlight: rewardsSaveInFlight,
            onCropComplete: onCropComplete
        )
        .task(id: zone.id) {
            await refreshSuggestedColors()
            if zone == .walletPassBack, !hasUnsavedCardChanges {
                await reloadWalletPassBackSettings()
            }
        }
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
