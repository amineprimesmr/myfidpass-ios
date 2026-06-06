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
    @ViewBuilder private let footer: () -> Footer

    @State private var isEditingMessage = false
    @FocusState private var messageFocused: Bool

    init(
        logoURL: String? = nil,
        notificationTitle: String,
        messageText: Binding<String>,
        messagePlaceholder: String = "Message sur le pass",
        maxLength: Int = 200,
        previewSize: WalletNotificationPreviewSize = .standard,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.logoURL = logoURL
        self.notificationTitle = notificationTitle
        self._messageText = messageText
        self.messagePlaceholder = messagePlaceholder
        self.maxLength = maxLength
        self.previewSize = previewSize
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: previewSize.rowSpacing) {
                previewIcon
                VStack(alignment: .leading, spacing: previewSize.textStackSpacing) {
                    Text(notificationTitle)
                        .font(previewSize.titleFont)
                        .foregroundStyle(Color.black)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if isEditingMessage {
                        TextField(messagePlaceholder, text: cappedMessageBinding, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(previewSize.bodyFont)
                            .foregroundStyle(Color.black.opacity(0.92))
                            .tint(AppTheme.Colors.primary)
                            .lineLimit(3 ... 10)
                            .multilineTextAlignment(.leading)
                            .focused($messageFocused)
                            .submitLabel(.done)
                            .onSubmit { finishEditingMessage() }
                    } else {
                        messageReadOnlyLine
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    if isEditingMessage {
                        finishEditingMessage()
                    } else {
                        isEditingMessage = true
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 45_000_000)
                            messageFocused = true
                        }
                    }
                } label: {
                    Image(systemName: isEditingMessage ? "checkmark.circle.fill" : "square.and.pencil")
                        .font(.system(size: previewSize.editIconSize, weight: .semibold))
                        .foregroundStyle(isEditingMessage ? AppTheme.Colors.primary : Color.black.opacity(0.48))
                        .frame(width: 32, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEditingMessage ? "Terminer la modification du message" : "Modifier le message")
            }
            .padding(.vertical, previewSize.verticalPadding)
            .padding(.horizontal, previewSize.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .walletNotificationPreviewSurface(previewSize: previewSize)
            .preferredColorScheme(.light)

            footer()
        }
    }

    private func finishEditingMessage() {
        isEditingMessage = false
        messageFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var messageReadOnlyLine: some View {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Text(trimmed.isEmpty ? messagePlaceholder : messageText)
            .font(previewSize.bodyFont)
            .foregroundStyle(trimmed.isEmpty ? Color.black.opacity(0.38) : Color.black.opacity(0.92))
            .multilineTextAlignment(.leading)
            .lineLimit(1 ... 8)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        previewSize: WalletNotificationPreviewSize = .standard
    ) {
        self.init(
            logoURL: logoURL,
            notificationTitle: notificationTitle,
            messageText: messageText,
            messagePlaceholder: messagePlaceholder,
            maxLength: maxLength,
            previewSize: previewSize,
            footer: { EmptyView() }
        )
    }
}

// MARK: - Apple Wallet (verrouillage)

private let campaignFamilies: [CampaignFamilySpec] = [
    CampaignFamilySpec(
        id: "reactivation",
        title: "Client inactif +14 jours",
        icon: "arrow.counterclockwise.circle",
        rules: [
            CampaignRuleSpec(
                id: "inactive_14",
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
                id: "birthday_today",
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

/// Ordre d’affichage du hub — périmètre / carte en premier dans le carrousel ; clés alignées sur le cron SaaS.
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
    CampaignRuleSpec(
        id: "points_near",
        title: "Presque la récompense",
        subtitle: "Clients proches du palier de points.",
        segmentKey: "pointsNear50",
        notificationPreviewTitle: "Encore quelques points",
        timingCaption:
            "Le client voit ce message quand il manque peu de points (ou de tampons) avant de débloquer la récompense."
    ),
    CampaignRuleSpec(
        id: "reward_ready",
        title: "Récompense prête",
        subtitle: "Clients à récompense disponible (ex. 50 points).",
        segmentKey: "points50",
        notificationPreviewTitle: "Votre récompense est prête",
        timingCaption:
            "Le client voit ce message dès que le palier est atteint et que la récompense est dispo sur la carte."
    ),
    CampaignRuleSpec(
        id: "inactive_14",
        title: "Client inactif +14 jours",
        subtitle: "Sans visite depuis 2 semaines.",
        segmentKey: "inactive14",
        notificationPreviewTitle: "Ça fait un moment…",
        timingCaption:
            "Le client voit ce message s’il n’a plus utilisé sa carte depuis environ deux semaines."
    ),
    CampaignRuleSpec(
        id: "birthday_today",
        title: "Anniversaire du jour",
        subtitle: "Date de naissance renseignée sur le profil.",
        segmentKey: "birthdayToday",
        notificationPreviewTitle: "Joyeux anniversaire",
        timingCaption:
            "Le client voit ce message le jour de son anniversaire (date renseignée sur son profil)."
    ),
]

/// Messages par défaut : `campaign-automation-cron.js` + périmètre (`locationEntry` seed).
private let defaultAutomationRuleMessages: [String: String] = [
    "inactive_14": "Ça fait un moment... Revenez nous voir aujourd'hui et profitez de -10 %.",
    "reward_ready": "Votre récompense est prête — passez en magasin pour en profiter.",
    "points_near": "Plus que quelques points pour débloquer votre récompense !",
    "birthday_today": "Joyeux anniversaire ! Profitez de -20 % en commandant aujourd'hui.",
    "locationEntry": "Vous êtes à proximité de notre commerce. Passez nous voir, votre carte Wallet est prête.",
]

private func foldLegacyAutomationKeys(
    into rules: inout [String: CampaignAutomationRuleDTO],
    canonical: String,
    legacy: String
) {
    guard let leg = rules.removeValue(forKey: legacy) else { return }
    if var cur = rules[canonical] {
        let legMsg = leg.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let curMsg = cur.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if curMsg.isEmpty, !legMsg.isEmpty { cur.message = leg.message }
        if leg.enabled == true { cur.enabled = true }
        rules[canonical] = cur
    } else {
        rules[canonical] = leg
    }
}

/// Retire les automatisations « bienvenue » retirées du produit (hub + événements `member_created`).
private func purgeRetiredWelcomeAutomationRules(_ rules: inout [String: CampaignAutomationRuleDTO]) {
    rules.removeValue(forKey: "welcome_pass")
    for key in rules.keys where key.hasPrefix("event_") {
        let et = rules[key]?.eventType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        if et == "member_created" {
            rules.removeValue(forKey: key)
        }
    }
}

/// Évite d’envoyer `inactive14` / `birthdayToday` : le cron serveur ne les exécute pas (seulement `inactive_14` / `birthday_today`).
private func campaignAutomationSanitizedForServer(_ config: CampaignAutomationConfigDTO) -> CampaignAutomationConfigDTO {
    var rules = config.rules ?? [:]
    foldLegacyAutomationKeys(into: &rules, canonical: "inactive_14", legacy: "inactive14")
    foldLegacyAutomationKeys(into: &rules, canonical: "birthday_today", legacy: "birthdayToday")
    rules.removeValue(forKey: "new_week")
    purgeRetiredWelcomeAutomationRules(&rules)
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
    var rules: [String: CampaignAutomationRuleDTO] = [:]
    for r in automationHubRules where !r.id.hasPrefix("_info") {
        let defMsg = defaultAutomationRuleMessages[r.id] ?? ""
        let existing: CampaignAutomationRuleDTO? = {
            if let exact = api?.rules?[r.id] { return exact }
            switch r.id {
            case "inactive_14":
                return api?.rules?["inactive14"]
            case "birthday_today":
                return api?.rules?["birthdayToday"]
            default:
                return nil
            }
        }()
        rules[r.id] = CampaignAutomationRuleDTO(
            enabled: existing?.enabled ?? true,
            message: (existing?.message?.isEmpty == false ? existing?.message : defMsg) ?? defMsg,
            segment: existing?.segment,
            title: existing?.title
        )
    }
    if let apiRules = api?.rules {
        for (k, v) in apiRules {
            if k.hasPrefix("custom_") || k.hasPrefix("event_") {
                rules[k] = v
            } else if rules[k] == nil {
                if k == "inactive14" && rules["inactive_14"] != nil { continue }
                if k == "birthdayToday" && rules["birthday_today"] != nil { continue }
                rules[k] = v
            }
        }
    }
    foldLegacyAutomationKeys(into: &rules, canonical: "inactive_14", legacy: "inactive14")
    foldLegacyAutomationKeys(into: &rules, canonical: "birthday_today", legacy: "birthdayToday")
    rules.removeValue(forKey: "new_week")
    purgeRetiredWelcomeAutomationRules(&rules)
    upgradeFactoryDisabledHubAutomationRules(&rules)
    let cd = api?.globalCooldownDays ?? 7
    return CampaignAutomationConfigDTO(version: api?.version ?? 1, globalCooldownDays: min(90, max(1, cd)), rules: rules)
}

/// Ancien état usine (hub entier désactivé + textes par défaut) → activer toutes les cartes du carrousel.
private func upgradeFactoryDisabledHubAutomationRules(_ rules: inout [String: CampaignAutomationRuleDTO]) {
    let hubIds = automationHubRules.filter { !$0.id.hasPrefix("_info") }.map(\.id)
    guard hubIds.allSatisfy({ rules[$0]?.enabled != true }) else { return }
    guard hubIds.allSatisfy({ id in
        let msg = rules[id]?.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let def = defaultAutomationRuleMessages[id] ?? ""
        return msg.isEmpty || msg == def
    }) else { return }
    for id in hubIds {
        let def = defaultAutomationRuleMessages[id] ?? ""
        var row = rules[id] ?? CampaignAutomationRuleDTO(enabled: true, message: def)
        row.enabled = true
        if row.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            row.message = def
        }
        rules[id] = row
    }
}

/// Programmation manuelle dans l’app : une fois, ou chaque jour (conversion fuseau → UTC côté token, comme le job SaaS).
private enum ScheduledNotificationKind: String, CaseIterable, Identifiable {
    case oneTime
    case daily

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneTime:
            return "Une date et heure"
        case .daily:
            return "Chaque jour à la même heure"
        }
    }
}

// MARK: - Barre de progression envoi (bandeau tout en haut — `progress` suit les étapes réelles de `send()`)

/// Barre de progression statique (sans `TimelineView` — moins de charge pendant l’envoi).
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
                    .frame(height: 5)
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: max(3, fillW), height: 5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 5)
        .accessibilityLabel("Progression d’envoi de la notification")
        .accessibilityValue("\(Int((max(0, min(1, progress))) * 100)) pour cent")
    }
}

// MARK: - Carrousel « Notifications automatiques » (dimensions partagées)

private enum AutomationCarouselLayout {
    /// Hauteur totale du `TabView` page (carte périmètre / cartes famille + bannière).
    static let tabViewHeight: CGFloat = 468
    /// Carte résumé et bloc carte carte (alignés).
    static let summaryCardHeight: CGFloat = 386
    /// Hauteur fixe de **chaque** slide du hub (toutes pages identiques).
    static let hubCarouselSlideContentHeight: CGFloat = 228
    /// Padding intérieur du bloc unique (titre + explications + carrousel + points).
    static let hubCarouselInnerPadding: CGFloat = 12
    static let hubCarouselSlideCornerRadius: CGFloat = 14
    /// Marge latérale du hub — plus étroite pour un carrousel plus large.
    static let hubCarouselOuterHorizontalPadding: CGFloat = 10
}

private enum AutomationHubCarouselChrome {
    static let slideFill = Color.white
    static let slideStroke = Color.black.opacity(0.07)
    static let slideShadow = Color.black.opacity(0.06)
    /// Réserve minimale sous le titre pour limiter le « saut » des points entre slides.
    static let headerSubtitleMinHeight: CGFloat = 30
    static let pageIndicatorSlotWidth: CGFloat = 18
    static let pageIndicatorHeight: CGFloat = 5
}

/// Pages du carrousel hub : règles prédéfinies, règles perso `custom_*`, puis programmation.
private enum AutomationHubCarouselSlot: Hashable {
    case hubRule(String)
    case customRule(String)
    case programming
}

// MARK: - Vue principale

struct CampaignNotificationsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @Environment(\.merchantTabIsActive) private var merchantTabIsActive
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var dataService: DataService

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
        case eventAutomation

        var id: String {
            switch self {
            case .ruleEditor(let rid): return "rule:\(rid)"
            case .eventAutomation: return "event"
            }
        }
    }

    @State private var auxiliarySheet: AuxiliarySheet?
    /// Même schéma que le popup « panier repère » sur la page Commerce (fond + carte centrée).
    @State private var notificationLogoPopupPresented = false
    @State private var notificationIconNudgeTask: Task<Void, Never>?
    @State private var showPerimeterMapSheet = false

    /// Envoi manuel de campagne : abo payant (sinon aperçu flouté + Déverrouiller avec Pro).
    private var campaignManualSendUnlocked: Bool {
        authService.merchantProInsightsUnlocked
    }

    // MARK: - Notifications programmées (date / récurrence quotidienne)
    @State private var eventAutomationsRuleBeingEdited: String?
    @State private var scheduleKind: ScheduledNotificationKind = .daily
    @State private var oneShotScheduleDate: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var eventDraftTitle = ""
    /// Délai après l’heure programmée avant envoi effectif (minutes) — le SaaS enqueue `run_at = maintenant + délai`.
    @State private var eventDraftDelayMinutes: Int = 1
    @State private var eventDraftMessage = ""
    @State private var eventDraftScheduleHour: Int = 10
    @State private var eventDraftScheduleMinute: Int = 0
    @State private var eventRulePendingDelete: String?
    /// Page du carrousel « Notifications automatiques » (géolocalisation + inactifs).
    @State private var automationCarouselPage: Int = 0
    /// Page du carrousel horizontal du hub éditable (automatisations).
    @State private var automationHubCarouselPage: Int = 0
    /// Confirmation **uniquement** avant de désactiver tout un bloc d’automatisations.
    @State private var familyAutomationDisableConfirm: FamilyAutomationDisableConfirm?
    @State private var lastCarouselHapticPage: Int = 0
    @State private var lastAutomationHubCarouselHapticPage: Int = 0
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
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                previewSection
                    .padding(.top, 12)
                automationsContent
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            .padding(.bottom, 100)
            .contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
        /// Réduit les conflits de rebond avec le paging horizontal du carrousel (TabView) imbriqué.
        .scrollBounceBehavior(.basedOnSize)
    }

    private var campaignNotificationsWithLifecycle: some View {
        MerchantTabScaffold(
            panelBackground: AppTheme.Colors.background,
            extraPanelTopInset: campaignNotificationsSendStripInset,
            topBar: { campaignNotificationsTopChrome },
            panel: {
                campaignNotificationsScrollStack
                    .scrollDismissesKeyboard(.interactively)
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
        .onChange(of: activeSlugForViewChange) { _, _ in
            guard merchantTabIsActive else { return }
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
            guard merchantTabIsActive else { return }
            scheduleCampaignDataReload(force: false, debounceNs: 220_000_000)
        }
        .refreshable {
            await loadCampaignData()
        }
        .alert(merchantAlertTitle, isPresented: .init(get: { message != nil }, set: { if !$0 { message = nil } })) {
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
                case .eventAutomation:
                    eventAutomationEditorSheet
                }
            }
            .alert("Supprimer cette programmation ?", isPresented: Binding(
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
                Text("La programmation sera supprimée.")
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

    private var merchantAlertTitle: String { "Impossible de continuer" }

    private func assignMerchantAlertMessage(from error: Error) {
        guard let text = APIError.merchantFacingMessage(from: error) else { return }
        message = text
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
            canCreateBusiness: authService.isPlatformAdmin ? false : authService.canCreateBusiness,
            isPlatformAdminAllCommercesMode: authService.isPlatformAdmin,
            onOpenAdministration: authService.isPlatformAdmin ? { authService.returnToPlatformAdministrationHub() } : nil,
            onBusinessSwitcherWillOpen: authService.isPlatformAdmin ? {
                Task { await authService.refreshPlatformAdminBusinesses(force: true) }
            } : nil,
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

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            if let err = loadError {
                errorCard(err)
                    .padding(.horizontal, AppTheme.Spacing.md)
            }
            ZStack {
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
                .blur(radius: campaignManualSendUnlocked ? 0 : 5)
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
                unifiedAutomationsHubSection
            }
        }
    }

    private var legacyCustomAutomationRuleIds: [String] {
        (campaignAutomation.rules ?? [:]).keys.filter { $0.hasPrefix("custom_") }.sorted()
    }

    private var automationHubCarouselSlots: [AutomationHubCarouselSlot] {
        var slots = automationHubRules.map { AutomationHubCarouselSlot.hubRule($0.id) }
        slots += legacyCustomAutomationRuleIds.map { AutomationHubCarouselSlot.customRule($0) }
        slots.append(.programming)
        return slots
    }

    private var automationHubCarouselPageCount: Int {
        automationHubCarouselSlots.count
    }

    private func automationHubHeaderTitle(page: Int) -> String {
        guard automationHubCarouselSlots.indices.contains(page) else { return "Automatisations" }
        switch automationHubCarouselSlots[page] {
        case .hubRule(let id):
            if id == "locationEntry" { return "Automatisations" }
            return automationHubRules.first(where: { $0.id == id })?.title ?? "Automatisations"
        case .customRule(let ruleId):
            let tit = campaignAutomation.rules?[ruleId]?.title?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return tit.isEmpty ? "Automatisation personnalisée" : tit
        case .programming:
            return "Notification automatique"
        }
    }

    private func automationHubHeaderSubtitle(page: Int) -> String? {
        guard automationHubCarouselSlots.indices.contains(page) else { return nil }
        switch automationHubCarouselSlots[page] {
        case .hubRule(let id):
            if id == "locationEntry" {
                return "Notification quand le client entre dans votre périmètre Wallet."
            }
            guard let spec = automationHubRules.first(where: { $0.id == id }) else { return nil }
            let cap = spec.timingCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return cap.isEmpty ? spec.subtitle : cap
        case .customRule(let ruleId):
            let seg = campaignAutomation.rules?[ruleId]?.segment ?? ""
            let segLabel = campaignSegmentCatalogLabel(for: seg)
            return "Segment « \(segLabel) » — envoi automatique côté serveur."
        case .programming:
            return "Rappel à une date précise ou chaque jour à la même heure."
        }
    }

    private var automationHubCarouselPageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<automationHubCarouselPageCount, id: \.self) { i in
                Button {
                    automationHubCarouselPage = i
                } label: {
                    ZStack {
                        Capsule()
                            .fill(Color.clear)
                            .frame(
                                width: AutomationHubCarouselChrome.pageIndicatorSlotWidth,
                                height: AutomationHubCarouselChrome.pageIndicatorHeight
                            )
                        Capsule()
                            .fill(
                                i == automationHubCarouselPage
                                    ? AppTheme.Colors.primary
                                    : AppTheme.Colors.textSecondary.opacity(0.28)
                            )
                            .frame(
                                width: i == automationHubCarouselPage
                                    ? AutomationHubCarouselChrome.pageIndicatorSlotWidth
                                    : 6,
                                height: AutomationHubCarouselChrome.pageIndicatorHeight
                            )
                    }
                    .frame(
                        width: AutomationHubCarouselChrome.pageIndicatorSlotWidth,
                        height: AutomationHubCarouselChrome.pageIndicatorHeight
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: AutomationHubCarouselChrome.pageIndicatorHeight)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(automationHubHeaderTitle(page: automationHubCarouselPage)), page \(automationHubCarouselPage + 1) sur \(automationHubCarouselPageCount)"
        )
    }

    /// Hub : un seul fond (titre + explication + slides + indicateurs), slides à hauteur fixe.
    private var unifiedAutomationsHubSection: some View {
        let corner = AutomationCarouselLayout.hubCarouselSlideCornerRadius
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
        let slideH = AutomationCarouselLayout.hubCarouselSlideContentHeight

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                automationHubCarouselHeaderBlock

                TabView(selection: $automationHubCarouselPage) {
                    ForEach(Array(automationHubCarouselSlots.enumerated()), id: \.offset) { idx, slot in
                        automationHubCarouselSlotView(slot: slot, pageIndex: idx)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: slideH)

                automationHubCarouselPageIndicator
            }
            .padding(AutomationCarouselLayout.hubCarouselInnerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AutomationHubCarouselChrome.slideFill)
            .clipShape(shape)
            .overlay(shape.stroke(AutomationHubCarouselChrome.slideStroke, lineWidth: 1))
            .shadow(color: AutomationHubCarouselChrome.slideShadow, radius: 8, x: 0, y: 3)
        }
        .padding(.horizontal, AutomationCarouselLayout.hubCarouselOuterHorizontalPadding)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: automationHubCarouselPageCount) { _, newCount in
            if newCount == 0 {
                automationHubCarouselPage = 0
                return
            }
            if automationHubCarouselPage >= newCount {
                automationHubCarouselPage = newCount - 1
            }
        }
        .onChange(of: automationHubCarouselPage) { _, newPage in
            guard newPage != lastAutomationHubCarouselHapticPage else { return }
            lastAutomationHubCarouselHapticPage = newPage
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred(intensity: 0.85)
        }
    }

    /// Titre + explication de la slide courante (dans le même fond que le carrousel).
    private var automationHubCarouselHeaderBlock: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(automationHubHeaderTitle(page: automationHubCarouselPage))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .id("automation-hub-title-\(automationHubCarouselPage)")
            Group {
                if let subtitle = automationHubHeaderSubtitle(page: automationHubCarouselPage) {
                    Text(subtitle)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .id("automation-hub-subtitle-\(automationHubCarouselPage)")
                } else {
                    Color.clear
                }
            }
            .frame(minHeight: AutomationHubCarouselChrome.headerSubtitleMinHeight, alignment: .topLeading)
        }
        .animation(.easeOut(duration: 0.18), value: automationHubCarouselPage)
    }

    @ViewBuilder
    private func automationHubCarouselSlotView(slot: AutomationHubCarouselSlot, pageIndex: Int) -> some View {
        let slideH = AutomationCarouselLayout.hubCarouselSlideContentHeight
        Group {
            switch slot {
            case .hubRule(let id):
                if let spec = automationHubRules.first(where: { $0.id == id }) {
                    automationHubCarouselPageView(spec: spec, pageIndex: pageIndex)
                } else {
                    Color.clear
                }
            case .customRule(let ruleId):
                automationHubLegacyCarouselPage(ruleId: ruleId)
            case .programming:
                automationHubProgrammingCarouselPage
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: slideH, alignment: .top)
        .clipped()
    }

    @ViewBuilder
    private func automationHubCarouselPageView(spec: CampaignRuleSpec, pageIndex: Int) -> some View {
        if spec.id == "locationEntry" {
            automationHubLocationMapSection(spec: spec, pageIndex: pageIndex)
        } else {
            automationStandardHubCard(spec: spec, showsRuleTitleHeader: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func automationHubLegacyCarouselPage(ruleId: String) -> some View {
        legacyCustomRuleCard(ruleId: ruleId, showsMetaHeader: false)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Dernière page du carrousel : notifications automatiques planifiées (ex-`eventAutomationsSection`).
    private var automationHubProgrammingCarouselPage: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if #available(iOS 26.0, *) {
                        Button(action: prepareNewEventAutomation) {
                            Label("Nouvelle notification", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    } else {
                        Button(action: prepareNewEventAutomation) {
                            Label("Nouvelle notification", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.Colors.primary)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)

                if !eventRuleIds.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(eventRuleIds, id: \.self) { rid in
                            eventAutomationRow(ruleId: rid)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func bindingAutomationRuleMessage(_ ruleId: String) -> Binding<String> {
        let def = defaultAutomationRuleMessages[ruleId] ?? ""
        return Binding(
            get: { campaignAutomation.rules?[ruleId]?.message ?? def },
            set: { v in
                var rsc = campaignAutomation.rules ?? [:]
                var row = rsc[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: v)
                if hasCustomNotificationIconFromSettings {
                    row.enabled = true
                }
                row.message = String(v.prefix(200))
                rsc[ruleId] = row
                campaignAutomation.rules = rsc
                scheduleCampaignAutomationSave()
            }
        )
    }

    private func bindingEventAutomationRuleMessage(_ ruleId: String) -> Binding<String> {
        Binding(
            get: { campaignAutomation.rules?[ruleId]?.message ?? "" },
            set: { v in
                var rsc = campaignAutomation.rules ?? [:]
                var row = rsc[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
                if hasCustomNotificationIconFromSettings {
                    row.enabled = true
                }
                row.message = String(v.prefix(200))
                rsc[ruleId] = row
                campaignAutomation.rules = rsc
                scheduleCampaignAutomationSave()
            }
        )
    }

    private func automationStandardHubCard(spec: CampaignRuleSpec, showsRuleTitleHeader: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsRuleTitleHeader {
                Text(spec.title)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            automationStandardHubCardCore(spec: spec)
        }
    }

    private func automationStandardHubCardCore(spec: CampaignRuleSpec) -> some View {
        WalletNotificationPreviewBlock(
            logoURL: notificationPreviewIconURLForView,
            notificationTitle: spec.effectiveNotificationPreviewTitle,
            messageText: bindingAutomationRuleMessage(spec.id),
            messagePlaceholder: "Tapez le message…",
            previewSize: .standard,
            footer: { automationHubRuleToggleFooter(ruleId: spec.id) }
        )
    }

    private func automationHubRuleToggleFooter(ruleId: String) -> some View {
        let enabled = hasCustomNotificationIconFromSettings
            && (campaignAutomation.rules?[ruleId]?.enabled ?? false)
        return HStack(spacing: 8) {
            Text(enabled ? "Activé" : "Activer")
                .font(AppTheme.Fonts.caption().weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Spacer(minLength: 0)
            Toggle("", isOn: Binding(
                get: { enabled },
                set: { on in
                    if on, !requireNotificationIconForSending() { return }
                    var r = campaignAutomation.rules ?? [:]
                    var row = r[ruleId] ?? CampaignAutomationRuleDTO(
                        enabled: false,
                        message: defaultAutomationRuleMessages[ruleId] ?? ""
                    )
                    row.enabled = on
                    if on, row.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                        row.message = defaultAutomationRuleMessages[ruleId] ?? row.message
                    }
                    r[ruleId] = row
                    campaignAutomation.rules = r
                    scheduleCampaignAutomationSave()
                }
            ))
            .labelsHidden()
            .tint(AppTheme.Colors.primary)
            .scaleEffect(0.88)
        }
        .padding(.top, 2)
    }

    /// Slide localisation : tap sur la carte → éditeur périmètre (comme l’ancien bouton « Modifier »).
    private func automationHubLocationMapSection(spec: CampaignRuleSpec, pageIndex: Int) -> some View {
        let slideH = AutomationCarouselLayout.hubCarouselSlideContentHeight
        let mapCorner = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return ZStack(alignment: .bottom) {
            LocalAutomationReliefMapBackdrop(
                latitude: dashboardSettings?.locationLat,
                longitude: dashboardSettings?.locationLng,
                radiusMeters: dashboardSettings?.locationRadiusMeters,
                isLiveElevationMapActive: automationHubCarouselPage == pageIndex
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(mapCorner)

            Button {
                showPerimeterMapSheet = true
            } label: {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifier le périmètre sur la carte")

            automationPerimeterHubNotificationOverlay(spec: spec)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .allowsHitTesting(true)
        }
        .frame(maxWidth: .infinity)
        .frame(height: slideH)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Carte du périmètre. Touchez la carte pour modifier le périmètre.")
    }

    private func automationPerimeterHubNotificationOverlay(spec: CampaignRuleSpec) -> some View {
        let def = defaultAutomationRuleMessages[spec.id] ?? ""
        return WalletNotificationPreviewBlock(
            logoURL: notificationPreviewIconURLForView,
            notificationTitle: spec.effectiveNotificationPreviewTitle,
            messageText: Binding(
                get: { perimeterRelevantMessageText },
                set: { v in
                    perimeterRelevantMessageText = String(v.prefix(200))
                    isPerimeterRelevantTextDirty = true
                    var rsc = campaignAutomation.rules ?? [:]
                    var row = rsc["locationEntry"] ?? CampaignAutomationRuleDTO(enabled: false, message: def)
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
            previewSize: .standard
        )
    }

    private func legacyCustomRuleCard(ruleId: String, showsMetaHeader: Bool = true) -> some View {
        let row = campaignAutomation.rules?[ruleId]
        let seg = row?.segment ?? ""
        let segLabel = campaignSegmentCatalogLabel(for: seg)
        let tit = row?.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = tit.isEmpty ? "Automatisation personnalisée" : tit
        let previewTitle = tit.isEmpty ? "Offre pour vous" : String(tit.prefix(48))
        return VStack(alignment: .leading, spacing: 8) {
            if showsMetaHeader {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(AppTheme.Fonts.caption2().weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                    Text(segLabel)
                        .font(AppTheme.Fonts.caption2())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            WalletNotificationPreviewBlock(
                logoURL: notificationPreviewIconURLForView,
                notificationTitle: previewTitle,
                messageText: bindingAutomationRuleMessage(ruleId),
                messagePlaceholder: "Message pour ce groupe…",
                previewSize: .standard,
                footer: { automationHubRuleToggleFooter(ruleId: ruleId) }
            )
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
        return "À proximité du magasin (Wallet)."
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
        if let first = rules.first, let def = defaultAutomationRuleMessages[first.id] { return def }
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
        guard hasCustomNotificationIconFromSettings else { return false }
        let fid = effectiveRulesFamilyId(forCarouselFamilyId: carouselFamilyId)
        guard let family = campaignFamilies.first(where: { $0.id == fid }) else { return false }
        return family.rules.contains { !$0.id.hasPrefix("_info") && ((campaignAutomation.rules?[$0.id]?.enabled) ?? false) }
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

    /// Active ou désactive toutes les règles de la famille (messages défaut si besoin).
    private func setFamilyAutomationEnabled(carouselFamilyId: String, enabled: Bool) {
        if enabled, !requireNotificationIconForSending() { return }
        let fid = effectiveRulesFamilyId(forCarouselFamilyId: carouselFamilyId)
        guard let family = campaignFamilies.first(where: { $0.id == fid }) else { return }
        var r = campaignAutomation.rules ?? [:]
        for rule in family.rules where !rule.id.hasPrefix("_info") {
            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultAutomationRuleMessages[rule.id] ?? "")
            row.enabled = enabled
            if enabled, row.message == nil || row.message?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                row.message = defaultAutomationRuleMessages[rule.id] ?? row.message
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
                return defaultAutomationRuleMessages[ruleId] ?? ""
            },
            set: { v in
                var r = campaignAutomation.rules ?? [:]
                var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: "")
                if hasCustomNotificationIconFromSettings {
                    row.enabled = true
                }
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
                var rsc = campaignAutomation.rules ?? [:]
                let def = defaultAutomationRuleMessages["locationEntry"] ?? ""
                var row = rsc["locationEntry"] ?? CampaignAutomationRuleDTO(enabled: false, message: def)
                if hasCustomNotificationIconFromSettings {
                    row.enabled = true
                }
                rsc["locationEntry"] = row
                campaignAutomation.rules = rsc
                schedulePerimeterRelevantTextSave()
                scheduleCampaignAutomationSave()
            }
        )
    }

    /// Repli **uniquement** pour les cartes automatisations du carrousel — ne pas utiliser `bodyText` (campagnes manuelles).
    private func fallbackAutomationCarouselBody() -> String {
        "Exemple : texte sur le pass au moment où l’automatisation se déclenche."
    }

    @ViewBuilder
    private func automationCarouselPageStack(
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
                logoURL: notificationPreviewIconURLForView
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
    private func automationPerimeterPageStack(isLiveElevationMapActive: Bool) -> some View {
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
                cardHeight: AutomationCarouselLayout.summaryCardHeight,
                isLiveElevationMapActive: isLiveElevationMapActive,
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
        let tabH = AutomationCarouselLayout.tabViewHeight
        return VStack(alignment: .leading, spacing: 12) {
            TabView(selection: $automationCarouselPage) {
                automationPerimeterPageStack(isLiveElevationMapActive: automationCarouselPage == 0)
                    .tag(0)
                ForEach(Array(predefinedAutomationFamilies.enumerated()), id: \.element.id) { index, family in
                    automationCarouselPageStack(
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
                        automationCarouselPage = i
                    } label: {
                        Capsule()
                            .fill(i == automationCarouselPage ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary.opacity(0.28))
                            .frame(width: i == automationCarouselPage ? 22 : 6, height: 6)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 4)
                }
            }
            .animation(nil, value: automationCarouselPage)
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
            let g = UIImpactFeedbackGenerator(style: .light)
            g.prepare()
            g.impactOccurred(intensity: 0.85)
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

    /// Bande colorée bas de carte (carrousel) — remplace les anciennes images `AutoRelance` / `anniv` (plus de decode PNG, plus fluide).
    private func automationCarouselSummaryStripeColors(familyId: String, accent: Color) -> [Color] {
        switch familyId {
        case "birthday":
            return [
                Color(red: 0.32, green: 0.06, blue: 0.18),
                Color(red: 0.52, green: 0.12, blue: 0.30),
                Color(red: 0.78, green: 0.22, blue: 0.44),
                Color(red: 0.95, green: 0.42, blue: 0.55),
                Color(red: 0.99, green: 0.68, blue: 0.76)
            ]
        case "reactivation":
            return [
                Color(red: 0.04, green: 0.12, blue: 0.20),
                Color(red: 0.08, green: 0.26, blue: 0.36),
                Color(red: 0.10, green: 0.42, blue: 0.48),
                Color(red: 0.16, green: 0.55, blue: 0.52),
                Color(red: 0.92, green: 0.58, blue: 0.16)
            ]
        default:
            return [
                accent.opacity(0.88),
                accent.opacity(0.55),
                AppTheme.Colors.primary.opacity(0.42),
                Color(red: 0.10, green: 0.11, blue: 0.14)
            ]
        }
    }

    @ViewBuilder
    private func automationSummaryCardBackground(
        familyId: String,
        accent: Color,
        corner: CGFloat,
        cardHeight: CGFloat
    ) -> some View {
        let stripeH = min(172, cardHeight * 0.44)
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.10, blue: 0.12),
                            AppTheme.Colors.cardBackground.opacity(0.94)
                        ],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.58)
                    )
                )
            LinearGradient(
                colors: [Color.black.opacity(0.52), Color.black.opacity(0.18), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: automationCarouselSummaryStripeColors(familyId: familyId, accent: accent),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: stripeH)
                .mask(
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private func automationSummaryCard(
        accent: Color,
        isActive: Bool,
        familyId: String,
        onToggleActive: @escaping () -> Void
    ) -> some View {
        let cardHeight = AutomationCarouselLayout.summaryCardHeight
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
            automationSummaryCardBackground(
                familyId: familyId,
                accent: accent,
                corner: corner,
                cardHeight: cardHeight
            )
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

    private var eventRuleIds: [String] {
        (campaignAutomation.rules ?? [:]).keys
            .filter { $0.hasPrefix("event_") }
            .filter { !isRetiredWelcomeEventRule($0) }
            .sorted()
    }

    private func isRetiredWelcomeEventRule(_ ruleId: String) -> Bool {
        let et = campaignAutomation.rules?[ruleId]?.eventType?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        return et == "member_created"
    }

    private var eventAutomationEditorSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom", text: $eventDraftTitle)
                    Picker("Type", selection: $scheduleKind) {
                        ForEach(ScheduledNotificationKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.menu)

                    if scheduleKind == .oneTime {
                        DatePicker(
                            "Date et heure",
                            selection: $oneShotScheduleDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    } else {
                        Stepper(value: $eventDraftScheduleHour, in: 0 ... 23, step: 1) {
                            Text("Heure : \(String(format: "%02d", eventDraftScheduleHour))h")
                        }
                        Stepper(value: $eventDraftScheduleMinute, in: 0 ... 59, step: 1) {
                            Text("Minutes : \(String(format: "%02d", eventDraftScheduleMinute))")
                        }
                    }

                    Stepper(value: $eventDraftDelayMinutes, in: 1 ... 120, step: 1) {
                        Text("+\(eventDraftDelayMinutes) min après l’instant")
                    }
                } header: {
                    Text("Quand")
                } footer: {
                    Text("Heure stockée en UTC (fuseau de l’appareil). Tous les membres avec la carte.")
                        .font(AppTheme.Fonts.caption2())
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField(
                            "Message",
                            text: Binding(
                                get: { eventDraftMessage },
                                set: { eventDraftMessage = String($0.prefix(200)) }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(4 ... 12)
                        .textFieldStyle(.plain)
                        Text("\(eventDraftMessage.count)/200")
                            .font(AppTheme.Fonts.caption2())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                } header: {
                    Text("Message")
                }
            }
            .navigationTitle(eventAutomationsRuleBeingEdited == nil ? "Programmation" : "Modifier")
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
        return !msg.isEmpty && !tit.isEmpty && eventDraftDelayMinutes > 0
    }

    private func prepareNewEventAutomation() {
        eventAutomationsRuleBeingEdited = nil
        scheduleKind = .daily
        oneShotScheduleDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
        eventDraftTitle = ""
        eventDraftDelayMinutes = 1
        eventDraftMessage = ""
        eventDraftScheduleHour = 10
        eventDraftScheduleMinute = 0
        auxiliarySheet = .eventAutomation
    }

    private func openEditEventAutomation(ruleId: String) {
        guard let row = campaignAutomation.rules?[ruleId],
              eventSupportsSchedulingEditor(row.eventType) else { return }
        eventAutomationsRuleBeingEdited = ruleId
        eventDraftTitle = row.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        hydrateScheduleDraft(from: row.eventType ?? "")
        eventDraftDelayMinutes = max(1, row.delayMinutes ?? 1)
        eventDraftMessage = row.message ?? ""
        auxiliarySheet = .eventAutomation
    }

    private func saveEventAutomationDraft() {
        let msg = String(eventDraftMessage.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
        let tit = String(eventDraftTitle.prefix(80)).trimmingCharacters(in: .whitespacesAndNewlines)
        let delay = max(1, Int(eventDraftDelayMinutes))
        let et = builtScheduledEventTypeTokenForSave()
        guard !msg.isEmpty, !tit.isEmpty, !et.isEmpty else { return }

        let key = eventAutomationsRuleBeingEdited ?? "event_\(UUID().uuidString)"
        var r = campaignAutomation.rules ?? [:]
        let existing = r[key]
        let row = CampaignAutomationRuleDTO(
            enabled: hasCustomNotificationIconFromSettings ? (existing?.enabled ?? false) : false,
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
        let delay = campaignAutomation.rules?[ruleId]?.delayMinutes ?? 1
        let eventType = campaignAutomation.rules?[ruleId]?.eventType ?? ""
        let canEditSchedule = eventSupportsSchedulingEditor(eventType)
        return VStack(alignment: .leading, spacing: 8) {
            if canEditSchedule {
                HStack(spacing: 6) {
                    Text(readableEventLabel(for: eventType))
                        .font(AppTheme.Fonts.caption2())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text("+\(delay) min")
                        .font(AppTheme.Fonts.caption2())
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.primary.opacity(0.12))
                        .clipShape(Capsule())
                }
            } else {
                Text("Ancienne règle · supprimez pour recréer")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            WalletNotificationPreviewBlock(
                logoURL: notificationPreviewIconURLForView,
                notificationTitle: eventNotificationPreviewTitle(ruleId: ruleId),
                messageText: bindingEventAutomationRuleMessage(ruleId),
                messagePlaceholder: "Tapez le message…",
                previewSize: .carousel,
                footer: {
                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        if #available(iOS 26.0, *) {
                            if canEditSchedule {
                                Button {
                                    openEditEventAutomation(ruleId: ruleId)
                                } label: {
                                    Image(systemName: "calendar")
                                }
                                .buttonStyle(.glass(.regular))
                                .buttonBorderShape(.circle)
                                .controlSize(.small)
                                .accessibilityLabel("Modifier la date et l’heure")
                            }
                            Button {
                                eventRulePendingDelete = ruleId
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.glass(.regular))
                            .buttonBorderShape(.circle)
                            .controlSize(.small)
                            .accessibilityLabel("Supprimer la programmation")
                        } else {
                            if canEditSchedule {
                                Button {
                                    openEditEventAutomation(ruleId: ruleId)
                                } label: {
                                    Image(systemName: "calendar")
                                }
                                .buttonStyle(.bordered)
                                .accessibilityLabel("Modifier la date et l’heure")
                            }
                            Button {
                                eventRulePendingDelete = ruleId
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Supprimer la programmation")
                        }
                    }
                }
            )
        }
        .padding(.vertical, 4)
    }

    /// Titre court dans l’aperçu (nom de règle du commerçant, sinon libellé selon le type d’événement).
    private func eventNotificationPreviewTitle(ruleId: String) -> String {
        if let t = campaignAutomation.rules?[ruleId]?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return String(t.prefix(56))
        }
        let raw = (campaignAutomation.rules?[ruleId]?.eventType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        switch raw {
        case "first_scan":
            return "Première visite"
        case "reward_unlocked":
            return "Récompense débloquée"
        default:
            break
        }
        if raw.hasPrefix("inactive_days:") { return "Ça fait un moment" }
        if raw.hasPrefix("daily_at:") { return "Rappel du jour" }
        if raw.hasPrefix("once_at:") { return "Message programmé" }
        return "Notification"
    }

    private func eventSupportsSchedulingEditor(_ eventType: String?) -> Bool {
        let t = eventType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return t.hasPrefix("daily_at:") || t.hasPrefix("once_at:")
    }

    private func dailyAtTokenFromLocal(hour: Int, minute: Int) -> String {
        let h = max(0, min(23, hour))
        let m = max(0, min(59, minute))
        guard let localDate = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) else {
            return "daily_at:10:00"
        }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = utcCal.dateComponents([.hour, .minute], from: localDate)
        let uh = max(0, min(23, c.hour ?? 10))
        let um = max(0, min(59, c.minute ?? 0))
        return String(format: "daily_at:%02d:%02d", uh, um)
    }

    private func localComponentsFromDailyUTC(_ token: String) -> (hour: Int, minute: Int)? {
        let t = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard t.hasPrefix("daily_at:") else { return nil }
        let rest = String(t.dropFirst(9))
        let parts = rest.split(separator: ":")
        guard parts.count == 2, let uh = Int(parts[0]), let um = Int(parts[1]) else { return nil }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let utcDate = utcCal.date(bySettingHour: uh, minute: um, second: 0, of: Date()) else { return nil }
        let lc = Calendar.current.dateComponents([.hour, .minute], from: utcDate)
        return (lc.hour ?? 0, lc.minute ?? 0)
    }

    private func parseOnceAtUTCToDate(_ raw: String) -> Date? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = t.lowercased()
        guard let r = lower.range(of: "once_at:") else { return nil }
        let iso = String(t[r.upperBound...])
        let parts = iso.split(separator: "T")
        guard parts.count == 2 else { return nil }
        let ymd = parts[0].split(separator: "-").compactMap { Int($0) }
        let hm = parts[1].split(separator: ":").compactMap { Int($0) }
        guard ymd.count == 3, hm.count >= 2 else { return nil }
        var c = DateComponents()
        c.timeZone = TimeZone(secondsFromGMT: 0)
        c.year = ymd[0]
        c.month = ymd[1]
        c.day = ymd[2]
        c.hour = hm[0]
        c.minute = hm[1]
        return Calendar(identifier: .gregorian).date(from: c)
    }

    private func onceAtTokenUTC(from date: Date) -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(secondsFromGMT: 0)!
        let c = utcCal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        guard let y = c.year, let mo = c.month, let d = c.day, let h = c.hour, let mi = c.minute else {
            return "once_at:2099-01-01T00:00"
        }
        return String(format: "once_at:%04d-%02d-%02dT%02d:%02d", y, mo, d, h, mi)
    }

    private func hydrateScheduleDraft(from rawEventType: String?) {
        let t = rawEventType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if t.hasPrefix("once_at:") {
            scheduleKind = .oneTime
            if let raw = rawEventType, let d = parseOnceAtUTCToDate(raw) {
                oneShotScheduleDate = d
            }
            return
        }
        if t.hasPrefix("daily_at:") {
            scheduleKind = .daily
            if let raw = rawEventType, let lm = localComponentsFromDailyUTC(raw) {
                eventDraftScheduleHour = lm.hour
                eventDraftScheduleMinute = lm.minute
            }
            return
        }
        scheduleKind = .daily
        eventDraftScheduleHour = 10
        eventDraftScheduleMinute = 0
    }

    private func builtScheduledEventTypeTokenForSave() -> String {
        switch scheduleKind {
        case .oneTime:
            return onceAtTokenUTC(from: oneShotScheduleDate)
        case .daily:
            return dailyAtTokenFromLocal(hour: eventDraftScheduleHour, minute: eventDraftScheduleMinute)
        }
    }

    private func readableEventLabel(for eventType: String) -> String {
        let raw = eventType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.hasPrefix("inactive_days:") {
            let value = raw.replacingOccurrences(of: "inactive_days:", with: "")
            let n = max(1, Int(value) ?? 30)
            return "Inactif depuis \(n)j"
        }
        if raw.hasPrefix("daily_at:"), let lm = localComponentsFromDailyUTC(eventType) {
            return String(format: "Chaque jour à %02d:%02d", lm.hour, lm.minute)
        }
        if raw.hasPrefix("once_at:"), let d = parseOnceAtUTCToDate(eventType) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "fr_FR")
            f.dateStyle = .medium
            f.timeStyle = .short
            return "Une fois — \(f.string(from: d))"
        }
        switch raw {
        case "first_scan":
            return "Premier scan"
        case "reward_unlocked":
            return "Récompense débloquée"
        default:
            return eventType.isEmpty ? "Événement" : eventType
        }
    }

    /// Libellés segments alignés sur `CAMPAIGN_SEGMENT_KEYS` (notifications.js côté SaaS).
    private func campaignSegmentCatalogLabel(for key: String) -> String {
        switch key {
        case "inactive14": return "Inactifs 14 jours"
        case "inactive30": return "Inactifs 30 jours"
        case "inactive60": return "Inactifs 60 jours"
        case "inactive90": return "Inactifs 90 jours"
        case "new7": return "Nouveaux (7 jours)"
        case "new30": return "Nouveaux (30 jours)"
        case "pointsNear50": return "Proche de 50 pts"
        case "points50": return "50 points — récompense"
        case "recurrent": return "Clients fidèles"
        case "birthdayToday": return "Anniversaire du jour"
        default:
            return key.isEmpty ? "Segment" : key
        }
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
        let activeCount = family.rules.filter {
            hasCustomNotificationIconFromSettings && (campaignAutomation.rules?[$0.id]?.enabled ?? false)
        }.count
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
                        get: {
                            hasCustomNotificationIconFromSettings
                                && (campaignAutomation.rules?[rule.id]?.enabled ?? false)
                        },
                        set: { on in
                            if on, !requireNotificationIconForSending() { return }
                            var r = campaignAutomation.rules ?? [:]
                            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultAutomationRuleMessages[rule.id] ?? "")
                            row.enabled = on
                            if row.message == nil || row.message?.isEmpty == true {
                                row.message = defaultAutomationRuleMessages[rule.id]
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
                        get: {
                            hasCustomNotificationIconFromSettings
                                && (campaignAutomation.rules?[rule.id]?.enabled ?? false)
                        },
                        set: { on in
                            if on, !requireNotificationIconForSending() { return }
                            var r = campaignAutomation.rules ?? [:]
                            var row = r[rule.id] ?? CampaignAutomationRuleDTO(enabled: false, message: defaultAutomationRuleMessages[rule.id] ?? "")
                            row.enabled = on
                            if row.message == nil || row.message?.isEmpty == true {
                                row.message = defaultAutomationRuleMessages[rule.id]
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
                TextField(
                    "Message",
                    text: Binding(
                        get: { campaignAutomation.rules?[ruleId]?.message ?? defaultAutomationRuleMessages[ruleId] ?? "" },
                        set: { v in
                            var r = campaignAutomation.rules ?? [:]
                            var row = r[ruleId] ?? CampaignAutomationRuleDTO(enabled: false, message: v)
                            row.message = String(v.prefix(200))
                            r[ruleId] = row
                            campaignAutomation.rules = r
                            scheduleCampaignAutomationSave()
                        }
                    ),
                    axis: .vertical
                )
                .lineLimit(4 ... 12)
                .textFieldStyle(.plain)
                .padding(10)
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
        if let t = automationHubRules.first(where: { $0.id == id })?.title {
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
        _ = clearAfterSend
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
            let t = gotSettings.notificationTitleOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                title = t
            }
            // Ne pas préremplir le champ campagne avec `notification_change_message` (gabarit PassKit ≠ message de campagne).
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
                assignMerchantAlertMessage(from: error)
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
        // Flush titre avant envoi (le corps part uniquement via POST /notifications/send).
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
            Task { await syncService.syncIfNeeded() }
            withAnimation(.easeInOut(duration: 0.38)) { notificationSendProgress = 1.0 }

            try? await Task.sleep(nanoseconds: 260_000_000)
        } catch let api as APIError {
            if case .notificationIconRequired = api {
                notificationLogoPopupPresented = true
            } else {
                message = api.errorDescription ?? "Erreur lors de l’envoi de la notification."
            }
        } catch {
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

/// Carte 3D légère (relief + inclinaison) uniquement sur la page « localisation » active du carrousel.
/// La `Map` n’est montée que lorsque cette page est affichée : les autres pages n’affichent qu’un fond léger.
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
        .transaction { $0.animation = nil }
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
        let cameraTaskId = "\(latitude)-\(longitude)-\(radiusCL)-3d"
        return Map(position: $cameraPosition, interactionModes: []) {
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
        .mapStyle(.standard(elevation: .realistic))
        .mapControlVisibility(.hidden)
        .padding(.bottom, -22)
        .padding(.leading, -6)
        .allowsHitTesting(false)
        .clipped()
        .transaction { $0.animation = nil }
        .task(id: cameraTaskId) {
            let distanceMeters = min(780, max(280, radiusCL * 4.6))
            var transaction = Transaction()
            transaction.animation = nil
            withTransaction(transaction) {
                cameraPosition = .camera(
                    MapCamera(centerCoordinate: center, distance: distanceMeters, heading: 12, pitch: 52)
                )
            }
        }
    }
}

// MARK: - Surface aperçu notification (carrousel = carte blanche lisible ; standard = verre)

private extension View {
    @ViewBuilder
    func walletNotificationPreviewSurface(previewSize: WalletNotificationPreviewSize) -> some View {
        let radius = previewSize.glassCornerRadius
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if previewSize == .carousel {
            self
                .background(shape.fill(Color.white))
                .overlay(shape.stroke(Color.black.opacity(0.09), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
        } else {
            self
                .glassEffect(.regularInteractive, cornerRadius: radius)
                .shadow(color: .clear, radius: 0, y: 0)
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
    }
}
#endif
