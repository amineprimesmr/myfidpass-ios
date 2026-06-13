//
//  CampaignNotificationsView.swift
//  myfidpass
//
//  Hub campagnes Wallet : automatisations (familles), envoi segmenté depuis l’aperçu, aperçu notification.
//

import SwiftUI
import PhotosUI
import UIKit
import CoreData
import Foundation
import MapKit
import CoreLocation

// MARK: - Catalogue (aligné backend `campaign-automation-cron.js` — segments produit simplifiés)

private struct CampaignRuleSpec: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    /// Clé `GET .../campaign-segments` pour afficher l’effectif.
    let segmentKey: String?
    /// Titre court dans l’aperçu type notification (sinon `title`).
    var notificationPreviewTitle: String? = nil
    /// Texte sous l’aperçu : **ce que vit le client** (pas la mécanique serveur).
    var timingCaption: String? = nil

    var effectiveNotificationPreviewTitle: String {
        let t = notificationPreviewTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? title : t
    }
}

private struct CampaignFamilySpec: Identifiable {
    let id: String
    let title: String
    let icon: String
    let rules: [CampaignRuleSpec]
}

// MARK: - Aperçu notification — Liquid Glass, lecture + bouton Modifier

private enum WalletNotificationPreviewSize {
    case standard
    case carousel

    var iconSide: CGFloat {
        switch self {
        case .standard: 40
        case .carousel: 52
        }
    }

    var iconCorner: CGFloat {
        switch self {
        case .standard: 10
        case .carousel: 12
        }
    }

    var titleFont: Font {
        switch self {
        case .standard: .footnote.weight(.semibold)
        case .carousel: .subheadline.weight(.semibold)
        }
    }

    var bodyFont: Font {
        switch self {
        case .standard: .footnote.weight(.regular)
        case .carousel: .body.weight(.regular)
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .standard: 12
        case .carousel: 16
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .standard: 14
        case .carousel: 16
        }
    }

    var glassCornerRadius: CGFloat {
        switch self {
        case .standard: 22
        case .carousel: 24
        }
    }

    var editIconSize: CGFloat {
        switch self {
        case .standard: 20
        case .carousel: 22
        }
    }

    var rowSpacing: CGFloat {
        switch self {
        case .standard: 12
        case .carousel: 14
        }
    }

    var textStackSpacing: CGFloat {
        switch self {
        case .standard: 3
        case .carousel: 5
        }
    }
}

private struct WalletNotificationPreviewBlock<Footer: View>: View {
    var logoURL: String? = nil
    let notificationTitle: String
    @Binding var messageText: String
    var messagePlaceholder: String = "Message sur le pass"
    var maxLength: Int = 200
    var previewSize: WalletNotificationPreviewSize = .standard
    var lightGlassSurface: Bool = false
    var onMessageEditingChanged: ((Bool) -> Void)? = nil
    @ViewBuilder private let footer: () -> Footer

    @FocusState private var messageFocused: Bool

    init(
        logoURL: String? = nil,
        notificationTitle: String,
        messageText: Binding<String>,
        messagePlaceholder: String = "Message sur le pass",
        maxLength: Int = 200,
        previewSize: WalletNotificationPreviewSize = .standard,
        lightGlassSurface: Bool = false,
        onMessageEditingChanged: ((Bool) -> Void)? = nil,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.logoURL = logoURL
        self.notificationTitle = notificationTitle
        self._messageText = messageText
        self.messagePlaceholder = messagePlaceholder
        self.maxLength = maxLength
        self.previewSize = previewSize
        self.lightGlassSurface = lightGlassSurface
        self.onMessageEditingChanged = onMessageEditingChanged
        self.footer = footer
    }

    private var titleTextColor: Color { lightGlassSurface ? .white : .black }
    private var bodyTextColor: Color { lightGlassSurface ? Color.white.opacity(0.92) : Color.black.opacity(0.92) }
    private var placeholderTextColor: Color { lightGlassSurface ? Color.white.opacity(0.42) : Color.black.opacity(0.38) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: previewSize.rowSpacing) {
                previewIcon
                VStack(alignment: .leading, spacing: previewSize.textStackSpacing) {
                    Text(notificationTitle)
                        .font(previewSize.titleFont)
                        .foregroundStyle(titleTextColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    TextField(messagePlaceholder, text: cappedMessageBinding, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(previewSize.bodyFont)
                        .foregroundStyle(bodyTextColor)
                        .tint(lightGlassSurface ? .white : AppTheme.Colors.primary)
                        .lineLimit(3 ... 10)
                        .multilineTextAlignment(.leading)
                        .focused($messageFocused)
                        .submitLabel(.done)
                        .onSubmit { dismissMessageEditing() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, previewSize.verticalPadding)
            .padding(.horizontal, previewSize.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .walletNotificationPreviewSurface(previewSize: previewSize, lightGlass: lightGlassSurface)
            .walletPreviewColorScheme(lightGlass: lightGlassSurface)

            footer()
        }
        .onChange(of: messageFocused) { _, focused in
            onMessageEditingChanged?(focused)
        }
        .onDisappear {
            onMessageEditingChanged?(false)
        }
    }

    private func dismissMessageEditing() {
        messageFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var cappedMessageBinding: Binding<String> {
        Binding(
            get: { messageText },
            set: { messageText = String($0.prefix(maxLength)) }
        )
    }

    @ViewBuilder
    private var previewIcon: some View {
        if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            BusinessLogoView(
                logoURL: raw,
                logoAssetContext: .campaignNotificationIcon,
                size: previewSize.iconSide,
                cornerRadius: previewSize.iconCorner
            )
        } else {
            Image("logonotif")
                .resizable()
                .scaledToFill()
                .frame(width: previewSize.iconSide, height: previewSize.iconSide)
                .clipShape(RoundedRectangle(cornerRadius: previewSize.iconCorner, style: .continuous))
        }
    }
}

private extension WalletNotificationPreviewBlock where Footer == EmptyView {
    init(
        logoURL: String? = nil,
        notificationTitle: String,
        messageText: Binding<String>,
        messagePlaceholder: String = "Message sur le pass",
        maxLength: Int = 200,
        previewSize: WalletNotificationPreviewSize = .standard,
        lightGlassSurface: Bool = false,
        onMessageEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.init(
            logoURL: logoURL,
            notificationTitle: notificationTitle,
            messageText: messageText,
            messagePlaceholder: messagePlaceholder,
            maxLength: maxLength,
            previewSize: previewSize,
            lightGlassSurface: lightGlassSurface,
            onMessageEditingChanged: onMessageEditingChanged,
            footer: { EmptyView() }
        )
    }
}

/// Périmètre Wallet — seule automatisation conservée côté produit.
private let automationHubRules: [CampaignRuleSpec] = [
    CampaignRuleSpec(
        id: "locationEntry",
        title: "Entrée dans le périmètre",
        subtitle: "Message lié à la géolocalisation Wallet.",
        segmentKey: nil,
        notificationPreviewTitle: "Vous êtes tout près",
        timingCaption:
            "Le client voit ce message en passant près du magasin avec sa carte dans Apple Wallet."
    ),
]

/// Message par défaut périmètre (`locationEntry`).
private let defaultAutomationRuleMessages: [String: String] = [
    "locationEntry": "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête.",
]

/// Ne conserve que le périmètre Wallet (`locationEntry`) — plus d’automatisations campagne.
private func campaignAutomationSanitizedForServer(_ config: CampaignAutomationConfigDTO) -> CampaignAutomationConfigDTO {
    let loc = config.rules?["locationEntry"]
    var rules: [String: CampaignAutomationRuleDTO] = [:]
    if let loc {
        rules["locationEntry"] = loc
    }
    return CampaignAutomationConfigDTO(
        version: config.version,
        globalCooldownDays: config.globalCooldownDays,
        rules: rules
    )
}

/// Force `enabled: false` sur toutes les règles tant qu’aucune icône notif personnalisée n’est configurée.
private func campaignAutomationGatedForIcon(
    _ config: CampaignAutomationConfigDTO,
    hasCustomIcon: Bool
) -> CampaignAutomationConfigDTO {
    guard hasCustomIcon else {
        var rules = config.rules ?? [:]
        for key in rules.keys {
            var row = rules[key] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
            row.enabled = false
            rules[key] = row
        }
        return CampaignAutomationConfigDTO(
            version: config.version,
            globalCooldownDays: config.globalCooldownDays,
            rules: rules
        )
    }
    return config
}

private func mergedAutomation(from api: CampaignAutomationConfigDTO?) -> CampaignAutomationConfigDTO {
    let defMsg = defaultAutomationRuleMessages["locationEntry"] ?? ""
    let existing = api?.rules?["locationEntry"]
    let locRule = CampaignAutomationRuleDTO(
        enabled: existing?.enabled ?? false,
        message: (existing?.message?.isEmpty == false ? existing?.message : defMsg) ?? defMsg
    )
    let cd = api?.globalCooldownDays ?? 7
    return CampaignAutomationConfigDTO(
        version: api?.version ?? 1,
        globalCooldownDays: min(90, max(1, cd)),
        rules: ["locationEntry": locRule]
    )
}

// MARK: - Barre de progression envoi (bandeau tout en haut — `progress` suit les étapes réelles de `send()`)

private struct NotificationSendTopProgressStrip: View {
    var progress: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let p = max(0, min(1, progress))
            let fillW = max(0, p * w)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.22))
                    .frame(height: 6)

                if fillW > 0.5 {
                    Capsule(style: .continuous)
                        .fill(Color.white)
                        .frame(width: fillW, height: 6)
                        .shadow(color: Color.white.opacity(0.45), radius: 8, x: 0, y: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 18)
        .accessibilityLabel("Progression d’envoi de la notification")
        .accessibilityValue("\(Int((max(0, min(1, progress))) * 100)) pour cent")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Vue principale

struct CampaignNotificationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var dataService: DataService
    @EnvironmentObject private var memberSearchCoordinator: MerchantMemberSearchCoordinator

    @State private var searchPresentedMemberOID: NSManagedObjectID?
    @State private var title = ""
    @State private var bodyText = ""
    @State private var segment: String?
    @State private var segments: CampaignSegmentsResponse?
    @State private var dashboardSettings: BusinessSettingsResponse?
    @State private var campaignAutomation: CampaignAutomationConfigDTO = mergedAutomation(from: nil)
    @State private var errorMessage: String?
    @State private var successFeedback: String?

    @State private var isLoadingData = false
    @State private var isLoadingCampaignDataInFlight = false
    @State private var lastCampaignDataLoadAt: Date?
    @State private var loadError: String?
    @State private var isSending = false
    /// 0…1 : avancement réel des étapes dans `send()` (barre blanche en tête de page).
    @State private var notificationSendProgress: CGFloat = 0
    @State private var isNotificationSendInFlight = false
    /// Nombre de destinataires du dernier envoi réussi — affiché brièvement dans le bouton avant de vider le champ.
    @State private var sendSuccessCount: Int? = nil
    /// Après envoi manuel, garder le champ vide même si le serveur renvoie encore l'ancien message.
    @State private var keepManualMessageFieldClearedAfterSend = false
    @State private var isApplyingRemoteSettings = false
    @State private var bannerTextsAutoSaveTask: Task<Void, Never>?
    @State private var campaignAutomationSaveTask: Task<Void, Never>?
    /// Timestamp local pour éviter les rechargements serveur pendant une édition automatique.
    @State private var lastAutomationLocalEditAt: Date?
    /// Message **périmètre / géolocalisation** (`location_relevant_text`) — distinct du message **manuel** (`bodyText`).
    @State private var perimeterRelevantMessageText = ""
    @State private var perimeterRelevantTextSaveTask: Task<Void, Never>?
    /// Empêche les reload distants d'écraser la saisie locale tant qu'elle n'est pas persistée.
    @State private var isPerimeterRelevantTextDirty = false
    @State private var isPerimeterMessageEditing = false
    @State private var notificationsKeyboardOverlap: CGFloat = 0
    @State private var notificationIconPhotoItem: PhotosPickerItem?
    @State private var notificationIconCropPayload: ImageCropPayload?
    @State private var isUploadingNotificationIcon = false
    /// Même URL `…/notification-icon` après upload : recréer les vues image + appliquer le nouveau `?v=`.
    @State private var notificationIconReloadNonce = 0
    /// Une seule feuille à la fois (sinon iOS : « only presenting a single sheet is supported »).
    /// Même schéma que le popup « panier repère » sur la page Commerce (fond + carte centrée).
    @State private var notificationLogoPopupPresented = false
    @State private var notificationIconNudgeTask: Task<Void, Never>?
    @State private var notificationReadinessRows: [NotificationBusinessReadinessDTO] = []
    @State private var selectedNotificationSlugs: Set<String> = []
    @State private var isLoadingNotificationReadiness = false

    /// Envoi manuel de campagne : abo payant (sinon aperçu flouté + Déverrouiller avec Pro).
    private var campaignManualSendUnlocked: Bool {
        authService.merchantProInsightsUnlocked
    }

    @State private var lastCampaignDataSlug: String?
    @State private var scheduledCampaignDataReloadTask: Task<Void, Never>?

    private var businessDisplayName: String {
        let t = dataService.currentCardTemplate()
        let n = t?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !n.isEmpty { return n }
        let b = dataService.createOrGetCurrentBusiness()
        let bn = b.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return bn.isEmpty ? "Mon commerce" : bn
    }

    private var campaignNotificationPreviewIconURL: String? {
        guard let slug = resolveSlugForAPI() else { return nil }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return "\(base)/api/businesses/\(enc)/notification-icon"
    }

    /// Évite qu’`AsyncImage` réaffiche une PNG mise en cache avant le nouveau `?v=` (même URL de base).
    /// Purge **toutes** les variantes query-string (`?v=…`) pour ce path ; sinon un ancien `?v=T1` en cache
    /// pouvait persister et être réutilisé si la vue reconstituait brièvement l'ancienne URL (bug : l'app
    /// affichait encore l'ancienne image après changement).
    private func invalidateCachedGETNotificationIconResponses() {
        guard let raw = campaignNotificationPreviewIconURL,
              let u = APIResourceURL.resolved(from: raw) else { return }
        // 1) Variante sans query
        URLCache.shared.removeCachedResponse(for: URLRequest(url: u))
        // 2) Toutes les entrées de URLCache qui matchent ce host + path (variantes ?v=…)
        let targetHost = u.host?.lowercased()
        let targetPath = u.path
        guard let targetHost, !targetPath.isEmpty else { return }
        // `URLCache` ne fournit pas de liste : on s'appuie sur `removeAllCachedResponses` si la ville
        // tampon est petite. En pratique la purge globale pour l'aperçu campagne est sûre : les autres
        // assets sont revalidés par ETag et restent fonctionnels.
        // (Tracer uniquement en debug pour éviter le bruit en prod.)
        #if DEBUG
        print("[notif-icon] Purge URLCache.shared pour host=\(targetHost) path=\(targetPath)")
        #endif
        if var components = URLComponents(url: u, resolvingAgainstBaseURL: false) {
            if let version = dashboardSettings?.notificationIconUpdatedAt?
                .trimmingCharacters(in: .whitespacesAndNewlines), !version.isEmpty {
                components.queryItems = [URLQueryItem(name: "v", value: version)]
                if let versioned = components.url {
                    URLCache.shared.removeCachedResponse(for: URLRequest(url: versioned))
                }
            }
        }
    }

    private var bannerFieldPromptFallback: String {
        defaultManualNotificationTitle
    }

    /// Titre par défaut des notifications manuelles = nom du commerce affiché au client.
    private var defaultManualNotificationTitle: String {
        let o = dashboardSettings?.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !o.isEmpty { return o }
        return businessDisplayName
    }

    /// Tant qu’aucune icône notif personnalisée n’est définie, on force le fallback local `logonotif`
    /// (évite le repli serveur vers un visuel vert générique).
    private var hasCustomNotificationIconFromSettings: Bool {
        let t = dashboardSettings?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !t.isEmpty
    }

    @MainActor
    private func requireNotificationIconForSending(presentPopup: Bool = true) -> Bool {
        guard hasCustomNotificationIconFromSettings else {
            if presentPopup {
                notificationLogoPopupPresented = true
            }
            return false
        }
        return true
    }

    private var notificationPreviewIconURLForView: String? {
        guard hasCustomNotificationIconFromSettings else { return nil }
        return campaignNotificationPreviewIconURL
    }

    /// Titre expéditeur (comme la bannière campagne du haut).
    private var effectiveCampaignNotificationSenderLine: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? bannerFieldPromptFallback : t
    }

    private func resolveSlugForAPI() -> String? {
        if let s = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        if let s = dataService.currentBusiness()?.slug?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            return s
        }
        return nil
    }

    private var activeSlugForViewChange: String {
        resolveSlugForAPI() ?? ""
    }

    /// Bandeau progression envoi — hauteur additionnelle sous la barre titre (ne pas masquer les coins du panneau).
    private var campaignNotificationsSendStripInset: CGFloat {
        isSending ? 22 : 0
    }

    /// Segments manuels (envoi immédiat) — clés API (`CAMPAIGN_SEGMENT_KEYS` côté serveur).
    private var manualSegmentChoices: [(key: String, label: String)] {
        [
            ("inactive14", "Client inactif +14 jours"),
            ("recurrent", "Clients fidèles (+10 visites par mois)"),
        ]
    }

    private var defaultMessages: [String: String] {
        [
            "inactive14": "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %.",
            "recurrent": "Offre pour nos clients les plus assidus ce mois-ci.",
        ]
    }

    var body: some View {
        campaignNotificationsWithPresentations
    }

    /// Découpe du `body` pour éviter l’erreur « unable to type-check in reasonable time ».
    private var campaignNotificationsScrollStack: some View {
        ZStack {
            if resolveSlugForAPI() != nil {
                notificationsFullPageMapBackground
            } else {
                Color(uiColor: .systemBackground)
            }

            Group {
                if memberSearchCoordinator.isActive {
                    ScrollView {
                        MerchantMemberSearchInlineSection { oid in
                            searchPresentedMemberOID = oid
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.top, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    notificationsMapForegroundLayout
                }
            }
        }
        .animation(MerchantMotion.searchBarMorph, value: memberSearchCoordinator.isActive)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            notificationsKeyboardOverlap = resolveNotificationsKeyboardOverlap(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            notificationsKeyboardOverlap = 0
        }
    }

    /// Carte plein écran (fond de page, lecture seule).
    private var notificationsFullPageMapBackground: some View {
        LocalAutomationReliefMapBackdrop(
            latitude: dashboardSettings?.locationLat,
            longitude: dashboardSettings?.locationLng,
            radiusMeters: dashboardSettings?.locationRadiusMeters,
            isLiveElevationMapActive: true
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var notificationsMapForegroundLayout: some View {
        ZStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                    previewSection
                        .padding(.top, 12)
                    if resolveSlugForAPI() == nil {
                        syncRequiredCard
                            .padding(.horizontal, AppTheme.Spacing.md)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if resolveSlugForAPI() != nil {
                    perimeterNotificationSimpleFooter
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, 8)
                        .padding(.bottom, notificationsPerimeterBottomInset)
                }
            }
            .blur(radius: campaignManualSendUnlocked ? 0 : 10)
            .allowsHitTesting(campaignManualSendUnlocked)

            if !campaignManualSendUnlocked {
                Color.black.opacity(0.14)
                    .allowsHitTesting(false)
                MerchantProUnlockTeaserButton(
                    unlockTitle: "Débloquer les notifications illimitées avec Pro"
                ) {
                    NotificationCenter.default.postOpenMerchantSubscriptionFromSession(
                        usedBusinesses: authService.usedBusinesses,
                        allowedBusinesses: authService.allowedBusinesses,
                        hasActiveSubscription: authService.hasEncashedMerchantSubscription
                    )
                }
                .padding(.horizontal, 24)
                .accessibilityLabel("Débloquer les notifications illimitées avec Pro")
                .accessibilityAddTraits(.isButton)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .animation(.easeOut(duration: 0.25), value: notificationsKeyboardOverlap)
        .animation(.easeOut(duration: 0.25), value: isPerimeterMessageEditing)
        .animation(.easeOut(duration: 0.25), value: campaignManualSendUnlocked)
    }

    private var notificationsTabBarClearance: CGFloat { 92 }

    /// Espace sous le bloc périmètre : tab bar seule, ou tab bar + pastille « Essayer 1 mois ».
    private var notificationsPerimeterBottomInset: CGFloat {
        if isPerimeterMessageEditing, notificationsKeyboardOverlap > 0 {
            return perimeterFooterKeyboardLift
        }
        guard !authService.hasEncashedMerchantSubscription else {
            return notificationsTabBarClearance
        }
        let subscribePillHeight: CGFloat = 48
        let gapAbovePill: CGFloat = 12
        return TabBarBottomClearance.stableFallback + subscribePillHeight + gapAbovePill
    }

    private var perimeterFooterKeyboardLift: CGFloat {
        guard isPerimeterMessageEditing, notificationsKeyboardOverlap > 0 else { return 0 }
        return notificationsKeyboardOverlap
    }

    private func resolveNotificationsKeyboardOverlap(from note: Notification) -> CGFloat {
        guard let value = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            return 0
        }
        let keyboardFrameInScreen = value.cgRectValue
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return max(0, UIScreen.main.bounds.maxY - keyboardFrameInScreen.minY)
        }
        let keyboardInWindow = window.convert(keyboardFrameInScreen, from: nil)
        return max(0, window.bounds.maxY - keyboardInWindow.minY)
    }

    private var campaignNotificationsWithLifecycle: some View {
        MerchantTabScaffold(
            panelBackground: .clear,
            extraPanelTopInset: campaignNotificationsSendStripInset,
            topBar: { campaignNotificationsTopChrome },
            panel: {
                campaignNotificationsScrollStack
            }
        )
        .overlay {
            if notificationLogoPopupPresented {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.9)) {
                            notificationLogoPopupPresented = false
                        }
                        scheduleNotificationIconNudgeIfNeeded()
                    }
                    .zIndex(28)

                NotificationManualLogoCommercePopupCard(
                    logoURL: notificationPreviewIconURLForView,
                    isUploadingNotificationIcon: isUploadingNotificationIcon,
                    notificationIconPhotoItem: $notificationIconPhotoItem
                )
                .frame(maxWidth: 430)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .transition(.scale(scale: 0.97).combined(with: .opacity))
                .zIndex(29)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: notificationLogoPopupPresented)
        .animation(.easeInOut(duration: 0.28), value: isSending)
        .toolbar(.hidden, for: .navigationBar)
        .merchantMemberSearchTabBinding { oid in
            searchPresentedMemberOID = oid
        }
        .sheet(isPresented: Binding(
            get: { searchPresentedMemberOID != nil },
            set: { if !$0 { searchPresentedMemberOID = nil } }
        )) {
            if let oid = searchPresentedMemberOID,
               let card = viewContext.object(with: oid) as? ClientCard {
                MemberDetailView(card: card, context: viewContext)
                    .environmentObject(syncService)
                    .environmentObject(dataService)
                    .memberDetailSheetChrome()
            }
        }
        .onAppear {
            scheduleNotificationIconNudgeIfNeeded()
        }
        .onChange(of: notificationLogoPopupPresented) { _, isOpen in
            if !isOpen, !hasCustomNotificationIconFromSettings {
                scheduleNotificationIconNudgeIfNeeded()
            }
        }
        .onChange(of: hasCustomNotificationIconFromSettings) { _, hasIcon in
            if hasIcon {
                cancelNotificationIconNudge()
                notificationLogoPopupPresented = false
            } else {
                scheduleNotificationIconNudgeIfNeeded()
            }
        }
        // Cold start : cet onglet est souvent monté hors écran par le TabView — ne pas lancer GET + états lourds
        // tant que l’utilisateur n’a pas ouvert « Campagnes » (évite blocage principal + warning navigation).
        .task(id: merchantTabIsActive) {
            guard merchantTabIsActive else { return }
            await Task.yield()
            await loadCampaignData()
        }
        .onChange(of: merchantTabIsActive) { _, active in
            if active {
                scheduleCampaignDataReload(force: false, debounceNs: 80_000_000)
            } else {
                scheduledCampaignDataReloadTask?.cancel()
                scheduledCampaignDataReloadTask = nil
                cancelNotificationIconNudge()
            }
        }
        .onChange(of: activeSlugForViewChange) { _, newSlug in
            guard merchantTabIsActive else { return }
            if let slug = resolveSlugForAPI(),
               let cached = ScanFlowSettingsCache.cached(for: slug) {
                CampaignNotificationImageCache.applyPreviewTimestamps(from: cached, slug: slug)
                dashboardSettings = cached
                prewarmNotificationIconIfPossible(slug: slug, settings: cached)
            } else {
                dashboardSettings = nil
            }
            let trimmed = newSlug.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if selectedNotificationSlugs.isEmpty || selectedNotificationSlugs.count == 1 {
                    selectedNotificationSlugs = [trimmed]
                } else {
                    selectedNotificationSlugs.insert(trimmed)
                }
            }
            segments = nil
            notificationIconReloadNonce &+= 1
            scheduleCampaignDataReload(force: true, debounceNs: 0)
            scheduleNotificationIconNudgeIfNeeded()
            Task { await loadNotificationReadiness() }
        }
        .onChange(of: syncService.lastSyncDate) { _, _ in
            guard merchantTabIsActive else { return }
            scheduleCampaignDataReload(force: false, debounceNs: 220_000_000)
        }
        .refreshable {
            await loadCampaignData()
        }
        .alert(merchantAlertTitle, isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage { Text(errorMessage) }
        }
        .alert("Campagne envoyée", isPresented: .init(get: { successFeedback != nil }, set: { if !$0 { successFeedback = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let successFeedback { Text(successFeedback) }
        }
        .onChange(of: notificationIconPhotoItem) { _, item in
            guard let item else { return }
            Task { await prepareNotificationIconCrop(from: item) }
        }
        .fullScreenCover(item: $notificationIconCropPayload) { payload in
            let spec = payload.spec
            ImageCropEditorView(
                spec: spec,
                sourceImage: payload.image,
                onCancel: { notificationIconCropPayload = nil },
                onComplete: { cropped in
                    notificationIconCropPayload = nil
                    Task { await uploadCroppedNotificationIcon(cropped) }
                }
            )
        }
        .onChange(of: title) { _, _ in
            guard !isApplyingRemoteSettings, !isNotificationSendInFlight else { return }
            scheduleBannerTextsAutoSave()
        }
        .onChange(of: bodyText) { _, _ in
            if !isApplyingRemoteSettings,
               !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                keepManualMessageFieldClearedAfterSend = false
            }
            guard !isApplyingRemoteSettings, !isNotificationSendInFlight else { return }
            scheduleBannerTextsAutoSave()
        }
        .onDisappear {
            notificationLogoPopupPresented = false
            cancelNotificationIconNudge()
            cancelPendingCampaignNotificationSaves()
            cancelPerimeterRelevantTextSaveTask()
            scheduledCampaignDataReloadTask?.cancel()
            scheduledCampaignDataReloadTask = nil
            Task {
                await flushBannerTextsAutoSave()
                await flushCampaignAutomationSave()
                await flushPerimeterRelevantTextSave()
            }
        }
    }

    private var campaignNotificationsWithPresentations: some View {
        campaignNotificationsWithLifecycle
    }

    private func cancelPendingCampaignNotificationSaves() {
        bannerTextsAutoSaveTask?.cancel()
        bannerTextsAutoSaveTask = nil
        campaignAutomationSaveTask?.cancel()
        campaignAutomationSaveTask = nil
    }

    private func scheduleCampaignDataReload(force: Bool, debounceNs: UInt64) {
        scheduledCampaignDataReloadTask?.cancel()
        scheduledCampaignDataReloadTask = Task {
            if debounceNs > 0 {
                try? await Task.sleep(nanoseconds: debounceNs)
            }
            guard !Task.isCancelled else { return }
            if shouldDeferCampaignDataReloadDuringEdit { return }
            await loadCampaignData(force: force)
        }
    }

    private func prewarmNotificationIconIfPossible(slug: String, settings: BusinessSettingsResponse?) {
        let raw = settings?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return }
        guard let resolved = APIResourceURL.resolved(from: raw) else { return }
        var components = URLComponents(url: resolved, resolvingAgainstBaseURL: false)
        if let d = CampaignNotificationImageCache.bestBustDate(for: slug) {
            components?.queryItems = [URLQueryItem(name: "v", value: String(Int64((d.timeIntervalSince1970 * 1000).rounded())))]
        }
        let displayURL = components?.url ?? resolved
        Task.detached(priority: .utility) {
            await AuthenticatedMediaLoader.prefetch(url: displayURL)
        }
    }

    private func cancelPerimeterRelevantTextSaveTask() {
        perimeterRelevantTextSaveTask?.cancel()
        perimeterRelevantTextSaveTask = nil
    }

    private func cancelNotificationIconNudge() {
        notificationIconNudgeTask?.cancel()
        notificationIconNudgeTask = nil
    }

    /// Après 3 s sur l’onglet : rappel si aucune icône personnalisée (tant que pas d’autre feuille modale).
    private func scheduleNotificationIconNudgeIfNeeded() {
        cancelNotificationIconNudge()
        notificationIconNudgeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            guard resolveSlugForAPI() != nil else { return }
            guard !hasCustomNotificationIconFromSettings else { return }
            guard notificationIconCropPayload == nil else { return }
            guard !isUploadingNotificationIcon else { return }
            guard !notificationLogoPopupPresented else { return }
            notificationLogoPopupPresented = true
        }
    }


    // MARK: - Sous-vues

    private var merchantAlertTitle: String { "Impossible de continuer" }

    private func assignMerchantAlertMessage(from error: Error) {
        guard let text = APIError.merchantFacingMessage(from: error) else { return }
        successFeedback = nil
        errorMessage = text
    }

    private var campaignNotificationsTopChrome: some View {
        VStack(spacing: 0) {
            if isSending {
                NotificationSendTopProgressStrip(progress: notificationSendProgress)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
            headerBlock
        }
    }

    private var headerBlock: some View {
        DashboardHomeMinimalTopBar(
            title: "Notifications",
            merchantName: notificationsTopBarTitle,
            accountEmail: authService.currentUserEmail ?? AuthStorage.userEmail,
            notificationIconURL: dashboardSettings?.notificationIconUrl,
            hasNotificationIcon: hasCustomNotificationIconFromSettings,
            businesses: authService.businessesForMerchantSwitcher,
            activeBusinessSlug: AuthStorage.currentBusinessSlug,
            canCreateBusiness: authService.isPlatformAdmin && !authService.adminShowsMerchantWorkspace
                ? false
                : authService.canCreateBusiness,
            isPlatformAdminAllCommercesMode: authService.isPlatformAdmin && !authService.adminShowsMerchantWorkspace,
            onBusinessSwitcherWillOpen: authService.isPlatformAdmin ? {
                Task { await authService.refreshPlatformAdminBusinesses(force: true) }
            } : nil,
            onOpenSideMenu: nil,
            onSelectBusiness: { slug in
                authService.selectBusiness(slug: slug)
                Task {
                    defer { authService.finishBusinessSwitch() }
                    await syncService.syncAfterServerMutation()
                    await loadCampaignData(force: true)
                }
            },
            onAddCommerce: {
                NotificationCenter.default.post(name: .myfidpassOpenAddCommerceSheet, object: nil)
            },
            onUpgradeCommerceQuota: {
                NotificationCenter.default.postOpenMerchantSubscription(
                    usedBusinesses: authService.usedBusinesses,
                    allowedBusinesses: authService.allowedBusinesses,
                    addingAnotherCommerce: true
                )
            }
        )
    }

    private var notificationsTopBarTitle: String {
        let businessName = dataService.currentBusiness()?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return businessName.isEmpty ? "Notifs" : businessName
    }

    private var showsMultiCommerceNotificationTargets: Bool {
        notificationReadinessRows.count > 1
    }

    private var multiCommerceTargetsSummaryLine: String {
        let selected = notificationReadinessRows.filter { row in
            guard let s = row.slug?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return false }
            return selectedNotificationSlugs.contains(s)
        }
        let devices = selected.reduce(0) { $0 + ($1.totalDevices ?? 0) }
        let readyCount = selected.filter { $0.ready == true }.count
        if selected.isEmpty { return "Aucun commerce sélectionné" }
        return "\(selected.count) commerce(s) · \(devices) appareil(s) · \(readyCount) prêt(s)"
    }

    private var multiCommerceNotificationTargetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupedSettingsSectionLabel("Commerces ciblés")
            Text("Chaque point de vente a sa propre icône notif et ses propres cartes Wallet enregistrées.")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if isLoadingNotificationReadiness {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.Colors.primary)
                } else {
                    multiCommerceTargetQuickAction("Tous") {
                        selectedNotificationSlugs = Set(
                            notificationReadinessRows.compactMap {
                                $0.slug?.trimmingCharacters(in: .whitespacesAndNewlines)
                            }.filter { !$0.isEmpty }
                        )
                    }
                    multiCommerceTargetQuickAction("Prêts") {
                        selectedNotificationSlugs = Set(
                            notificationReadinessRows.compactMap { row -> String? in
                                guard row.ready == true else { return nil }
                                let s = row.slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                                return s.isEmpty ? nil : s
                            }
                        )
                    }
                    if let active = resolveSlugForAPI() {
                        multiCommerceTargetQuickAction("Actif") {
                            selectedNotificationSlugs = [active]
                        }
                    }
                }
                Spacer(minLength: 0)
            }

            GroupedSettingsCard {
                ForEach(Array(notificationReadinessRows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 { GroupedSettingsRowDivider() }
                    multiCommerceNotificationTargetRow(row)
                }
            }

            Text(multiCommerceTargetsSummaryLine)
                .font(AppTheme.Fonts.caption2().weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.bottom, 6)
    }

    private func multiCommerceTargetQuickAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Fonts.caption2().weight(.semibold))
                .foregroundStyle(AppTheme.Colors.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppTheme.Colors.primary.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func multiCommerceNotificationTargetRow(_ row: NotificationBusinessReadinessDTO) -> some View {
        let slug = row.slug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isSelected = !slug.isEmpty && selectedNotificationSlugs.contains(slug)
        let ready = row.ready == true
        let isActive = slug == resolveSlugForAPI()

        Button {
            guard !slug.isEmpty else { return }
            if isSelected {
                if selectedNotificationSlugs.count > 1 {
                    selectedNotificationSlugs.remove(slug)
                }
            } else {
                selectedNotificationSlugs.insert(slug)
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary.opacity(0.45))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(row.displayName)
                            .font(AppTheme.Fonts.subheadline().weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                        if isActive {
                            Text("Actif")
                                .font(AppTheme.Fonts.caption2().weight(.bold))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppTheme.Colors.primary.opacity(0.12), in: Capsule())
                        }
                        Spacer(minLength: 0)
                        multiCommerceReadinessBadge(ready: ready, previewOnly: row.previewOnly == true)
                    }

                    if ready, row.previewOnly == true {
                        // Prêt pour l’auto-test mais 0 vrai client : message d’action, pas un faux « joignable ».
                        let hint = row.deliveryHint?.trimmingCharacters(in: .whitespacesAndNewlines)
                        Text(hint?.isEmpty == false
                            ? hint!
                            : "Aperçu seulement : partage le lien de ta carte pour que de vrais clients l’ajoutent à Apple Wallet.")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if ready {
                        let realClients = row.realClientDeviceCount
                        let deviceLine = "\(realClients) client(s) joignable(s)"
                        let memberLine = (row.membersCount ?? 0) > 0
                            ? " · \(row.membersCount ?? 0) client(s) enregistré(s)"
                            : ""
                        Text(deviceLine + memberLine)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.success)
                    } else if let hint = row.blockMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !hint.isEmpty {
                        Text(hint)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? AppTheme.Colors.primary.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(slug.isEmpty)
        .accessibilityLabel("\(row.displayName), \(ready ? "prêt" : "non prêt"), \(isSelected ? "sélectionné" : "non sélectionné")")
    }

    @ViewBuilder
    private func multiCommerceReadinessBadge(ready: Bool, previewOnly: Bool = false) -> some View {
        let label = !ready ? "À configurer" : (previewOnly ? "Aperçu" : "Prêt")
        let tint = (ready && !previewOnly) ? AppTheme.Colors.success : AppTheme.Colors.warning
        Text(label)
            .font(AppTheme.Fonts.caption2().weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if let err = loadError {
                errorCard(err)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            if showsMultiCommerceNotificationTargets {
                multiCommerceNotificationTargetsSection
            }
            BorderBeamManualNotificationComposerView(
                notificationTitle: $title,
                messageBody: $bodyText,
                segment: $segment,
                segmentChoices: manualSegmentChoices,
                defaultMessages: defaultMessages,
                keepManualMessageFieldClearedAfterSend: keepManualMessageFieldClearedAfterSend,
                hasSlug: resolveSlugForAPI() != nil,
                sendingLocked: !campaignManualSendUnlocked,
                isSending: isSending,
                isUploadingNotificationIcon: isUploadingNotificationIcon,
                sendSuccessCount: sendSuccessCount,
                onSend: { Task { await send() } }
            )
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.bottom, 2)
    }

    private var perimeterNotificationSimpleFooter: some View {
        WalletNotificationPreviewBlock(
            logoURL: notificationPreviewIconURLForView,
            notificationTitle: "Vous êtes tout près",
            messageText: Binding(
                get: { perimeterRelevantMessageText },
                set: { v in
                    perimeterRelevantMessageText = String(v.prefix(200))
                    isPerimeterRelevantTextDirty = true
                    var rsc = campaignAutomation.rules ?? [:]
                    var row = rsc["locationEntry"] ?? CampaignAutomationRuleDTO(
                        enabled: false,
                        message: defaultAutomationRuleMessages["locationEntry"] ?? ""
                    )
                    row.message = perimeterRelevantMessageText
                    if hasCustomNotificationIconFromSettings {
                        row.enabled = true
                    }
                    rsc["locationEntry"] = row
                    campaignAutomation.rules = rsc
                    schedulePerimeterRelevantTextSave()
                    scheduleCampaignAutomationSave()
                }
            ),
            messagePlaceholder: "Message à proximité du magasin…",
            maxLength: 200,
            previewSize: .standard,
            lightGlassSurface: true,
            onMessageEditingChanged: { isPerimeterMessageEditing = $0 }
        )
        .disabled(!hasCustomNotificationIconFromSettings)
    }

    private var syncRequiredCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aucun commerce synchronisé.")
                .font(AppTheme.Fonts.body())
            Button {
                Task {
                    await syncService.syncAfterServerMutation()
                    await loadCampaignData()
                }
            } label: {
                Label("Synchroniser", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
            .disabled(syncService.isSyncing)
        }
        .padding(AppTheme.Spacing.md)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    private func errorCard(_ err: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 8) {
                Text(err)
                    .font(AppTheme.Fonts.caption())
                Button("Réessayer") {
                    Task { await loadCampaignData() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    // MARK: - Persistance & réseau

    /// Court : titre / message campagne — tout est aussi flush avant « Envoyer » et au `onDisappear`.
    private static let bannerTextsAutoSaveDebounceNs: UInt64 = 380_000_000
    private static let campaignAutomationDebounceNs: UInt64 = 550_000_000
    private static let perimeterRelevantTextDebounceNs: UInt64 = 550_000_000

    private func scheduleCampaignAutomationSave() {
        guard resolveSlugForAPI() != nil else { return }
        lastAutomationLocalEditAt = Date()
        campaignAutomationSaveTask?.cancel()
        campaignAutomationSaveTask = Task {
            try? await Task.sleep(nanoseconds: Self.campaignAutomationDebounceNs)
            guard !Task.isCancelled else { return }
            await flushCampaignAutomationSave()
        }
    }

    @MainActor
    private func flushCampaignAutomationSave() async {
        campaignAutomationSaveTask?.cancel()
        campaignAutomationSaveTask = nil
        guard let slug = resolveSlugForAPI() else { return }
        if isNotificationSendInFlight { return }
        do {
            var patch = FullDashboardSettingsPatch()
            patch.campaignAutomation = campaignAutomationSanitizedForServer(
                campaignAutomationGatedForIcon(
                    campaignAutomation,
                    hasCustomIcon: hasCustomNotificationIconFromSettings
                )
            )
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
        } catch {
            // Sauvegarde auto : pas d’alerte bloquante (évite « The request timed out » au commerçant).
            _ = shouldSuppressCancelledNetworkNoise(error)
        }
    }

    private func schedulePerimeterRelevantTextSave() {
        guard resolveSlugForAPI() != nil else { return }
        perimeterRelevantTextSaveTask?.cancel()
        perimeterRelevantTextSaveTask = Task {
            try? await Task.sleep(nanoseconds: Self.perimeterRelevantTextDebounceNs)
            guard !Task.isCancelled else { return }
            await flushPerimeterRelevantTextSave()
        }
    }

    @MainActor
    private func flushPerimeterRelevantTextSave() async {
        perimeterRelevantTextSaveTask?.cancel()
        perimeterRelevantTextSaveTask = nil
        guard let slug = resolveSlugForAPI() else { return }
        if isNotificationSendInFlight { return }
        do {
            var patch = FullDashboardSettingsPatch()
            let t = perimeterRelevantMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
            let localEnabled = hasCustomNotificationIconFromSettings
                && (campaignAutomation.rules?["locationEntry"]?.enabled ?? false)
            patch.locationRelevantText = localEnabled ? (t.isEmpty ? nil : String(t.prefix(200))) : nil
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            isPerimeterRelevantTextDirty = false
            await syncService.syncAfterServerMutation()
        } catch {
            _ = shouldSuppressCancelledNetworkNoise(error)
        }
    }

    private func scheduleBannerTextsAutoSave() {
        guard resolveSlugForAPI() != nil else { return }
        bannerTextsAutoSaveTask?.cancel()
        bannerTextsAutoSaveTask = Task {
            try? await Task.sleep(nanoseconds: Self.bannerTextsAutoSaveDebounceNs)
            guard !Task.isCancelled else { return }
            _ = await persistBannerTextsToServer()
        }
    }

    @MainActor
    private func flushBannerTextsAutoSave() async {
        bannerTextsAutoSaveTask?.cancel()
        bannerTextsAutoSaveTask = nil
        guard resolveSlugForAPI() != nil else { return }
        if isNotificationSendInFlight { return }
        if await persistBannerTextsToServer() {
            await syncService.syncAfterServerMutation()
        }
    }

    @discardableResult
    @MainActor
    private func persistBannerTextsToServer(clearAfterSend: Bool = false) async -> Bool {
        guard let slug = resolveSlugForAPI() else { return false }
        do {
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let cur = (dashboardSettings?.notificationTitleOverride ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !clearAfterSend && t == cur {
                return true
            }
            var patch = FullDashboardSettingsPatch()
            patch.notificationTitleOverride = t.isEmpty ? nil : String(t.prefix(80))
            // Corps de campagne → POST /notifications/send (`last_broadcast_message` côté serveur).
            // Ne jamais PATCH `notification_change_message` ici : c’est le gabarit PassKit stable (Ma carte, avec %@).
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            return true
        } catch {
            if shouldSuppressCancelledNetworkNoise(error) { return false }
            return false
        }
    }

    /// Chargement initial optimisé : settings + segments en parallèle pour réduire la latence perçue.
    @MainActor
    private func loadNotificationReadiness() async {
        guard authService.businesses.count > 1 || authService.businessesForMerchantSwitcher.count > 1 else {
            notificationReadinessRows = []
            return
        }
        isLoadingNotificationReadiness = true
        defer { isLoadingNotificationReadiness = false }
        do {
            let resp: NotificationReadinessResponse = try await APIClient.shared.request(.authNotificationReadiness)
            notificationReadinessRows = resp.businesses ?? []
            if selectedNotificationSlugs.isEmpty, let slug = resolveSlugForAPI() {
                selectedNotificationSlugs = [slug]
            }
        } catch {
            if !shouldSuppressCancelledNetworkNoise(error) {
                notificationReadinessRows = []
            }
        }
    }

    @MainActor
    private func loadCampaignData(force: Bool = false) async {
        if isLoadingCampaignDataInFlight { return }
        guard let slug = resolveSlugForAPI() else {
            segments = nil
            dashboardSettings = nil
            perimeterRelevantMessageText = ""
            isPerimeterRelevantTextDirty = false
            loadError = nil
            isLoadingData = false
            lastCampaignDataSlug = nil
            return
        }
        if !force,
           slug == lastCampaignDataSlug,
           let last = lastCampaignDataLoadAt,
           Date().timeIntervalSince(last) < 1.2 {
            return
        }
        if slug != lastCampaignDataSlug {
            if let cached = ScanFlowSettingsCache.cached(for: slug) {
                CampaignNotificationImageCache.applyPreviewTimestamps(from: cached, slug: slug)
                dashboardSettings = cached
                prewarmNotificationIconIfPossible(slug: slug, settings: cached)
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let override = cached.notificationTitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let commerce = cached.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    title = override.isEmpty ? (commerce.isEmpty ? businessDisplayName : commerce) : override
                }
            } else {
                dashboardSettings = nil
            }
            segments = nil
        }

        isLoadingCampaignDataInFlight = true
        isLoadingData = true
        loadError = nil
        defer { isLoadingCampaignDataInFlight = false }

        do {
            let gotSettings = try await APIClient.shared.request(.businessSettings(slug: slug)) as BusinessSettingsResponse
            ScanFlowSettingsCache.store(gotSettings, for: slug)
            CampaignNotificationImageCache.applyPreviewTimestamps(from: gotSettings, slug: slug)
            dashboardSettings = gotSettings
            prewarmNotificationIconIfPossible(slug: slug, settings: gotSettings)
            if !shouldDeferCampaignDataReloadDuringEdit {
                perimeterRelevantMessageText = gotSettings.locationRelevantText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                isPerimeterRelevantTextDirty = false
            }
            let gotSeg: CampaignSegmentsResponse
            do {
                gotSeg = try await APIClient.shared.request(.dashboardNotificationSegments(slug: slug)) as CampaignSegmentsResponse
            } catch let segErr as APIError where segErr.isHTTPResourceMissing {
                gotSeg = .empty
            } catch {
                throw error
            }
            segments = gotSeg
            let iconReady = !(gotSettings.notificationIconUrl?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            ).isEmpty
            campaignAutomation = campaignAutomationGatedForIcon(
                mergedAutomation(from: gotSettings.campaignAutomation),
                hasCustomIcon: iconReady
            )
            isApplyingRemoteSettings = true
            let override = gotSettings.notificationTitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = override.isEmpty ? defaultManualNotificationTitle : override
            }
            // Ne pas préremplir le champ campagne avec `notification_change_message` (gabarit PassKit ≠ message de campagne).
            isApplyingRemoteSettings = false
            loadError = nil
            isLoadingData = false
            lastCampaignDataLoadAt = Date()
            lastCampaignDataSlug = slug
            await loadNotificationReadiness()
        } catch {
            if shouldSuppressCancelledNetworkNoise(error) {
                isLoadingData = false
                return
            }
            isLoadingData = false
            if let api = error as? APIError, api.isHTTPResourceMissing {
                dashboardSettings = nil
                segments = nil
                loadError = nil
                return
            }
            loadError = APIError.merchantFacingMessage(from: error) ?? "Impossible de charger les notifications. Réessayez."
        }
    }

    private func shouldSuppressCancelledNetworkNoise(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlErr = error as? URLError, urlErr.code == .cancelled { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        if case let APIError.network(wrapped) = error {
            return shouldSuppressCancelledNetworkNoise(wrapped)
        }
        return false
    }

    /// Pendant une saisie périmètre en cours (dirty ou debounce actif), ne pas réappliquer l'état distant.
    private var shouldDeferCampaignDataReloadDuringEdit: Bool {
        let automationRecentlyEdited: Bool = {
            guard let lastAutomationLocalEditAt else { return false }
            return Date().timeIntervalSince(lastAutomationLocalEditAt) < 1.4
        }()
        return isPerimeterRelevantTextDirty
            || perimeterRelevantTextSaveTask != nil
            || campaignAutomationSaveTask != nil
            || automationRecentlyEdited
    }

    private func prepareNotificationIconCrop(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            await MainActor.run { notificationIconPhotoItem = nil }
            return
        }
        await MainActor.run {
            notificationIconCropPayload = ImageCropPayload(image: image, spec: .squareIcon)
            notificationIconPhotoItem = nil
        }
    }

    @MainActor
    private func uploadCroppedNotificationIcon(_ image: UIImage) async {
        guard let slug = resolveSlugForAPI() else { return }
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
            errorMessage = "Impossible d’encoder l’image."
            return
        }
        let maxLen = 512 * 1024
        guard jpeg.count <= maxLen else {
            errorMessage = "Image trop volumineuse (max. 512 Ko)."
            return
        }
        let b64 = jpeg.base64EncodedString()
        let payload = "data:image/jpeg;base64,\(b64)"
        isUploadingNotificationIcon = true
        defer { isUploadingNotificationIcon = false }
        do {
            var patch = FullDashboardSettingsPatch()
            patch.notificationIconBase64 = payload
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            ScanFlowSettingsCache.clear(for: slug)
            CampaignNotificationImageCache.markLocalUploadNow(slug: slug)
            invalidateCachedGETNotificationIconResponses()
            // Bump immédiat : la vue se recrée tout de suite avec le nouveau `?v=` basé sur `localAt`
            // frais. Sans cela, si l'utilisateur regardait la preview avant `loadCampaignData`, SwiftUI
            // pouvait garder l'ancienne `AsyncImage` (donc l'ancienne image) à l'écran.
            notificationIconReloadNonce &+= 1
            // PATCH serveur : envoi PassKit APNs ; délai pour que le bundle à jour soit servi avant resync aperçu.
            try await Task.sleep(nanoseconds: 500_000_000)
            await loadCampaignData(force: true)
            // Deuxième bump : après `loadCampaignData` la vue reflète aussi le nouveau `notification_icon_updated_at`
            // serveur — on force un autre re-render pour éviter tout état transitoire.
            notificationIconReloadNonce &+= 1
            await syncService.syncAfterServerMutation()
            notificationLogoPopupPresented = false
        } catch {
            if !shouldSuppressCancelledNetworkNoise(error) {
                assignMerchantAlertMessage(from: error)
            }
        }
    }

    @MainActor
    private func setSendProgress(_ value: CGFloat, animated: Bool = true) {
        let clamped = max(0, min(1, value))
        if animated {
            withAnimation(.easeInOut(duration: 0.38)) {
                notificationSendProgress = clamped
            }
        } else {
            notificationSendProgress = clamped
        }
    }

    @MainActor
    private func finishSendProgressUI(clearSuccessCheck: Bool = true) {
        if clearSuccessCheck {
            sendSuccessCount = nil
        }
        isSending = false
        isNotificationSendInFlight = false
        notificationSendProgress = 0
    }

    @MainActor
    private func dismissNotificationComposerKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    @MainActor
    private func send() async {
        guard campaignManualSendUnlocked else {
            NotificationCenter.default.postOpenMerchantSubscriptionFromSession(
                usedBusinesses: authService.usedBusinesses,
                allowedBusinesses: authService.allowedBusinesses,
                hasActiveSubscription: authService.hasEncashedMerchantSubscription
            )
            return
        }
        guard let slug = resolveSlugForAPI() else { return }
        let sendSlugs = selectedNotificationSlugs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let targetsReady = notificationReadinessRows.filter { row in
            guard let s = row.slug?.trimmingCharacters(in: .whitespacesAndNewlines), sendSlugs.contains(s) else { return false }
            return row.ready == true
        }
        if showsMultiCommerceNotificationTargets, !sendSlugs.isEmpty, targetsReady.isEmpty {
            let blocked = notificationReadinessRows.filter { row in
                guard let s = row.slug, sendSlugs.contains(s) else { return false }
                return row.ready != true
            }
            errorMessage = blocked.compactMap { row in
                let name = row.displayName
                let why = row.blockMessage ?? "Non prêt"
                return "\(name) : \(why)"
            }.joined(separator: "\n\n")
            if errorMessage?.isEmpty != false {
                errorMessage = "Aucun des commerces sélectionnés n’est prêt à envoyer (icône ou appareils manquants)."
            }
            return
        }
        if !showsMultiCommerceNotificationTargets {
            guard hasCustomNotificationIconFromSettings else {
                notificationLogoPopupPresented = true
                return
            }
        }
        let msg = bodyText
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }

        bannerTextsAutoSaveTask?.cancel()
        bannerTextsAutoSaveTask = nil
        isSending = true
        isNotificationSendInFlight = true
        successFeedback = nil
        setSendProgress(0.06, animated: false)

        do {
            _ = await persistBannerTextsToServer()
            setSendProgress(0.20)

            var payload = NotificationSendPayload(
                title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title,
                message: msg,
                segment: segment
            )
            payload.testSelfOnly = false
            if sendSlugs.count > 1 {
                payload.businessSlugs = sendSlugs
            }
            let sendResult: NotificationSendResponse = try await APIClient.shared.request(
                .dashboardNotificationSend(slug: slug, body: payload)
            )
            setSendProgress(0.64)

            if sendResult.code == "no_real_clients" {
                finishSendProgressUI()
                errorMessage = sendResult.message
                    ?? "Aucun vrai client n’a encore ajouté la carte. Partage le lien de ta carte pour que tes clients l’ajoutent à Apple Wallet."
                return
            }

            let touched = sendResult.total ?? sendResult.sent ?? 0
            if touched == 0 {
                finishSendProgressUI()
                let serverMsg = sendResult.message?.trimmingCharacters(in: .whitespacesAndNewlines)
                errorMessage = (serverMsg?.isEmpty == false ? serverMsg : nil)
                    ?? "Aucun client n’a pu être notifié. Vérifiez que vos clients ont ajouté la carte (Apple Wallet ou navigateur)."
                return
            }

            var pendingSuccessFeedback: String?
            if sendResult.multi == true, let results = sendResult.results {
                for row in results where row.ok == true {
                    NotificationDeliveryFollowUp.trackAsyncSend(
                        slug: row.slug ?? slug,
                        title: payload.title,
                        message: msg,
                        jobId: row.jobId,
                        batchId: row.batchId,
                        expectedDevices: row.deliverableDevices ?? row.totalDevices,
                        playsSoundOnDelivered: false
                    )
                }
                let okCount = results.filter { $0.ok == true }.count
                let skipped = results.filter { $0.ok != true }
                var text = "Notification envoyée vers \(okCount) commerce\(okCount > 1 ? "s" : "")."
                if !skipped.isEmpty {
                    let names = skipped.map { $0.businessName ?? $0.slug ?? "Commerce" }.joined(separator: ", ")
                    text += "\nIgnoré : \(names)."
                }
                pendingSuccessFeedback = text
            } else {
                NotificationDeliveryFollowUp.trackAsyncSend(
                    slug: slug,
                    title: payload.title,
                    message: msg,
                    jobId: sendResult.jobId,
                    batchId: sendResult.batchId,
                    expectedDevices: sendResult.total ?? touched,
                    playsSoundOnDelivered: false
                )
                pendingSuccessFeedback = "Notification envoyée à \(touched) client\(touched > 1 ? "s" : "")."
            }

            withAnimation(.easeInOut(duration: 0.22)) { sendSuccessCount = touched }
            try? await Task.sleep(nanoseconds: 350_000_000)
            setSendProgress(0.72)

            keepManualMessageFieldClearedAfterSend = true
            withAnimation(.easeOut(duration: 0.2)) {
                bodyText = ""
            }
            dismissNotificationComposerKeyboard()
            setSendProgress(0.80)

            _ = await persistBannerTextsToServer(clearAfterSend: true)
            setSendProgress(0.86)

            invalidateCachedGETNotificationIconResponses()
            notificationIconReloadNonce &+= 1
            await loadCampaignData(force: true)
            setSendProgress(0.91)

            Task { await syncService.syncIfNeeded() }
            setSendProgress(0.97)
            setSendProgress(1.0)

            try? await Task.sleep(nanoseconds: 280_000_000)
            MerchantUXFeedback.shared.playNotificationSent()
            if let pendingSuccessFeedback {
                successFeedback = pendingSuccessFeedback
            }

            try? await Task.sleep(nanoseconds: 900_000_000)
            withAnimation(.easeOut(duration: 0.2)) { sendSuccessCount = nil }
            finishSendProgressUI(clearSuccessCheck: false)
        } catch let api as APIError {
            finishSendProgressUI()
            if case .notificationIconRequired = api {
                notificationLogoPopupPresented = true
            } else {
                errorMessage = api.errorDescription ?? "Erreur lors de l’envoi de la notification."
            }
        } catch {
            finishSendProgressUI()
            assignMerchantAlertMessage(from: error)
        }
    }
}

// MARK: - Popup logo notif (même schéma que Commerce — panier repère)

private struct NotificationLogoPopupGlassCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct NotificationManualLogoCommercePopupCard: View {
    let logoURL: String?
    let isUploadingNotificationIcon: Bool
    @Binding var notificationIconPhotoItem: PhotosPickerItem?

    private static let logoHintMessage = "👈 Votre logo apparaîtra ici dans la notification."

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ManualRichNotificationReadOnlyPreview(
                senderTitle: "",
                messageBody: "",
                appDisplayNameFallback: "",
                logoURL: logoURL,
                hidesSenderTitleRow: true,
                messageCopyOverride: Self.logoHintMessage
            )

            if isUploadingNotificationIcon {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Envoi en cours…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.black.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }

            PhotosPicker(selection: $notificationIconPhotoItem, matching: .images, photoLibrary: .shared()) {
                HStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Mettre mon logo")
                        .font(.system(size: 17, weight: .bold, design: .default))
                }
                .foregroundStyle(Color.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.white))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isUploadingNotificationIcon)
            .opacity(isUploadingNotificationIcon ? 0.55 : 1)
            .accessibilityLabel("Choisir une image pour le logo de notification")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
        )
        .modifier(NotificationLogoPopupGlassCardModifier())
    }
}

/// Carte 3D légère (relief + inclinaison) — fond plein écran Notifications.
/// La `Map` n’est montée que lorsque les coordonnées commerce sont connues.
private struct LocalAutomationReliefMapBackdrop: View {
    let latitude: Double?
    let longitude: Double?
    let radiusMeters: Int?
    let isLiveElevationMapActive: Bool

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Group {
            if let lat = latitude, let lng = longitude, isLiveElevationMapActive {
                reliefMap(latitude: lat, longitude: lng)
            } else {
                placeholderBackdrop
            }
        }
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .transaction { $0.animation = nil }
    }

    private var placeholderBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(white: 0.14), Color(white: 0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "map")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.28))
        }
        .clipped()
    }

    private func backdropCameraDistance(for radiusMeters: CLLocationDistance) -> CLLocationDistance {
        // Plus large que l’ancien plafond 780 m — la zone Wallet reste visible sans zoom excessif.
        min(1_850, max(820, radiusMeters * 11.0))
    }

    @ViewBuilder
    private func reliefMap(latitude: Double, longitude: Double) -> some View {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let radiusCL = CLLocationDistance(max(30, min(1000, radiusMeters ?? 100)))
        let cameraTaskId = "\(latitude)-\(longitude)-\(radiusCL)-3d-dark"
        let distanceMeters = backdropCameraDistance(for: radiusCL)
        let mapContent = Map(position: $cameraPosition, interactionModes: []) {
            Annotation("", coordinate: center) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    Circle()
                        .fill(AppTheme.Colors.primary)
                        .frame(width: 10, height: 10)
                }
            }
            MapCircle(center: center, radius: radiusCL)
                .foregroundStyle(Color.blue.opacity(0.20))
                .stroke(Color.blue.opacity(0.66), lineWidth: 2)
        }

        Group {
            if #available(iOS 18.0, *) {
                mapContent
                    .mapStyle(.standard(elevation: .realistic, emphasis: .muted, pointsOfInterest: .excludingAll))
            } else {
                mapContent
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            }
        }
        .background(MapKitDarkBackdropEnforcer())
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .mapControlVisibility(.hidden)
        .padding(.bottom, -22)
        .padding(.leading, -6)
        .allowsHitTesting(false)
        .clipped()
        .transaction { $0.animation = nil }
        .task(id: cameraTaskId) {
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                cameraPosition = .camera(
                    MapCamera(centerCoordinate: center, distance: distanceMeters, heading: 28, pitch: 62)
                )
            }
        }
    }
}

/// L’app force `.preferredColorScheme(.light)` au root : MapKit reste clair sans override UIKit explicite.
private struct MapKitDarkBackdropEnforcer: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            applyDarkMapStyle(from: uiView, attempt: 0)
        }
    }

    private func applyDarkMapStyle(from anchor: UIView, attempt: Int) {
        guard let mapView = anchor.enclosingMapKitView else {
            guard attempt < 4 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                applyDarkMapStyle(from: anchor, attempt: attempt + 1)
            }
            return
        }
        mapView.overrideUserInterfaceStyle = .dark
        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
            config.pointOfInterestFilter = .excludingAll
            mapView.preferredConfiguration = config
        }
    }
}

private extension UIView {
    func findMapKitViewInHierarchy() -> MKMapView? {
        if let mapView = self as? MKMapView { return mapView }
        for subview in subviews {
            if let found = subview.findMapKitViewInHierarchy() { return found }
        }
        return nil
    }

    var enclosingMapKitView: MKMapView? {
        var candidate: UIView? = self
        while let current = candidate {
            if let mapView = current.findMapKitViewInHierarchy() { return mapView }
            candidate = current.superview
        }
        return nil
    }
}

// MARK: - Surface aperçu notification (carrousel = carte blanche lisible ; standard = verre)

private extension View {
    @ViewBuilder
    func walletNotificationPreviewSurface(previewSize: WalletNotificationPreviewSize, lightGlass: Bool = false) -> some View {
        let radius = previewSize.glassCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if previewSize == .carousel {
            self
                .background(shape.fill(Color.white))
                .overlay(shape.stroke(Color.black.opacity(0.09), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        } else if lightGlass {
            // Périmètre sur carte sombre — liquid glass teinté (texte blanc via `walletPreviewColorScheme`).
            self
                .glassEffectRegularDark(cornerRadius: radius)
        } else {
            self
                .glassEffect(.regularInteractive, cornerRadius: radius)
                .shadow(color: .clear, radius: 0, y: 0)
        }
    }

    @ViewBuilder
    func walletPreviewColorScheme(lightGlass: Bool) -> some View {
        if lightGlass {
            self.preferredColorScheme(.dark)
        } else {
            self.preferredColorScheme(.light)
        }
    }
}

// MARK: - Notif liquid glass (carrousel automatisations — legacy)

/// Bannière seule (sans faux iPhone) : style notif système, glass.
private struct AutomationCarouselLiquidNotificationBanner: View {
    let senderTitle: String
    let messageBody: String
    /// Si non-nil : édition inline du message (sync serveur côté parent).
    var messageBinding: Binding<String>? = nil
    /// Placeholder du `TextField` (ex. message périmètre vs automatisation segment).
    var textFieldPlaceholder: String = "Message de la notification"
    let logoURL: String?
    /// `false` pour le périmètre : retours à la ligne **interdits** (texte replié sur plusieurs lignes visuellement) ; la touche « OK » / ✓ ferme le clavier et peut appeler `onSubmitActivate` sans insérer `\n`.
    var useMultilineMessageField: Bool = true
    var onSubmitActivate: (() -> Void)? = nil

    @FocusState private var messageFieldFocused: Bool

    private var previewSize: WalletNotificationPreviewSize { .carousel }

    var body: some View {
        HStack(alignment: .center, spacing: previewSize.rowSpacing) {
            automationIcon
            VStack(alignment: .leading, spacing: previewSize.textStackSpacing) {
                Text(senderTitle)
                    .font(previewSize.titleFont)
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let binding = messageBinding {
                    Group {
                        if useMultilineMessageField {
                            TextField(textFieldPlaceholder, text: binding, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(previewSize.bodyFont)
                                .foregroundStyle(Color.black.opacity(0.88))
                                .lineLimit(2 ... 5)
                                .multilineTextAlignment(.leading)
                        } else {
                            TextField(textFieldPlaceholder, text: binding, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(previewSize.bodyFont)
                                .foregroundStyle(Color.black.opacity(0.88))
                                .lineLimit(2 ... 12)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .submitLabel(.done)
                    .focused($messageFieldFocused)
                    .onSubmit {
                        messageFieldFocused = false
                        onSubmitActivate?()
                    }
                    .accessibilityLabel("\(textFieldPlaceholder) Modifiable.")
                } else {
                    Text(messageBody)
                        .font(previewSize.bodyFont)
                        .foregroundStyle(Color.black.opacity(0.88))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, previewSize.verticalPadding)
        .padding(.horizontal, previewSize.horizontalPadding)
        .walletNotificationPreviewSurface(previewSize: previewSize)
        .preferredColorScheme(.light)
    }

    private var automationIcon: some View {
        Group {
            if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                BusinessLogoView(
                    logoURL: raw,
                    logoAssetContext: .campaignNotificationIcon,
                    size: previewSize.iconSide,
                    cornerRadius: previewSize.iconCorner
                )
            } else {
                Image("logonotif")
                    .resizable()
                    .scaledToFill()
                    .frame(width: previewSize.iconSide, height: previewSize.iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: previewSize.iconCorner, style: .continuous))
            }
        }
    }

}

#if DEBUG
#Preview {
    let container = PersistenceController.preview.container
    NavigationStack {
        CampaignNotificationsView()
            .environmentObject(DataService(context: container.viewContext))
            .environmentObject(SyncService(container: container))
            .environmentObject(MainTabRouter())
            .environmentObject(AuthService())
            .environmentObject(MerchantMemberSearchCoordinator())
    }
}
#endif
