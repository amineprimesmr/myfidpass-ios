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
}

private struct CampaignFamilySpec: Identifiable {
    let id: String
    let title: String
    let icon: String
    let rules: [CampaignRuleSpec]
}

private enum NotificationsTopRoundedPanel {
    static let shape = UnevenRoundedRectangle(
        topLeadingRadius: 24,
        bottomLeadingRadius: 0,
        bottomTrailingRadius: 0,
        topTrailingRadius: 24,
        style: .continuous
    )
}

// MARK: - Aide Apple Wallet (écran verrouillé vs message commerçant)

/// Apple n’expose pas d’API pour remplacer « Carte de fidélité modifiée » sur le verrouillage : on informe le commerçant.
private struct WalletLockScreenDisclaimerCard: View {
    /// `true` : une ligne sous les actions (manuel / auto) ; `false` : bloc détaillé sous l’aperçu.
    var compact: Bool

    var body: some View {
        if compact {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.body)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text(
                    "Lors du tout premier changement après ajout au Wallet, l’écran verrouillé affiche souvent « Carte de fidélité modifiée » (choix d’Apple). Votre texte est bien enregistré sur le pass ; les alertes suivantes le montrent davantage (Wallet, aperçu étendu)."
                )
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.iphone")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text("Affichage côté client (Apple)")
                        .font(AppTheme.Fonts.subheadline())
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    disclaimerRow(
                        symbol: "1.circle.fill",
                        text: "L’aperçu ci-dessus = le texte enregistré dans le pass (titre + message)."
                    )
                    disclaimerRow(
                        symbol: "bell.badge.fill",
                        text: "Première notification après ajout de la carte : sur l’écran verrouillé, iOS affiche souvent uniquement la phrase système « Carte de fidélité modifiée ». Ce n’est pas un bug Myfidpass : Apple ne permet pas de la remplacer par votre phrase sur cette surface."
                    )
                    disclaimerRow(
                        symbol: "sparkles",
                        text: "À partir des mises à jour suivantes, votre message personnalisé apparaît plus souvent (aperçu étendu, îlot, en ouvrant Wallet)."
                    )
                    disclaimerRow(
                        symbol: "wallet.pass.fill",
                        text: "Le client voit toujours votre contenu sur la carte dans l’app Wallet, après ouverture ou rafraîchissement du pass."
                    )
                    disclaimerRow(
                        symbol: "arrow.triangle.merge",
                        text: "Manuel et automatique partagent le même champ « Message » sur le pass : le dernier envoi (peu importe l’origine) remplace le texte côté clients — ce n’est pas deux conversations séparées."
                    )
                }
            }
            .padding(AppTheme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .strokeBorder(AppTheme.Colors.primary.opacity(0.2), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        }
    }

    private func disclaimerRow(symbol: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.body)
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 22, alignment: .center)
            Text(text)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private let campaignFamilies: [CampaignFamilySpec] = [
    CampaignFamilySpec(
        id: "reactivation",
        title: "Client inactif +14 jours",
        icon: "arrow.counterclockwise.circle",
        rules: [
            CampaignRuleSpec(
                id: "inactive14",
                title: "Client inactif +14 jours",
                subtitle: "Aucune visite depuis 2 semaines",
                segmentKey: "inactive14"
            ),
        ]
    ),
    CampaignFamilySpec(
        id: "birthday",
        title: "Anniversaires",
        icon: "gift.fill",
        rules: [
            CampaignRuleSpec(
                id: "birthdayToday",
                title: "Anniversaire du jour",
                subtitle: "Profil complété avec date de naissance (téléphone + ville)",
                segmentKey: "birthdayToday"
            ),
        ]
    ),
    CampaignFamilySpec(
        id: "local",
        title: "Local & Wallet",
        icon: "location.circle",
        rules: [
            CampaignRuleSpec(
                id: "locationEntry",
                title: "Entrée dans le périmètre",
                subtitle: "Notification quand le client entre dans la zone Wallet",
                segmentKey: nil
            ),
        ]
    ),
]

private let defaultRuleMessages: [String: String] = [
    "inactive14": "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %.",
    "birthdayToday": "Joyeux anniversaire ! Profitez de -20 % en commandant aujourd'hui.",
    "locationEntry": "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête.",
]

/// Message suggéré pour relances inactifs (événement « Inactif depuis X jours ») — le commerçant peut l’ajuster.
private let defaultInactiveRelancePromoMessage =
    "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %."

private func mergedAutomation(from api: CampaignAutomationConfigDTO?) -> CampaignAutomationConfigDTO {
    var rules: [String: CampaignAutomationRuleDTO] = [:]
    for family in campaignFamilies {
        for r in family.rules where !r.id.hasPrefix("_info") {
            let defMsg = defaultRuleMessages[r.id] ?? ""
            let existing: CampaignAutomationRuleDTO? = {
                if let exact = api?.rules?[r.id] { return exact }
                switch r.id {
                case "inactive14":
                    return api?.rules?["inactive_14"]
                case "birthdayToday":
                    return api?.rules?["birthday_today"]
                default:
                    return nil
                }
            }()
            rules[r.id] = CampaignAutomationRuleDTO(
                enabled: true,
                message: (existing?.message?.isEmpty == false ? existing?.message : defMsg) ?? defMsg,
                segment: existing?.segment,
                title: existing?.title
            )
        }
    }
    if let apiRules = api?.rules {
        for (k, v) in apiRules {
            if k.hasPrefix("custom_") || k.hasPrefix("event_") {
                rules[k] = v
            } else if rules[k] == nil {
                var copy = v
                if copy.enabled != true { copy.enabled = true }
                rules[k] = copy
            }
        }
    }
    let cd = api?.globalCooldownDays ?? 7
    return CampaignAutomationConfigDTO(version: api?.version ?? 1, globalCooldownDays: min(90, max(1, cd)), rules: rules)
}

// MARK: - Barre de progression envoi (bandeau tout en haut — `progress` suit les étapes réelles de `send()`)

/// Remplissage 0…1 + halo blanc très vif ; léger pulsage (TimelineView) pendant l’attente réseau / synchro.
private struct NotificationSendTopProgressStrip: View {
    var progress: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathe = 0.62 + 0.38 * (0.5 + 0.5 * sin(t * 1.15))
            GeometryReader { geo in
                let w = max(geo.size.width, 1)
                let p = max(0, min(1, progress))
                let fillW = max(0, p * w)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.22 + 0.12 * breathe))
                        .frame(height: 6)

                    if fillW > 0.5 {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.55 * breathe))
                            .frame(width: fillW + 14, height: 12)
                            .blur(radius: 10)
                            .offset(x: -7)

                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.97),
                                        Color.white,
                                        Color.white.opacity(0.98),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fillW, height: 6)
                            .shadow(color: Color.white.opacity(0.95), radius: 12, x: 0, y: 0)
                            .shadow(color: Color.white.opacity(0.55), radius: 22, x: 0, y: 0)

                        if fillW > 18 {
                            Capsule(style: .continuous)
                                .fill(Color.white)
                                .frame(width: min(16, fillW * 0.08), height: 7)
                                .blur(radius: 2.5)
                                .offset(x: fillW - 10)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .compositingGroup()
            }
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
    @EnvironmentObject private var authService: AuthService
    @StateObject private var dataService: DataService

    @State private var title = ""
    @State private var bodyText = ""
    @State private var segment: String?
    @State private var segments: CampaignSegmentsResponse?
    @State private var dashboardSettings: BusinessSettingsResponse?
    @State private var campaignAutomation: CampaignAutomationConfigDTO = mergedAutomation(from: nil)
    @State private var message: String?

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
    @State private var notificationIconPhotoItem: PhotosPickerItem?
    @State private var notificationIconCropPayload: ImageCropPayload?
    @State private var isUploadingNotificationIcon = false
    /// Même URL `…/notification-icon` après upload : recréer les vues image + appliquer le nouveau `?v=`.
    @State private var notificationIconReloadNonce = 0
    /// Une seule feuille à la fois (sinon iOS : « only presenting a single sheet is supported »).
    private enum AuxiliarySheet: Identifiable, Equatable {
        case ruleEditor(String)
        case customAutomation
        case eventAutomation

        var id: String {
            switch self {
            case .ruleEditor(let rid): return "rule:\(rid)"
            case .customAutomation: return "custom"
            case .eventAutomation: return "event"
            }
        }
    }

    @State private var auxiliarySheet: AuxiliarySheet?
    /// Même schéma que le popup « panier repère » sur la page Commerce (fond + carte centrée).
    @State private var notificationLogoPopupPresented = false
    @State private var notificationIconNudgeTask: Task<Void, Never>?
    @State private var showPerimeterMapSheet = false
    @State private var customRuleBeingEdited: String?
    @State private var customDraftTitle = ""
    @State private var customDraftSegment = ""
    @State private var customDraftMessage = ""
    @State private var customRulePendingDelete: String?

    /// Envoi manuel de campagne : même déblocage que les stats détaillées (Stripe qualifiant ou admin).
    private var campaignManualSendUnlocked: Bool {
        if authService.isPlatformAdmin { return true }
        if authService.hasPaidStripeSubscription { return true }
        return false
    }

    // MARK: - Event-based custom automations (no segment)
    @State private var eventAutomationsRuleBeingEdited: String?
    @State private var eventDraftTitle = ""
    @State private var eventDraftEventType = "member_created"
    @State private var eventDraftDelayMinutes: Int = 2
    @State private var eventDraftMessage = ""
    @State private var eventDraftPreset: EventPreset = .memberCreated
    @State private var eventDraftInactiveDays: Int = 30
    @State private var eventDraftScheduleHour: Int = 10
    @State private var eventDraftScheduleMinute: Int = 0
    @State private var eventDraftCustomKey: String = ""
    @State private var eventDraftAIInstruction: String = ""
    @State private var isEventDraftAIParsing = false
    @State private var eventRulePendingDelete: String?
    /// Page du carrousel « Notifications automatiques » (géolocalisation + inactifs).
    @State private var automationCarouselPage: Int = 0
    /// Confirmation **uniquement** avant de désactiver tout un bloc d’automatisations.
    @State private var familyAutomationDisableConfirm: FamilyAutomationDisableConfirm?
    @State private var lastCarouselHapticPage: Int = 0
    @State private var lastCampaignDataSlug: String?
    @State private var scheduledCampaignDataReloadTask: Task<Void, Never>?

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

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
        URLCache.shared.removeAllCachedResponses()
    }

    private var bannerFieldPromptFallback: String {
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

    /// Réserve verticale sous le chrome noir (barre titre + bandeau d’envoi éventuel) pour ne pas recouvrir le panneau blanc.
    private var campaignNotificationsScrollTopInset: CGFloat {
        let baseHeaderChrome: CGFloat = DashboardHomeMinimalTopBarLayout.scrollContentTopInset
        // `NotificationSendTopProgressStrip` : frame 18 + paddings top 4 / bottom 6.
        let sendStripBlock: CGFloat = isSending ? 28 : 0
        return baseHeaderChrome + sendStripBlock
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
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                previewSection
                    .padding(.top, 14)
                automationsContent
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, 100)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    private var campaignNotificationsWithLifecycle: some View {
        ZStack(alignment: .top) {
            Color.black
                .ignoresSafeArea(edges: .top)

            campaignNotificationsScrollStack
                .background(AppTheme.Colors.background)
                .clipShape(NotificationsTopRoundedPanel.shape)
                .padding(.top, campaignNotificationsScrollTopInset)
                .ignoresSafeArea(edges: .bottom)
                .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 0) {
                if isSending {
                    NotificationSendTopProgressStrip(progress: notificationSendProgress)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)
                        .background(Color.black)
                        .ignoresSafeArea(edges: .top)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
                headerBlock
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

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
        .onAppear {
            scheduleNotificationIconNudgeIfNeeded()
        }
        .onChange(of: auxiliarySheet) { _, newVal in
            if newVal != nil {
                notificationLogoPopupPresented = false
                return
            }
            if !hasCustomNotificationIconFromSettings {
                scheduleNotificationIconNudgeIfNeeded()
            }
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
        .task {
            await Task.yield()
            await loadCampaignData()
        }
        .onChange(of: activeSlugForViewChange) { _, _ in
            if let slug = resolveSlugForAPI(),
               let cached = ScanFlowSettingsCache.cached(for: slug) {
                CampaignNotificationImageCache.applyPreviewTimestamps(from: cached, slug: slug)
                dashboardSettings = cached
                prewarmNotificationIconIfPossible(slug: slug, settings: cached)
            } else {
                dashboardSettings = nil
            }
            segments = nil
            notificationIconReloadNonce &+= 1
            scheduleCampaignDataReload(force: true, debounceNs: 0)
            scheduleNotificationIconNudgeIfNeeded()
        }
        .onChange(of: syncService.lastSyncDate) { _, _ in
            scheduleCampaignDataReload(force: false, debounceNs: 220_000_000)
        }
        .refreshable {
            await loadCampaignData()
        }
        .alert("Info", isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            if let message { Text(message) }
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
            .sheet(item: $auxiliarySheet) { sheet in
                switch sheet {
                case .ruleEditor(let ruleId):
                    ruleEditSheet(ruleId: ruleId)
                case .customAutomation:
                    customAutomationEditorSheet
                case .eventAutomation:
                    eventAutomationEditorSheet
                }
            }
            .alert("Supprimer cette automatisation ?", isPresented: Binding(
                get: { customRulePendingDelete != nil },
                set: { if !$0 { customRulePendingDelete = nil } }
            )) {
                Button("Supprimer", role: .destructive) {
                    if let id = customRulePendingDelete {
                        removeCustomRule(id: id)
                    }
                    customRulePendingDelete = nil
                }
                Button("Annuler", role: .cancel) { customRulePendingDelete = nil }
            } message: {
                Text("La règle sera retirée de la liste. Vous pourrez en créer une nouvelle à tout moment.")
            }
            .alert("Supprimer cette automatisation événementielle ?", isPresented: Binding(
                get: { eventRulePendingDelete != nil },
                set: { if !$0 { eventRulePendingDelete = nil } }
            )) {
                Button("Supprimer", role: .destructive) {
                    if let id = eventRulePendingDelete {
                        removeEventRule(id: id)
                    }
                    eventRulePendingDelete = nil
                }
                Button("Annuler", role: .cancel) { eventRulePendingDelete = nil }
            } message: {
                Text("La règle sera retirée de la liste. Vous pourrez en créer une nouvelle à tout moment.")
            }
            .fullScreenCover(isPresented: $showPerimeterMapSheet) {
                PerimeterMapView(context: viewContext, onDismissEmbedded: { showPerimeterMapSheet = false })
                    .environmentObject(syncService)
            }
            .alert("Désactiver ce bloc ?", isPresented: Binding(
                get: { familyAutomationDisableConfirm != nil },
                set: { if !$0 { familyAutomationDisableConfirm = nil } }
            )) {
                Button("Annuler", role: .cancel) {
                    familyAutomationDisableConfirm = nil
                }
                Button("Désactiver", role: .destructive) {
                    if let payload = familyAutomationDisableConfirm {
                        setFamilyAutomationEnabled(carouselFamilyId: payload.carouselFamilyId, enabled: false)
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                    familyAutomationDisableConfirm = nil
                }
            } message: {
                if let payload = familyAutomationDisableConfirm {
                    Text(
                        "« \(automationFamilyDisplayName(for: payload.carouselFamilyId)) » n’enverra plus de notifications automatiques. Vos textes et réglages restent enregistrés ; vous pourrez réactiver quand vous voulez."
                    )
                }
            }
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
            guard auxiliarySheet == nil else { return }
            guard notificationIconCropPayload == nil else { return }
            guard !isUploadingNotificationIcon else { return }
            guard !notificationLogoPopupPresented else { return }
            notificationLogoPopupPresented = true
        }
    }

    private struct FamilyAutomationDisableConfirm: Identifiable {
        let id = UUID()
        let carouselFamilyId: String
    }

    // MARK: - Sous-vues

    private var headerBlock: some View {
        DashboardHomeMinimalTopBar(
            title: "Notifications",
            merchantName: notificationsTopBarTitle,
            accountEmail: authService.currentUserEmail ?? AuthStorage.userEmail,
            notificationIconURL: dashboardSettings?.notificationIconUrl,
            hasNotificationIcon: hasCustomNotificationIconFromSettings,
            businesses: authService.businesses,
            activeBusinessSlug: AuthStorage.currentBusinessSlug,
            canCreateBusiness: authService.canCreateBusiness,
            onSelectBusiness: { slug in
                authService.selectBusiness(slug: slug)
                Task {
                    defer { authService.finishBusinessSwitch() }
                    await loadCampaignData(force: true)
                    await syncService.syncAfterServerMutation()
                    await loadCampaignData(force: true)
                }
            },
            onAddCommerce: {
                NotificationCenter.default.post(name: .myfidpassOpenAddCommerceSheet, object: nil)
            },
            onUpgradeCommerceQuota: {
                NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
            }
        )
    }

    private var notificationsTopBarTitle: String {
        let businessName = dataService.currentBusiness()?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return businessName.isEmpty ? "Notifs" : businessName
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if let err = loadError {
                errorCard(err)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            ZStack {
                BorderBeamManualNotificationComposerView(
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
                .blur(radius: campaignManualSendUnlocked ? 0 : 2.2)
                .allowsHitTesting(campaignManualSendUnlocked)

                if !campaignManualSendUnlocked {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(0.04))
                        .allowsHitTesting(false)
                    MerchantProUnlockTeaserButton(preferDarkGlassTint: false) {
                        NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
                    }
                    .accessibilityLabel("Déverrouiller avec Pro pour envoyer des notifications")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
        .padding(.bottom, 2)
    }

    private var automationsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if resolveSlugForAPI() == nil {
                syncRequiredCard
            } else {
                /// Titre + carrousel serrés (évite la double marge : paddings barre + `TabView` + padding des pages).
                VStack(alignment: .leading, spacing: 0) {
                    automationsTopBar
                    automationsCarouselBlock
                }
            }
        }
    }

    private var automationCarouselPageCount: Int {
        max(1, predefinedAutomationFamilies.count + 1)
    }

    /// Corps d’aperçu pour une famille (premier message de règle renseigné, sinon défaut).
    private func automationCarouselSampleBody(forFamilyId familyId: String) -> String {
        if familyId == "local" {
            return perimeterAutomationPreviewLine()
        }
        return firstAutomationMessageBody(forFamilyId: familyId)
    }

    /// Aperçu notif **périmètre** : uniquement `location_relevant_text`, jamais le message manuel campagne.
    private func perimeterAutomationPreviewLine() -> String {
        let t = perimeterRelevantMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return "Message affiché quand un client entre dans la zone autour de votre commerce (Apple Wallet)."
    }

    private func firstAutomationMessageBody(forFamilyId familyId: String) -> String {
        guard let family = campaignFamilies.first(where: { $0.id == familyId }) else {
            return fallbackAutomationCarouselBody()
        }
        let rules = family.rules.filter { !$0.id.hasPrefix("_info") }
        for rule in rules {
            let m = campaignAutomation.rules?[rule.id]?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !m.isEmpty { return String(m.prefix(220)) }
        }
        if let first = rules.first, let def = defaultRuleMessages[first.id] { return def }
        return fallbackAutomationCarouselBody()
    }

    private func effectiveRulesFamilyId(forCarouselFamilyId id: String) -> String {
        id
    }

    /// Première règle éditable pour le message affiché dans le bandeau du carrousel.
    private func primaryRuleIdForCarousel(familyIdForPreview: String) -> String? {
        let fid = effectiveRulesFamilyId(forCarouselFamilyId: familyIdForPreview)
        guard let family = campaignFamilies.first(where: { $0.id == fid }) else { return nil }
        let rules = family.rules.filter { !$0.id.hasPrefix("_info") }
        guard !rules.isEmpty else { return nil }
        for rule in rules {
            let m = campaignAutomation.rules?[rule.id]?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !m.isEmpty { return rule.id }
        }
        return rules.first?.id
    }

    private func isFamilyAutomationActive(carouselFamilyId: String) -> Bool {
        let fid = effectiveRulesFamilyId(forCarouselFamilyId: carouselFamilyId)
        guard let family = campaignFamilies.first(where: { $0.id == fid }) else { return false }
        return family.rules.contains { !$0.id.hasPrefix("_info") && (campaignAutomation.rules?[$0.id]?.enabled == true) }
    }

    /// Active ou désactive toutes les règles de la famille (messages défaut si besoin).
    private func setFamilyAutomationEnabled(carouselFamilyId: String, enabled: Bool) {
        let fid = effectiveRulesFamilyId(forCarouselFamilyId: carouselFamilyId)
        guard let family = campaignFamilies.first(where: { $0.id == fid }) else { return }
        var r = campaignAutomation.rules ?? [:]
        for rule in family.rules where !rule.id.hasPrefix("_info") {
            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultRuleMessages[rule.id] ?? "")
            row.enabled = enabled
            if enabled, row.message == nil || row.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                row.message = defaultRuleMessages[rule.id] ?? row.message
            }
            r[rule.id] = row
        }
        campaignAutomation.rules = r
        scheduleCampaignAutomationSave()
        if fid == "local" {
            // Le toggle localisation contrôle aussi l’envoi du message périmètre serveur.
            schedulePerimeterRelevantTextSave()
        }
    }

    private func carouselMessageBinding(ruleId: String?) -> Binding<String>? {
        guard let ruleId else { return nil }
        return Binding(
            get: {
                let m = campaignAutomation.rules?[ruleId]?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !m.isEmpty { return String(m.prefix(200)) }
                return defaultRuleMessages[ruleId] ?? ""
            },
            set: { v in
                var r = campaignAutomation.rules ?? [:]
                var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
                row.message = String(v.prefix(200))
                r[ruleId] = row
                campaignAutomation.rules = r
                scheduleCampaignAutomationSave()
            }
        )
    }

    private func carouselPerimeterMessageBinding() -> Binding<String>? {
        guard resolveSlugForAPI() != nil else { return nil }
        return Binding(
            get: {
                String(perimeterRelevantMessageText.replacingOccurrences(of: "\n", with: "").prefix(200))
            },
            set: { v in
                let flattened = v.replacingOccurrences(of: "\n", with: "")
                perimeterRelevantMessageText = String(flattened.prefix(200))
                isPerimeterRelevantTextDirty = true
                schedulePerimeterRelevantTextSave()
            }
        )
    }

    /// Repli **uniquement** pour les cartes automatisations du carrousel — ne pas utiliser `bodyText` (campagnes manuelles).
    private func fallbackAutomationCarouselBody() -> String {
        "Exemple : texte sur le pass au moment où l’automatisation se déclenche."
    }

    @ViewBuilder
    private func automationCarouselPageStack(
        pageIndex: Int,
        familyIdForPreview: String,
        accent: Color,
        summaryFamilyId: String
    ) -> some View {
        let active = isFamilyAutomationActive(carouselFamilyId: summaryFamilyId)
        let ruleId = primaryRuleIdForCarousel(familyIdForPreview: familyIdForPreview)
        ZStack(alignment: .top) {
            automationSummaryCard(
                accent: accent,
                isActive: active,
                familyId: summaryFamilyId,
                onToggleActive: {
                    if active {
                        familyAutomationDisableConfirm = FamilyAutomationDisableConfirm(carouselFamilyId: summaryFamilyId)
                    } else {
                        setFamilyAutomationEnabled(carouselFamilyId: summaryFamilyId, enabled: true)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            )
            .zIndex(0)

            AutomationCarouselLiquidNotificationBanner(
                senderTitle: effectiveCampaignNotificationSenderLine,
                messageBody: automationCarouselSampleBody(forFamilyId: familyIdForPreview),
                messageBinding: carouselMessageBinding(ruleId: ruleId),
                logoURL: notificationPreviewIconURLForView,
                pageIndex: pageIndex,
                currentPage: automationCarouselPage
            )
            .id(notificationIconReloadNonce)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .zIndex(1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Aperçu notification pour cette automatisation")
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    @ViewBuilder
    private func automationPerimeterPageStack(pageIndex: Int, carouselSelection: Int) -> some View {
        let trimmedPerimeter = perimeterRelevantMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasPerimeterMessage = !trimmedPerimeter.isEmpty
        let rulesActive = isFamilyAutomationActive(carouselFamilyId: "local")
        /// Les règles peuvent être « on » par défaut sans texte Wallet : l’UI « Activé » exige un vrai message périmètre.
        let showsActivé = rulesActive && hasPerimeterMessage
        /// Désactivé seulement sans message et sans règle à couper (état incohérent rules on + texte vide → tap pour éteindre).
        let perimeterButtonEnabled = hasPerimeterMessage || rulesActive
        let corner = RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
        ZStack(alignment: .top) {
            localWalletMapSection(
                cardHeight: 236,
                isLiveElevationMapActive: carouselSelection == pageIndex,
                showsActivé: showsActivé,
                isButtonEnabled: perimeterButtonEnabled,
                onToggleActive: {
                    guard perimeterButtonEnabled else { return }
                    if showsActivé {
                        familyAutomationDisableConfirm = FamilyAutomationDisableConfirm(carouselFamilyId: "local")
                    } else if rulesActive && !hasPerimeterMessage {
                        setFamilyAutomationEnabled(carouselFamilyId: "local", enabled: false)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } else if !rulesActive && hasPerimeterMessage {
                        setFamilyAutomationEnabled(carouselFamilyId: "local", enabled: true)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                }
            )
                .zIndex(0)

            AutomationCarouselLiquidNotificationBanner(
                senderTitle: effectiveCampaignNotificationSenderLine,
                messageBody: automationCarouselSampleBody(forFamilyId: "local"),
                messageBinding: carouselPerimeterMessageBinding(),
                textFieldPlaceholder: "Message périmètre (géolocalisation Wallet)…",
                logoURL: notificationPreviewIconURLForView,
                pageIndex: pageIndex,
                currentPage: automationCarouselPage,
                useMultilineMessageField: false,
                onSubmitActivate: {
                    let msg = perimeterRelevantMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !msg.isEmpty else { return }
                    // Déjà actif (règles + message) : la touche ✓ ne fait que fermer le clavier.
                    guard !(rulesActive && hasPerimeterMessage) else { return }
                    setFamilyAutomationEnabled(carouselFamilyId: "local", enabled: true)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            )
            .id(notificationIconReloadNonce)
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .zIndex(1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Aperçu notification dans le périmètre")
        }
        .clipShape(corner)
        .overlay(
            corner
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }

    /// Carrousel : notif liquid glass superposée à la carte, swipe fluide + indicateurs.
    private var automationsCarouselBlock: some View {
        let tabH: CGFloat = 318
        return VStack(alignment: .leading, spacing: 12) {
            TabView(selection: $automationCarouselPage) {
                automationPerimeterPageStack(pageIndex: 0, carouselSelection: automationCarouselPage)
                    .tag(0)
                ForEach(Array(predefinedAutomationFamilies.enumerated()), id: \.element.id) { index, family in
                    automationCarouselPageStack(
                        pageIndex: index + 1,
                        familyIdForPreview: family.id,
                        accent: familyThemeColor(family.id),
                        summaryFamilyId: family.id
                    )
                    .tag(index + 1)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            /// Le style page réserve souvent ~10–14 pt en haut même sans indicateur système — on le compense.
            .padding(.top, -20)
            .frame(height: tabH)

            HStack(spacing: 0) {
                ForEach(0..<automationCarouselPageCount, id: \.self) { i in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { automationCarouselPage = i }
                    } label: {
                        Capsule()
                            .fill(i == automationCarouselPage ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary.opacity(0.28))
                            .frame(width: i == automationCarouselPage ? 22 : 6, height: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Automatisations, page \(automationCarouselPage + 1) sur \(automationCarouselPageCount)")
        }
        .onChange(of: predefinedAutomationFamilies.count) { _, _ in
            let maxPage = max(0, automationCarouselPageCount - 1)
            if automationCarouselPage > maxPage {
                automationCarouselPage = maxPage
            }
        }
        .onChange(of: automationCarouselPage) { _, newPage in
            guard newPage != lastCarouselHapticPage else { return }
            lastCarouselHapticPage = newPage
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private var automationsTopBar: some View {
        HStack(alignment: .center) {
            Text("Notifications automatiques")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer(minLength: 8)
        }
        .padding(.top, 6)
        .padding(.bottom, -10)
    }

    private func automationSummaryTitleLines(for familyId: String) -> (String, String) {
        switch familyId {
        case "reactivation":
            return ("Client inactif", "+14 jours")
        case "birthday":
            return ("Anniversaire", "aujourd’hui")
        default:
            return (familyHeroTitle(familyId), "")
        }
    }

    private func automationSummaryActivateIconName(familyId: String, isActive: Bool) -> String {
        if isActive { return "checkmark.circle.fill" }
        switch familyId {
        case "reactivation":
            return "arrow.counterclockwise.circle.fill"
        case "birthday":
            return "gift.fill"
        default:
            return "play.circle.fill"
        }
    }

    private func automationSummaryCard(
        accent: Color,
        isActive: Bool,
        familyId: String,
        onToggleActive: @escaping () -> Void
    ) -> some View {
        let backgroundAssetName: String? = {
            switch familyId {
            case "reactivation":
                return "AutoRelance"
            case "birthday":
                return "anniv"
            default:
                return nil
            }
        }()
        let cardHeight: CGFloat = 236
        let corner = AppTheme.Radius.lg
        return VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 52)

            HStack(alignment: .center, spacing: 8) {
                Button(action: onToggleActive) {
                    HStack(spacing: 5) {
                        Image(systemName: isActive ? "checkmark.circle.fill" : automationSummaryActivateIconName(familyId: familyId, isActive: false))
                            .font(.system(size: 13, weight: .semibold))
                        Text(isActive ? "Activé" : "Activer")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                    }
                    .foregroundStyle(isActive ? Color.green : AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .modifier(LiquidGlassCapsuleButtonModifier(controlSize: .small))

                Spacer(minLength: 0)
            }
        }
        .padding(.leading, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .top)
        .background {
            if let backgroundAssetName {
                Image(backgroundAssetName)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.34), Color.black.opacity(0.22), AppTheme.Colors.cardBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    LinearGradient(
                        colors: [Color.black.opacity(0.68), Color.black.opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .clear, radius: 0, y: 0)
    }

    private var predefinedAutomationFamilies: [CampaignFamilySpec] {
        campaignFamilies.filter { family in
            family.id != "local"
                && family.rules.contains(where: { !$0.id.hasPrefix("_info") })
        }
    }

    private var customRuleIds: [String] {
        (campaignAutomation.rules ?? [:]).keys.filter { $0.hasPrefix("custom_") }.sorted()
    }

    private var eventRuleIds: [String] {
        (campaignAutomation.rules ?? [:]).keys.filter { $0.hasPrefix("event_") }.sorted()
    }

    private var customAutomationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Automatisations personnalisées")
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer(minLength: 8)
                if #available(iOS 26.0, *) {
                    Button {
                        prepareNewCustomAutomation()
                    } label: {
                        Label("Nouvelle", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                } else {
                    Button {
                        prepareNewCustomAutomation()
                    } label: {
                        Label("Nouvelle", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                }
            }
            if !customRuleIds.isEmpty {
                ForEach(customRuleIds, id: \.self) { rid in
                    customAutomationRow(ruleId: rid)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    private var eventAutomationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("Créer une automatisation")
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Spacer(minLength: 8)
                if #available(iOS 26.0, *) {
                    Button {
                        prepareNewEventAutomation()
                    } label: {
                        Label("Nouvelle", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                } else {
                    Button {
                        prepareNewEventAutomation()
                    } label: {
                        Label("Nouvelle", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                }
            }
            if !eventRuleIds.isEmpty {
                ForEach(eventRuleIds, id: \.self) { rid in
                    eventAutomationRow(ruleId: rid)
                }
            }
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
    }

    private func customAutomationRow(ruleId: String) -> some View {
        let rawTitle = campaignAutomation.rules?[ruleId]?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = rawTitle.isEmpty ? "Automatisation" : rawTitle
        let seg = campaignAutomation.rules?[ruleId]?.segment ?? ""
        let segLabel = manualSegmentChoices.first(where: { $0.key == seg })?.label ?? seg
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(AppTheme.Fonts.subheadline())
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(segLabel)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if let n = segmentCount(for: seg), !seg.isEmpty {
                        Text("\(n)")
                            .font(AppTheme.Fonts.caption())
                            .fontWeight(.semibold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(AppTheme.Colors.primary.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { campaignAutomation.rules?[ruleId]?.enabled ?? false },
                set: { on in
                    var r = campaignAutomation.rules ?? [:]
                    var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
                    row.enabled = on
                    r[ruleId] = row
                    campaignAutomation.rules = r
                    scheduleCampaignAutomationSave()
                }
            ))
            .labelsHidden()
            .tint(AppTheme.Colors.primary)
            if #available(iOS 26.0, *) {
                Button {
                    openEditCustomAutomation(ruleId: ruleId)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.small)
                Button {
                    customRulePendingDelete = ruleId
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.small)
            } else {
                Button {
                    openEditCustomAutomation(ruleId: ruleId)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                Button {
                    customRulePendingDelete = ruleId
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private var customAutomationEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom (ex. : Relance VIP)", text: $customDraftTitle)
                    Picker("Segment cible", selection: $customDraftSegment) {
                        ForEach(manualSegmentChoices, id: \.key) { c in
                            Text(c.label).tag(c.key)
                        }
                    }
                    .onChange(of: customDraftSegment) { _, newSeg in
                        if customDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let hint = defaultMessages[newSeg] {
                            customDraftMessage = hint
                        }
                    }
                } header: {
                    Text("Règle")
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $customDraftMessage)
                            .frame(minHeight: 140)
                        Text("\(customDraftMessage.count)/200 caractères max. côté serveur.")
                            .font(AppTheme.Fonts.caption2())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                } header: {
                    Text("Message sur le pass")
                }
            }
            .navigationTitle(customRuleBeingEdited == nil ? "Nouvelle automatisation" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        auxiliarySheet = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveCustomAutomationDraft()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSaveCustomDraft)
                }
            }
        }
    }

    private var eventAutomationEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Décrivez l’automatisation souhaitée…", text: $eventDraftAIInstruction, axis: .vertical)
                        .lineLimit(2 ... 4)
                    Button {
                        Task { await parseEventDraftWithAI() }
                    } label: {
                        HStack {
                            if isEventDraftAIParsing { ProgressView() }
                            Image(systemName: "wand.and.stars")
                            Text(isEventDraftAIParsing ? "Analyse IA…" : "Générer la règle avec IA")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isEventDraftAIParsing || eventDraftAIInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } header: {
                    Text("Assistant IA")
                }

                Section {
                    TextField("Nom (ex. : Bienvenue +2min)", text: $eventDraftTitle)
                    Picker("Déclencheur", selection: $eventDraftPreset) {
                        ForEach(EventPreset.allCases, id: \.self) { preset in
                            Text(preset.label).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: eventDraftPreset) { _, preset in
                        guard preset == .inactiveDays else { return }
                        let t = eventDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
                        if t.isEmpty || t == "Bienvenue ! Votre carte est prête." {
                            eventDraftMessage = defaultInactiveRelancePromoMessage
                        }
                    }

                    if eventDraftPreset == .inactiveDays {
                        Stepper(value: $eventDraftInactiveDays, in: 1 ... 365, step: 1) {
                            Text("Inactif depuis \(eventDraftInactiveDays) jour(s)")
                        }
                    }

                    if eventDraftPreset == .dailyAt {
                        HStack(spacing: 8) {
                            Stepper(value: $eventDraftScheduleHour, in: 0 ... 23, step: 1) {
                                Text("Heure: \(String(format: "%02d", eventDraftScheduleHour))h")
                            }
                        }
                        HStack(spacing: 8) {
                            Stepper(value: $eventDraftScheduleMinute, in: 0 ... 59, step: 5) {
                                Text("Minute: \(String(format: "%02d", eventDraftScheduleMinute))")
                            }
                        }
                    }

                    if eventDraftPreset == .custom {
                        TextField("Clé événement perso (ex: birthday_7d)", text: $eventDraftCustomKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }

                    Stepper(value: $eventDraftDelayMinutes, in: 1 ... 120, step: 1) {
                        Text("Délai : \(eventDraftDelayMinutes) minute(s)")
                    }
                } header: {
                    Text("Règle")
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $eventDraftMessage)
                            .frame(minHeight: 140)
                        Text("\(eventDraftMessage.count)/200 caractères max. côté serveur.")
                            .font(AppTheme.Fonts.caption2())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                } header: {
                    Text("Message sur le pass")
                }
            }
            .navigationTitle(eventAutomationsRuleBeingEdited == nil ? "Nouvelle automatisation événementielle" : "Modifier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if #available(iOS 26.0, *) {
                        Button("Annuler") {
                            auxiliarySheet = nil
                        }
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    } else {
                        Button("Annuler") {
                            auxiliarySheet = nil
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if #available(iOS 26.0, *) {
                        Button("Enregistrer") {
                            saveEventAutomationDraft()
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSaveEventDraft)
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    } else {
                        Button("Enregistrer") {
                            saveEventAutomationDraft()
                        }
                        .fontWeight(.semibold)
                        .disabled(!canSaveEventDraft)
                    }
                }
            }
        }
    }

    private var canSaveEventDraft: Bool {
        let msg = eventDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = eventDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if eventDraftPreset == .custom {
            let custom = sanitizeCustomEventKey(eventDraftCustomKey)
            return !msg.isEmpty && !tit.isEmpty && !custom.isEmpty && eventDraftDelayMinutes > 0
        }
        return !msg.isEmpty && !tit.isEmpty && eventDraftDelayMinutes > 0
    }

    private var canSaveCustomDraft: Bool {
        let msg = customDraftMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = customDraftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return !msg.isEmpty && !customDraftSegment.isEmpty && !tit.isEmpty
    }

    private func prepareNewCustomAutomation() {
        customRuleBeingEdited = nil
        customDraftTitle = ""
        let firstSeg = manualSegmentChoices.first?.key ?? "inactive14"
        customDraftSegment = firstSeg
        customDraftMessage = defaultMessages[firstSeg] ?? ""
        auxiliarySheet = .customAutomation
    }

    private func prepareNewEventAutomation() {
        eventAutomationsRuleBeingEdited = nil
        eventDraftTitle = ""
        eventDraftEventType = "member_created"
        eventDraftPreset = .memberCreated
        eventDraftInactiveDays = 30
        eventDraftScheduleHour = 10
        eventDraftScheduleMinute = 0
        eventDraftCustomKey = ""
        eventDraftDelayMinutes = 2
        eventDraftMessage = "Bienvenue ! Votre carte est prête."
        eventDraftAIInstruction = ""
        auxiliarySheet = .eventAutomation
    }

    private func openEditEventAutomation(ruleId: String) {
        eventAutomationsRuleBeingEdited = ruleId
        let row = campaignAutomation.rules?[ruleId]
        eventDraftTitle = row?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        eventDraftEventType = row?.eventType ?? "member_created"
        hydrateEventDraft(from: eventDraftEventType)
        eventDraftDelayMinutes = row?.delayMinutes ?? 2
        eventDraftMessage = row?.message ?? ""
        eventDraftAIInstruction = ""
        auxiliarySheet = .eventAutomation
    }

    private func saveEventAutomationDraft() {
        let msg = String(eventDraftMessage.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = String(eventDraftTitle.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        let delay = max(1, Int(eventDraftDelayMinutes))
        let et = resolvedEventTypeForDraft()
        guard !msg.isEmpty, !tit.isEmpty, !et.isEmpty else { return }

        let key = eventAutomationsRuleBeingEdited ?? "event_\(UUID().uuidString)"
        var r = campaignAutomation.rules ?? [:]
        let existing = r[key]
        let row = CampaignAutomationRuleDTO(
            enabled: existing?.enabled ?? true,
            message: msg,
            segment: nil,
            title: tit,
            eventType: et,
            delayMinutes: delay
        )
        r[key] = row
        campaignAutomation.rules = r
        auxiliarySheet = nil
        eventAutomationsRuleBeingEdited = nil
        scheduleCampaignAutomationSave()
    }

    private func removeEventRule(id: String) {
        var r = campaignAutomation.rules ?? [:]
        r.removeValue(forKey: id)
        campaignAutomation.rules = r
        scheduleCampaignAutomationSave()
    }

    private func eventAutomationRow(ruleId: String) -> some View {
        let rawTitle = campaignAutomation.rules?[ruleId]?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = rawTitle.isEmpty ? "Automatisation événementielle" : rawTitle
        let delay = campaignAutomation.rules?[ruleId]?.delayMinutes ?? 2
        let eventType = campaignAutomation.rules?[ruleId]?.eventType ?? "member_created"
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(displayTitle)
                    .font(AppTheme.Fonts.subheadline())
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(readableEventLabel(for: eventType))
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("+\(delay) min")
                        .font(AppTheme.Fonts.caption())
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.primary.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { campaignAutomation.rules?[ruleId]?.enabled ?? false },
                set: { on in
                    var r = campaignAutomation.rules ?? [:]
                    var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
                    row.enabled = on
                    r[ruleId] = row
                    campaignAutomation.rules = r
                    scheduleCampaignAutomationSave()
                }
            ))
            .labelsHidden()
            .tint(AppTheme.Colors.primary)

            if #available(iOS 26.0, *) {
                Button {
                    openEditEventAutomation(ruleId: ruleId)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.small)

                Button {
                    eventRulePendingDelete = ruleId
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.circle)
                .controlSize(.small)
            } else {
                Button {
                    openEditEventAutomation(ruleId: ruleId)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)

                Button {
                    eventRulePendingDelete = ruleId
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    private enum EventPreset: String, CaseIterable {
        case memberCreated
        case firstCardScan
        case rewardUnlocked
        case inactiveDays
        case dailyAt
        case custom

        var label: String {
            switch self {
            case .memberCreated: return "Carte ajoutée"
            case .firstCardScan: return "Premier scan"
            case .rewardUnlocked: return "Récompense débloquée"
            case .inactiveDays: return "Inactif depuis X jours"
            case .dailyAt: return "Tous les jours à heure fixe"
            case .custom: return "Événement personnalisé"
            }
        }
    }

    private func hydrateEventDraft(from rawEventType: String) {
        let raw = rawEventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("inactive_days:") {
            eventDraftPreset = .inactiveDays
            let value = raw.replacingOccurrences(of: "inactive_days:", with: "")
            eventDraftInactiveDays = max(1, min(365, Int(value) ?? 30))
            return
        }
        if raw.hasPrefix("daily_at:") {
            eventDraftPreset = .dailyAt
            let value = raw.replacingOccurrences(of: "daily_at:", with: "")
            let comps = value.split(separator: ":")
            if comps.count == 2 {
                eventDraftScheduleHour = max(0, min(23, Int(comps[0]) ?? 10))
                eventDraftScheduleMinute = max(0, min(59, Int(comps[1]) ?? 0))
            }
            return
        }
        switch raw {
        case "member_created":
            eventDraftPreset = .memberCreated
        case "first_scan":
            eventDraftPreset = .firstCardScan
        case "reward_unlocked":
            eventDraftPreset = .rewardUnlocked
        default:
            eventDraftPreset = .custom
            eventDraftCustomKey = rawEventType
        }
    }

    private func sanitizeCustomEventKey(_ raw: String) -> String {
        let filtered = raw.lowercased().map { ch -> Character in
            if ch.isLetter || ch.isNumber || ch == "_" || ch == "-" { return ch }
            return "_"
        }
        let collapsed = String(filtered)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_- "))
        return String(collapsed.prefix(48))
    }

    private func resolvedEventTypeForDraft() -> String {
        switch eventDraftPreset {
        case .memberCreated:
            return "member_created"
        case .firstCardScan:
            return "first_scan"
        case .rewardUnlocked:
            return "reward_unlocked"
        case .inactiveDays:
            return "inactive_days:\(max(1, min(365, eventDraftInactiveDays)))"
        case .dailyAt:
            let hh = String(format: "%02d", max(0, min(23, eventDraftScheduleHour)))
            let mm = String(format: "%02d", max(0, min(59, eventDraftScheduleMinute)))
            return "daily_at:\(hh):\(mm)"
        case .custom:
            return sanitizeCustomEventKey(eventDraftCustomKey)
        }
    }

    private func readableEventLabel(for eventType: String) -> String {
        let raw = eventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("inactive_days:") {
            let value = raw.replacingOccurrences(of: "inactive_days:", with: "")
            let n = max(1, Int(value) ?? 30)
            return "Inactif depuis \(n)j"
        }
        if raw.hasPrefix("daily_at:") {
            let value = raw.replacingOccurrences(of: "daily_at:", with: "")
            return "Chaque jour à \(value)"
        }
        switch raw {
        case "member_created":
            return "Carte ajoutée"
        case "first_scan":
            return "Premier scan"
        case "reward_unlocked":
            return "Récompense débloquée"
        default:
            return eventType.isEmpty ? "Événement" : eventType
        }
    }

    private func applyAIParsedEventDraft(
        title: String,
        message: String,
        eventType: String,
        delayMinutes: Int
    ) {
        eventDraftTitle = String(title.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        eventDraftMessage = String(message.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        eventDraftDelayMinutes = max(1, min(1440, delayMinutes))
        eventDraftEventType = eventType
        hydrateEventDraft(from: eventType)
    }

    @MainActor
    private func parseEventDraftWithAI() async {
        let instruction = eventDraftAIInstruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !instruction.isEmpty else { return }
        guard let slug = resolveSlugForAPI() else { return }
        isEventDraftAIParsing = true
        defer {
            isEventDraftAIParsing = false
        }
        do {
            let body = CampaignAutomationAIParseRequestDTO(instruction: instruction)
            let parsed = try await APIClient.shared.request(
                .dashboardCampaignAutomationParse(slug: slug, body: body)
            ) as CampaignAutomationAIParseResponseDTO
            let title = parsed.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = parsed.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let eventType = parsed.eventType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let delay = parsed.delayMinutes ?? 2
            guard !title.isEmpty, !message.isEmpty, !eventType.isEmpty else { return }
            applyAIParsedEventDraft(
                title: title,
                message: message,
                eventType: eventType,
                delayMinutes: delay
            )
        } catch {
            message = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func openEditCustomAutomation(ruleId: String) {
        customRuleBeingEdited = ruleId
        let row = campaignAutomation.rules?[ruleId]
        customDraftTitle = row?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        customDraftSegment = row?.segment ?? manualSegmentChoices.first?.key ?? "inactive14"
        customDraftMessage = row?.message ?? ""
        auxiliarySheet = .customAutomation
    }

    private func saveCustomAutomationDraft() {
        let msg = String(customDraftMessage.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = String(customDraftTitle.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !tit.isEmpty, !customDraftSegment.isEmpty else { return }
        let key = customRuleBeingEdited ?? "custom_\(UUID().uuidString)"
        var r = campaignAutomation.rules ?? [:]
        let existing = r[key]
        let row = CampaignAutomationRuleDTO(
            enabled: existing?.enabled ?? true,
            message: msg,
            segment: customDraftSegment,
            title: tit
        )
        r[key] = row
        campaignAutomation.rules = r
        auxiliarySheet = nil
        customRuleBeingEdited = nil
        scheduleCampaignAutomationSave()
    }

    private func removeCustomRule(id: String) {
        var r = campaignAutomation.rules ?? [:]
        r.removeValue(forKey: id)
        campaignAutomation.rules = r
        scheduleCampaignAutomationSave()
    }

    private func localWalletMapSection(
        cardHeight: CGFloat = 204,
        isLiveElevationMapActive: Bool,
        showsActivé: Bool,
        isButtonEnabled: Bool,
        onToggleActive: @escaping () -> Void
    ) -> some View {
        return ZStack(alignment: .bottomLeading) {
            LocalAutomationReliefMapBackdrop(
                latitude: dashboardSettings?.locationLat,
                longitude: dashboardSettings?.locationLng,
                radiusMeters: dashboardSettings?.locationRadiusMeters,
                isLiveElevationMapActive: isLiveElevationMapActive
            )

            Button {
                showPerimeterMapSheet = true
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ouvrir la carte et le périmètre")

            Button(action: onToggleActive) {
                HStack(spacing: 5) {
                    Image(systemName: showsActivé ? "checkmark.circle.fill" : "location.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(showsActivé ? "Activé" : "Activer")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                }
                .foregroundStyle(showsActivé ? Color.green : (isButtonEnabled ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .modifier(LiquidGlassCapsuleButtonModifier(controlSize: .small))
            .disabled(!isButtonEnabled)
            .opacity(isButtonEnabled ? 1 : 0.48)
            // Aligné sur `automationSummaryCard` : padding carte 14 + leading interne 12 pour le bloc « Activer ».
            .padding(.leading, 26)
            // Légèrement plus haut que le bas strict (14) des autres cartes — repère visuel carte carte.
            .padding(.bottom, 18)
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .clear, radius: 0, y: 0)
    }

    private func familyCard(_ family: CampaignFamilySpec) -> some View {
        let activeCount = family.rules.filter { (campaignAutomation.rules?[$0.id]?.enabled ?? false) }.count
        let totalCount = family.rules.count
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            familyThemeColor(family.id).opacity(0.34),
                            Color.black.opacity(0.22),
                            AppTheme.Colors.cardBackground
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            LinearGradient(
                colors: [Color.black.opacity(0.68), Color.black.opacity(0.3), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    Text(familyHeroTitle(family.id))
                        .font(.system(size: 22, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text("\(activeCount)/\(totalCount)")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.36), in: Capsule())
                }

                VStack(spacing: 8) {
                    ForEach(family.rules) { rule in
                        ruleRow(rule, socialAvisStyle: false)
                    }
                }
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .clear, radius: 0, y: 0)
    }

    private func ruleRow(_ rule: CampaignRuleSpec, socialAvisStyle: Bool) -> some View {
        Group {
            if rule.id.hasPrefix("_info") {
                EmptyView()
            } else if socialAvisStyle {
                HStack(alignment: .center, spacing: 12) {
                    campaignSocialRowLeading(ruleId: rule.id)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rule.title)
                            .font(.system(size: 16, weight: .semibold, design: .default))
                            .foregroundStyle(Color.black)
                        Text(rule.subtitle)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(Color(white: 0.38))
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: Binding(
                        get: { campaignAutomation.rules?[rule.id]?.enabled ?? false },
                        set: { on in
                            var r = campaignAutomation.rules ?? [:]
                            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultRuleMessages[rule.id] ?? "")
                            row.enabled = on
                            if row.message == nil || row.message?.isEmpty == true {
                                row.message = defaultRuleMessages[rule.id]
                            }
                            r[rule.id] = row
                            campaignAutomation.rules = r
                            scheduleCampaignAutomationSave()
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.9)
                )
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(rule.title)
                                .font(AppTheme.Fonts.subheadline())
                                .fontWeight(.medium)
                                .foregroundStyle(.white)
                            if let k = rule.segmentKey, let n = segmentCount(for: k) {
                                Text("\(n)")
                                    .font(AppTheme.Fonts.caption())
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(rule.subtitle)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: Binding(
                        get: { campaignAutomation.rules?[rule.id]?.enabled ?? false },
                        set: { on in
                            var r = campaignAutomation.rules ?? [:]
                            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultRuleMessages[rule.id] ?? "")
                            row.enabled = on
                            if row.message == nil || row.message?.isEmpty == true {
                                row.message = defaultRuleMessages[rule.id]
                            }
                            r[rule.id] = row
                            campaignAutomation.rules = r
                            scheduleCampaignAutomationSave()
                        }
                    ))
                    .labelsHidden()
                    .tint(AppTheme.Colors.primary)
                    editRuleGlassButton(ruleId: rule.id)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func campaignSocialRowLeading(ruleId: String) -> some View {
        let s: CGFloat = 28
        switch ruleId {
        case "social_google":
            Image("SocialGoogle")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_instagram":
            Image("SocialInstagram")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_tiktok":
            Image("SocialTikTok")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_facebook":
            Image("SocialFacebook")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_x":
            Image(systemName: "x.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(.black)
                .frame(width: s, height: s)
        case "social_snapchat":
            Image("SocialSnapchat")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_linkedin":
            Image("SocialLinkedIn")
                .resizable()
                .scaledToFit()
                .frame(width: s, height: s)
        case "social_youtube":
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.red)
                .frame(width: s, height: s)
        default:
            Image(systemName: "globe")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.black)
                .frame(width: s, height: s)
        }
    }

    private func familyHeroTitle(_ familyId: String) -> String {
        switch familyId {
        case "reactivation":
            return "Client inactif +14 jours"
        case "birthday":
            return "Anniversaire"
        default:
            return "Automatisation"
        }
    }

    /// Libellé court pour les confirmations (carrousel).
    private func automationFamilyDisplayName(for carouselFamilyId: String) -> String {
        switch carouselFamilyId {
        case "local":
            return "Notification dans le périmètre"
        case "reactivation":
            return "Client inactif +14 jours"
        case "birthday":
            return "Anniversaire"
        default:
            return "Ce bloc"
        }
    }

    private func familyThemeColor(_ familyId: String) -> Color {
        switch familyId {
        case "reactivation":
            return Color.orange
        case "birthday":
            return Color(red: 0.92, green: 0.35, blue: 0.55)
        default:
            return AppTheme.Colors.primary
        }
    }

    @ViewBuilder
    private func editRuleGlassButton(ruleId: String) -> some View {
        if #available(iOS 26.0, *) {
            Button {
                auxiliarySheet = .ruleEditor(ruleId)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.glass(.regular))
            .buttonBorderShape(.circle)
            .controlSize(.small)
        } else {
            Button {
                auxiliarySheet = .ruleEditor(ruleId)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
        }
    }

    private func segmentCount(for key: String) -> Int? {
        guard let s = segments else { return nil }
        switch key {
        case "inactive14": return s.inactive14
        case "inactive30": return s.inactive30
        case "inactive60": return s.inactive60
        case "inactive90": return s.inactive90
        case "new7": return s.new7
        case "new30": return s.new30
        case "welcomeNew": return s.welcomeNew
        case "pointsNear50": return s.pointsNear50
        case "points50": return s.points50
        case "recurrent": return s.recurrent
        case "birthdayToday": return s.birthdayToday
        default: return nil
        }
    }

    private var cronHintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Automatisation serveur", systemImage: "server.rack")
                .font(AppTheme.Fonts.subheadline())
                .fontWeight(.medium)
            Text("Les automatisations par segment sont traitées environ une fois par jour. Les automatisations événementielles (carte / nouveau membre) sont traitées environ toutes les minutes. Il faut un canal actif (Apple Wallet enregistré sur l’appareil ou Web Push) pour recevoir l’alerte ; sinon le serveur réessaie automatiquement.")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
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

    private func ruleEditSheet(ruleId: String) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Message affiché sur le pass (corps de la notification).")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextEditor(text: Binding(
                    get: { campaignAutomation.rules?[ruleId]?.message ?? defaultRuleMessages[ruleId] ?? "" },
                    set: { v in
                        var r = campaignAutomation.rules ?? [:]
                        var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: v)
                        row.message = String(v.prefix(200))
                        r[ruleId] = row
                        campaignAutomation.rules = r
                        scheduleCampaignAutomationSave()
                    }
                ))
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                Spacer()
            }
            .padding()
            .navigationTitle(ruleTitle(for: ruleId))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { auxiliarySheet = nil }
                }
            }
        }
    }

    private func ruleTitle(for id: String) -> String {
        if (id.hasPrefix("custom_") || id.hasPrefix("event_")),
           let t = campaignAutomation.rules?[id]?.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !t.isEmpty {
            return t
        }
        for f in campaignFamilies {
            if let r = f.rules.first(where: { $0.id == id }) { return r.title }
        }
        return "Message"
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
            patch.campaignAutomation = campaignAutomation
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
        } catch {
            if !shouldSuppressCancelledNetworkNoise(error) {
                message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
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
            let localEnabled = campaignAutomation.rules?["locationEntry"]?.enabled ?? true
            patch.locationRelevantText = localEnabled ? (t.isEmpty ? nil : String(t.prefix(200))) : nil
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            isPerimeterRelevantTextDirty = false
            await syncService.syncAfterServerMutation()
        } catch {
            if !shouldSuppressCancelledNetworkNoise(error) {
                message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
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
            var patch = FullDashboardSettingsPatch()
            let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let b = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
            patch.notificationTitleOverride = t.isEmpty ? nil : String(t.prefix(80))
            if clearAfterSend && b.isEmpty {
                patch.clearNotificationChangeMessage = true
            } else {
                patch.notificationChangeMessage = b.isEmpty ? nil : String(b.prefix(200))
            }
            _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
            return true
        } catch {
            if shouldSuppressCancelledNetworkNoise(error) { return false }
            if !isNotificationSendInFlight {
                message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            return false
        }
    }

    /// Chargement initial optimisé : settings + segments en parallèle pour réduire la latence perçue.
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
            async let settingsReq: BusinessSettingsResponse = APIClient.shared.request(.businessSettings(slug: slug))
            async let segmentsReq: CampaignSegmentsResponse = APIClient.shared.request(.dashboardNotificationSegments(slug: slug))
            let (gotSettings, gotSeg) = try await (settingsReq, segmentsReq)
            ScanFlowSettingsCache.store(gotSettings, for: slug)
            CampaignNotificationImageCache.applyPreviewTimestamps(from: gotSettings, slug: slug)
            dashboardSettings = gotSettings
            prewarmNotificationIconIfPossible(slug: slug, settings: gotSettings)
            if !shouldDeferCampaignDataReloadDuringEdit {
                perimeterRelevantMessageText = gotSettings.locationRelevantText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                isPerimeterRelevantTextDirty = false
            }
            segments = gotSeg
            campaignAutomation = mergedAutomation(from: gotSettings.campaignAutomation)
            isApplyingRemoteSettings = true
            let t = gotSettings.notificationTitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = t
            }
            if bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !keepManualMessageFieldClearedAfterSend {
                let hint = gotSettings.notificationChangeMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !hint.isEmpty { bodyText = hint }
            }
            isApplyingRemoteSettings = false
            loadError = nil
            isLoadingData = false
            lastCampaignDataLoadAt = Date()
            lastCampaignDataSlug = slug
        } catch {
            if shouldSuppressCancelledNetworkNoise(error) {
                isLoadingData = false
                return
            }
            isLoadingData = false
            loadError = (error as? APIError)?.errorDescription ?? error.localizedDescription
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
            message = "Impossible d’encoder l’image."
            return
        }
        let maxLen = 512 * 1024
        guard jpeg.count <= maxLen else {
            message = "Image trop volumineuse (max. 512 Ko)."
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
                message = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    @MainActor
    private func send() async {
        guard campaignManualSendUnlocked else {
            NotificationCenter.default.post(name: .myfidpassOpenMerchantSubscriptionSheet, object: nil)
            return
        }
        guard let slug = resolveSlugForAPI() else { return }
        guard hasCustomNotificationIconFromSettings else {
            notificationLogoPopupPresented = true
            return
        }
        let msg = bodyText
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty else { return }

        bannerTextsAutoSaveTask?.cancel()
        bannerTextsAutoSaveTask = nil
        // Sans ce flush, `notification_change_message` peut rester sur un texte précédent
        // (autosave annulé ou course) alors que la campagne envoie un nouveau corps → Wallet concatène.
        isSending = true
        isNotificationSendInFlight = true
        notificationSendProgress = 0.06
        defer {
            isSending = false
            isNotificationSendInFlight = false
            notificationSendProgress = 0
        }
        do {
            _ = await persistBannerTextsToServer()
            withAnimation(.easeInOut(duration: 0.55)) { notificationSendProgress = 0.20 }

            // Un seul POST /notifications/send : le backend persiste titre + modèle et envoie PassKit
            // (évite le double push PATCH dashboard + POST qui cassait les bannières après changement de texte).
            var payload = NotificationSendPayload(
                title: title.trimmingCharacters(in: .whitespaces).isEmpty ? nil : title,
                message: msg,
                categoryIds: nil,
                segment: segment
            )
            payload.testSelfOnly = false
            let sendResult: NotificationSendResponse = try await APIClient.shared.request(
                .dashboardNotificationSend(slug: slug, body: payload)
            )
            _ = sendResult.accepted ?? sendResult.ok
            let touched = sendResult.total ?? sendResult.sent ?? 0
            NotificationSendLocalHistoryStore.recordSuccess(
                slug: slug,
                title: payload.title,
                message: msg,
                count: touched
            )
            withAnimation(.easeInOut(duration: 0.58)) { notificationSendProgress = 0.64 }

            // Affiche brièvement le résultat dans le bouton avant de vider le champ.
            withAnimation(.easeInOut(duration: 0.22)) { sendSuccessCount = touched }
            withAnimation(.easeInOut(duration: 0.45)) { notificationSendProgress = 0.72 }

            try? await Task.sleep(nanoseconds: 1_400_000_000)
            withAnimation(.easeInOut(duration: 0.42)) { notificationSendProgress = 0.80 }

            // Vider le champ localement.
            keepManualMessageFieldClearedAfterSend = true
            withAnimation(.easeOut(duration: 0.2)) {
                bodyText = ""
                sendSuccessCount = nil
            }
            withAnimation(.easeInOut(duration: 0.38)) { notificationSendProgress = 0.86 }

            // Efface le champ côté serveur (null explicite) pour que le prochain GET ne réinjecte pas
            // l'ancien message dans l'éditeur — nil seul ne suffit pas (le PATCH ignore les champs nil).
            _ = await persistBannerTextsToServer(clearAfterSend: true)
            withAnimation(.easeInOut(duration: 0.38)) { notificationSendProgress = 0.91 }

            invalidateCachedGETNotificationIconResponses()
            notificationIconReloadNonce &+= 1
            await loadCampaignData(force: true)
            withAnimation(.easeInOut(duration: 0.52)) { notificationSendProgress = 0.97 }

            await syncService.syncAfterServerMutation()
            withAnimation(.easeInOut(duration: 0.38)) { notificationSendProgress = 1.0 }

            try? await Task.sleep(nanoseconds: 260_000_000)
        } catch {
            message = (error as? APIError)?.errorDescription ?? error.localizedDescription
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

/// Plan standard avec **relief / bâtiments 3D** (`.standard(elevation: .realistic)`), aligné sur `PerimeterMapView`.
/// La `Map` n’est montée que lorsque la page « localisation » du carrousel est affichée : les autres pages n’affichent qu’un fond léger.
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
    }

    private var placeholderBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.10), Color.black.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "map")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.22))
        }
        .clipped()
    }

    private func reliefMap(latitude: Double, longitude: Double) -> some View {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let radiusCL = CLLocationDistance(max(30, min(1000, radiusMeters ?? 100)))
        let cameraTaskId = "\(latitude)-\(longitude)-\(radiusCL)-live3d"
        return Map(position: $cameraPosition, interactionModes: []) {
            MapCircle(center: center, radius: radiusCL)
                .foregroundStyle(Color.blue.opacity(0.20))
                .stroke(Color.blue.opacity(0.66), lineWidth: 2)
        }
        .mapStyle(.standard(elevation: .realistic))
        .task(id: cameraTaskId) {
            let distanceMeters = min(820, max(300, radiusCL * 5.0))
            cameraPosition = .camera(
                MapCamera(centerCoordinate: center, distance: distanceMeters, heading: 0, pitch: 52)
            )
        }
    }
}

// MARK: - Notif liquid glass (carrousel automatisations)

/// Bannière seule (sans faux iPhone) : style notif système, glass, animation d’entrée au slide.
private struct AutomationCarouselLiquidNotificationBanner: View {
    let senderTitle: String
    let messageBody: String
    /// Si non-nil : édition inline du message (sync serveur côté parent).
    var messageBinding: Binding<String>? = nil
    /// Placeholder du `TextField` (ex. message périmètre vs automatisation segment).
    var textFieldPlaceholder: String = "Message de la notification"
    let logoURL: String?
    let pageIndex: Int
    let currentPage: Int
    /// `false` pour le périmètre : retours à la ligne **interdits** (texte replié sur plusieurs lignes visuellement) ; la touche « OK » / ✓ ferme le clavier et peut appeler `onSubmitActivate` sans insérer `\n`.
    var useMultilineMessageField: Bool = true
    var onSubmitActivate: (() -> Void)? = nil

    @FocusState private var messageFieldFocused: Bool

    private let iconSide: CGFloat = 44
    private let iconCorner: CGFloat = 10

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            automationIcon
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(senderTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 4)
                    Text("maintenant")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Color.black.opacity(0.45))
                }
                if let binding = messageBinding {
                    Group {
                        if useMultilineMessageField {
                            TextField(textFieldPlaceholder, text: binding, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.subheadline.weight(.regular))
                                .foregroundStyle(Color.black.opacity(0.88))
                                .lineLimit(2 ... 5)
                                .multilineTextAlignment(.leading)
                        } else {
                            TextField(textFieldPlaceholder, text: binding, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(.subheadline.weight(.regular))
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
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .glassEffect(.regular, cornerRadius: 22)
        .shadow(color: .clear, radius: 0, y: 0)
        .preferredColorScheme(.light)
    }

    private var automationIcon: some View {
        Group {
            if let raw = logoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
                BusinessLogoView(
                    logoURL: raw,
                    logoAssetContext: .campaignNotificationIcon,
                    size: iconSide,
                    cornerRadius: iconCorner
                )
            } else {
                Image("logonotif")
                    .resizable()
                    .scaledToFill()
                    .frame(width: iconSide, height: iconSide)
                    .clipShape(RoundedRectangle(cornerRadius: iconCorner, style: .continuous))
            }
        }
    }

}

#if DEBUG
#Preview {
    NavigationStack {
        CampaignNotificationsView(context: PersistenceController.preview.container.viewContext)
            .environmentObject(SyncService(container: PersistenceController.preview.container))
            .environmentObject(MainTabRouter())
            .environmentObject(AuthService())
    }
}
#endif
