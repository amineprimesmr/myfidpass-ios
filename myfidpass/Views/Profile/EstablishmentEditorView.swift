//
//  EstablishmentEditorView.swift
//  myfidpass
//
//  Formulaire commerce (identité, coordonnées, réseaux & avis) — utilisé sur l’onglet Commerce.
//

import CoreData
import MapKit
import PhotosUI
import SwiftUI
import UIKit

// MARK: - Réseaux : pseudo / chemin → URL https (sans saisie d’URL complète obligatoire)

private enum SocialLinkMode: Hashable {
    case google, instagram, tiktok, facebook, twitter, snapchat, linkedin, youtube, trustpilot, tripadvisor

    /// Masquage UI « Avis & réseaux » uniquement (données / API inchangées).
    var isTemporarilyHiddenInAvisReseaux: Bool {
        guard EngagementTemporaryVisibility.hideSecondaryReviewNetworks else { return false }
        switch self {
        case .twitter, .snapchat, .linkedin, .trustpilot, .tripadvisor: return true
        default: return false
        }
    }

    /// Réseaux où l’on saisit surtout un pseudo ou un court chemin ; les deux derniers attendent plutôt l’URL de la page avis.
    var prefersShortInput: Bool {
        switch self {
        case .trustpilot, .tripadvisor: return false
        default: return true
        }
    }

    /// Lance l’app du réseau sans rien saisir (compte déjà connecté sur l’iPhone).
    func launchAppButtonTitle(shortName: String) -> String {
        "Ouvrir \(shortName)"
    }

    /// Ouvre le lien enregistré une fois le pseudo / collage renseigné.
    func previewButtonTitle(shortName: String) -> String {
        "Voir \(shortName)"
    }

    var pasteButtonTitle: String { "Coller le lien" }

    var fieldPlaceholder: String {
        switch self {
        case .google: return "Place ID Google (ex: ChIJ...)"
        case .instagram: return "Optionnel : pseudo ou lien du profil"
        case .tiktok: return "Optionnel : pseudo ou lien"
        case .facebook: return "Optionnel : nom de page ou lien"
        case .twitter: return "Votre nom d’utilisateur X ou lien du profil"
        case .snapchat: return "Optionnel : nom d’utilisateur ou lien"
        case .linkedin: return "Optionnel : ex. company/… ou lien"
        case .youtube: return "Optionnel : @chaîne ou lien"
        case .trustpilot: return "URL de votre page Trustpilot"
        case .tripadvisor: return "URL de votre page Tripadvisor"
        }
    }

    var helperCaption: String {
        switch self {
        case .google:
            return "Liez la fiche Google Maps de votre commerce : recherche ou Place ID — ouvrez l’écran dédié."
        case .instagram, .facebook:
            return "Si la connexion Meta échoue : copiez le lien public Instagram ou Page Facebook, puis collez-le ici."
        case .tiktok:
            return "Si la connexion TikTok échoue : collez l’URL du profil TikTok ici."
        case .youtube:
            return "Si la connexion YouTube échoue : collez l’URL de votre chaîne ici."
        case .twitter, .snapchat, .linkedin:
            return "Collez l’URL publique de votre profil (OAuth non disponible pour ce réseau)."
        case .trustpilot, .tripadvisor:
            return "Ouvrez le site depuis le bouton ci‑dessous, connectez‑vous à votre page avis, copiez l’URL puis touchez « Coller le lien »."
        }
    }

    /// Texte affiché quand une URL est déjà enregistrée côté serveur.
    static func displayInput(fromStoredURL url: String, mode: SocialLinkMode) -> String {
        let t = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        if mode == .google { return t }
        guard let u = URL(string: t), u.host != nil else {
            return t
        }
        let path = u.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = path.split(separator: "/").map(String.init)
        switch mode {
        case .google:
            return t
        case .instagram, .facebook, .twitter:
            return parts.first ?? path
        case .tiktok:
            if let p = parts.first, p.hasPrefix("@") { return String(p.dropFirst()) }
            return parts.first ?? path
        case .snapchat:
            if parts.count >= 2, parts[0].lowercased() == "add" { return parts[1] }
            return parts.last ?? path
        case .linkedin:
            return path
        case .youtube:
            if path.hasPrefix("@") {
                return String(path.dropFirst()).split(separator: "/").first.map(String.init) ?? path
            }
            return path.split(separator: "/").first.map(String.init) ?? path
        case .trustpilot, .tripadvisor:
            return t
        }
    }

    func resolvedHTTPSURL(from raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "" }
        let lower = t.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") { return t }

        let h = t.trimmingCharacters(in: CharacterSet(charactersIn: "@/ "))
        if h.isEmpty { return "" }

        switch self {
        case .google:
            return t
        case .instagram:
            return "https://instagram.com/\(h)"
        case .tiktok:
            return "https://www.tiktok.com/@\(h)"
        case .facebook:
            return "https://www.facebook.com/\(h)"
        case .twitter:
            return "https://x.com/\(h)"
        case .snapchat:
            return "https://www.snapchat.com/add/\(h)"
        case .linkedin:
            return "https://www.linkedin.com/\(h)"
        case .youtube:
            let name = h.hasPrefix("@") ? String(h.dropFirst()) : h
            return "https://www.youtube.com/@\(name)"
        case .trustpilot, .tripadvisor:
            if lower.contains("trustpilot.com") || lower.contains("tripadvisor.") {
                return lower.hasPrefix("http") ? t : "https://\(t)"
            }
            return "https://\(t)"
        }
    }

    /// Ouvre l’app du réseau (ou la page d’accueil web) **sans** pseudo : le commerçant est en général déjà connecté sur son téléphone.
    @MainActor
    func openAppEntry() {
        guard let s = appEntryURLString() else { return }
        if s == "instagram://" {
            if let direct = URL(string: s) {
                UIApplication.shared.open(direct, options: [:], completionHandler: nil)
            } else if let web = URL(string: "https://www.instagram.com/") {
                UIApplication.shared.open(web, options: [:], completionHandler: nil)
            }
            return
        }
        guard let url = Self.makeOpenableURL(from: s) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func appEntryURLString() -> String? {
        switch self {
        case .google:
            return "https://maps.google.com/"
        case .instagram:
            return "instagram://"
        case .tiktok:
            return "https://www.tiktok.com/"
        case .facebook:
            return "https://www.facebook.com/"
        case .twitter:
            return "https://x.com/"
        case .snapchat:
            return "https://www.snapchat.com/"
        case .linkedin:
            return "https://www.linkedin.com/"
        case .youtube:
            return "https://www.youtube.com/"
        case .trustpilot:
            return "https://www.trustpilot.com/"
        case .tripadvisor:
            return "https://www.tripadvisor.com/"
        }
    }

    /// Ouvre le lien **profil** construit à partir du champ (pseudo / URL) — après saisie ou collage.
    @MainActor
    func openExternally(from raw: String) {
        let webStr = resolvedHTTPSURL(from: raw)
        guard !webStr.isEmpty else { return }

        let httpsURL = Self.makeOpenableURL(from: webStr)
        guard let httpsURL else { return }

        if self == .instagram {
            let handle = Self.displayInput(fromStoredURL: webStr, mode: .instagram)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !handle.isEmpty {
                var c = URLComponents()
                c.scheme = "instagram"
                c.host = "user"
                c.queryItems = [URLQueryItem(name: "username", value: handle)]
                if let ig = c.url {
                    UIApplication.shared.open(ig, options: [:]) { success in
                        if !success {
                            DispatchQueue.main.async {
                                UIApplication.shared.open(httpsURL, options: [:], completionHandler: nil)
                            }
                        }
                    }
                    return
                }
            }
        }

        UIApplication.shared.open(httpsURL, options: [:], completionHandler: nil)
    }

    /// Construit une URL exploitable par le système (évite les échecs silencieux de `URL(string:)` avec espaces / caractères spéciaux).
    private static func makeOpenableURL(from string: String) -> URL? {
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        if #available(iOS 17.0, *) {
            return URL(string: t, encodingInvalidCharacters: true)
        }
        return URL(string: t)
    }
}
// MARK: - État missions engagement (GET → formulaire → PATCH)

private struct UrlChannelForm: Equatable {
    /// Pseudo, chemin court ou URL complète (Trustpilot / Tripadvisor / collage).
    var input: String

    init(_ ch: EngagementChannelDTO?, mode: SocialLinkMode) {
        let stored = ch?.url ?? ""
        input = SocialLinkMode.displayInput(fromStoredURL: stored, mode: mode)
    }

    func toPatchField(mode: SocialLinkMode) -> EngagementRewardsFullPatch.SimpleUrlPatch {
        let u = mode.resolvedHTTPSURL(from: input).trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(enabled: !u.isEmpty, points: 1, url: u)
    }
}

private struct EngagementFormState: Equatable {
    var googlePlaceId: String
    var googleAutoVerify: Bool
    var instagram: UrlChannelForm
    var tiktok: UrlChannelForm
    var facebook: UrlChannelForm
    var twitter: UrlChannelForm
    var snapchat: UrlChannelForm
    var linkedin: UrlChannelForm
    var youtube: UrlChannelForm
    var trustpilot: UrlChannelForm
    var tripadvisor: UrlChannelForm

    init(from dto: EngagementRewardsDTO?) {
        let g = dto?.googleReview
        googlePlaceId = g?.placeId ?? ""
        googleAutoVerify = g?.autoVerifyEnabled ?? true
        instagram = .init(dto?.instagramFollow, mode: .instagram)
        tiktok = .init(dto?.tiktokFollow, mode: .tiktok)
        facebook = .init(dto?.facebookFollow, mode: .facebook)
        twitter = .init(dto?.twitterFollow, mode: .twitter)
        snapchat = .init(dto?.snapchatFollow, mode: .snapchat)
        linkedin = .init(dto?.linkedinFollow, mode: .linkedin)
        youtube = .init(dto?.youtubeFollow, mode: .youtube)
        trustpilot = .init(dto?.trustpilotReview, mode: .trustpilot)
        tripadvisor = .init(dto?.tripadvisorReview, mode: .tripadvisor)
    }

    func toPatch() -> EngagementRewardsFullPatch {
        let place = googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let googlePatch = EngagementRewardsFullPatch.GoogleReviewPatch(
            enabled: !place.isEmpty,
            points: 1,
            placeId: place,
            autoVerifyEnabled: googleAutoVerify
        )
        return EngagementRewardsFullPatch(
            googleReview: googlePatch,
            instagramFollow: instagram.toPatchField(mode: .instagram),
            tiktokFollow: tiktok.toPatchField(mode: .tiktok),
            facebookFollow: facebook.toPatchField(mode: .facebook),
            twitterFollow: twitter.toPatchField(mode: .twitter),
            snapchatFollow: snapchat.toPatchField(mode: .snapchat),
            linkedinFollow: linkedin.toPatchField(mode: .linkedin),
            youtubeFollow: youtube.toPatchField(mode: .youtube),
            trustpilotReview: trustpilot.toPatchField(mode: .trustpilot),
            tripadvisorReview: tripadvisor.toPatchField(mode: .tripadvisor)
        )
    }
}

// MARK: - Feuille modale unique

/// Feuille unique pour les réseaux qui nécessitent une saisie manuelle.
private enum MerchantEstablishmentActiveSheet: Identifiable {
    case socialEdit(SocialLinkMode, String)
    case socialMissions

    var id: String {
        switch self {
        case .socialEdit(let mode, let label):
            return "social-\(label)-\(String(describing: mode))"
        case .socialMissions:
            return "social-missions"
        }
    }
}

// MARK: - Formulaire principal

struct MerchantEstablishmentForm: View {
    struct Sections {
        var showIdentity: Bool = true
        var showContact: Bool = true
        var showEngagement: Bool = true
        var mergeEngagementIntoSingleCard: Bool = false
        /// Masque le titre « Avis & réseaux » sur la carte (ex. checklist Commerce où le titre est déjà affiché au-dessus).
        var hideEngagementCardTitle: Bool = false
        /// Carte métriques (OAuth, rafraîchissement).
        var showSocialMetrics: Bool = true
        /// Instagram, TikTok, Facebook, YouTube, X, etc. — désactivé sur l’onglet Commerce (Google / Place ID uniquement).
        var showSocialNetworksEngagement: Bool = true
        /// Bandeau métriques OAuth (Meta, YouTube, TikTok) — masqué si seul Google (Place ID) est proposé.
        var showSocialMetricsOAuthCard: Bool = true
        /// Onglet Commerce : tableau de bord avis Google (graphique, synchro auto) à la place de la ligne cliquable.
        var useGoogleCommerceDashboard: Bool = false
        /// Ne pas envelopper le bloc engagement dans `sectionCard` — la carte est fournie par le parent (ex. onglet Commerce).
        var embedEngagementWithoutSectionCard: Bool = false
        /// Passé au tableau de bord : masque la ligne de titre interne quand le parent affiche déjà un en-tête.
        var suppressGoogleDashboardTitleRow: Bool = false

        static let full = Sections()
        static let engagementOnly = Sections(showIdentity: false, showContact: false, showEngagement: true, mergeEngagementIntoSingleCard: true)
        /// Onglet Commerce — avis Google seul : pas de carte interne, titre géré par `ProfileView`.
        static let commerceGoogleStandalone = Sections(
            showIdentity: false,
            showContact: false,
            showEngagement: true,
            mergeEngagementIntoSingleCard: true,
            hideEngagementCardTitle: true,
            showSocialNetworksEngagement: false,
            showSocialMetricsOAuthCard: false,
            useGoogleCommerceDashboard: true,
            embedEngagementWithoutSectionCard: true,
            suppressGoogleDashboardTitleRow: true
        )
    }

    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService

    @State private var organizationName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var logoURL: String = ""
    @State private var logoIconURL: String = ""
    @State private var logoPhotoItem: PhotosPickerItem?
    @State private var logoIconPhotoItem: PhotosPickerItem?
    @State private var imageCropPayload: ImageCropPayload?
    @State private var engagement: EngagementFormState = .init(from: nil)
    @State private var isSaving = false
    @State private var savedMessage: String?
    @State private var profileSaveError: String?
    @State private var activeSheet: MerchantEstablishmentActiveSheet?
    /// OAuth en cours (Meta = Instagram + Page Facebook).
    @State private var oauthBusy: EngagementOAuthBusyKind?
    @State private var suppressAutosave = true
    @State private var autosaveTask: Task<Void, Never>?
    /// Métriques Google (avis / note) — même API que la carte métriques, affichées dans la ligne Google.
    @State private var googleMetricsChannel: SocialMetricsChannelRow?
    @State private var googleMetricsLoading = false
    @State private var googleMetricsRefreshing = false
    /// Pseudos @ enregistrés via « Connecter mes réseaux » (social-missions API).
    @State private var socialMissionsCache: SocialMissionsResponse?
    private let sections: Sections

    private enum EngagementOAuthBusyKind: Hashable {
        case meta, youtube, tiktok, googleBusiness
    }

    init(context: NSManagedObjectContext, sections: Sections = .full) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
        self.sections = sections
    }

    /// Carte fusionnée : titre/icône adaptés quand seuls les avis Google sont affichés.
    private var mergedEngagementCardTitle: String? {
        if sections.hideEngagementCardTitle { return nil }
        if !sections.showSocialNetworksEngagement { return "Avis Google" }
        return "Avis & réseaux"
    }

    private var mergedEngagementCardSystemImage: String? {
        if sections.hideEngagementCardTitle { return nil }
        if !sections.showSocialNetworksEngagement { return "star.bubble" }
        return "bubble.left.and.bubble.right.fill"
    }

    @ViewBuilder
    private func engagementMergedInnerContent() -> some View {
        if !EngagementTemporaryVisibility.hideGoogleReviewsUI {
            if sections.useGoogleCommerceDashboard {
                GoogleReviewsCommerceDashboardView(
                    placeIdTrimmed: engagement.googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines),
                    showTitleRow: !sections.suppressGoogleDashboardTitleRow,
                    emptyStateHighlightsConfigureButton: true
                )
                googleCommerceConfigureButton
                connectSocialNetworksButton
            } else {
                socialGoogleRow()
            }
        }
        if sections.showSocialNetworksEngagement {
            socialEngagementRow(mode: .instagram, shortName: "Instagram", channel: $engagement.instagram)
            socialEngagementRow(mode: .tiktok, shortName: "TikTok", channel: $engagement.tiktok)
            socialEngagementRow(mode: .facebook, shortName: "Facebook", channel: $engagement.facebook)
            if !SocialLinkMode.twitter.isTemporarilyHiddenInAvisReseaux {
                socialEngagementRow(mode: .twitter, shortName: "X", channel: $engagement.twitter)
            }
            if !SocialLinkMode.snapchat.isTemporarilyHiddenInAvisReseaux {
                socialEngagementRow(mode: .snapchat, shortName: "Snapchat", channel: $engagement.snapchat)
            }
            if !SocialLinkMode.linkedin.isTemporarilyHiddenInAvisReseaux {
                socialEngagementRow(mode: .linkedin, shortName: "LinkedIn", channel: $engagement.linkedin)
            }
            socialEngagementRow(mode: .youtube, shortName: "YouTube", channel: $engagement.youtube)
            if !SocialLinkMode.trustpilot.isTemporarilyHiddenInAvisReseaux {
                socialEngagementRow(mode: .trustpilot, shortName: "Trustpilot", channel: $engagement.trustpilot)
            }
            if !SocialLinkMode.tripadvisor.isTemporarilyHiddenInAvisReseaux {
                socialEngagementRow(mode: .tripadvisor, shortName: "Tripadvisor", channel: $engagement.tripadvisor)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if sections.showIdentity {
            sectionCard(title: "Identité", systemImage: "building.2") {
                labeledField("Nom affiché", caption: "Carte, pass Wallet et fiche.") {
                    TextField("Ex. Café de la Gare", text: $organizationName)
                        .textFieldStyle(.roundedBorder)
                }
                logoBlock(
                    title: "Logo bandeau carte",
                    caption: nil,
                    url: $logoURL,
                    pickerItem: $logoPhotoItem,
                    pickIcon: "photo.badge.plus",
                    corner: 12,
                    onPick: { item in
                        await loadLogoFromPicker(item)
                    }
                )
                logoBlock(
                    title: "Logo carré",
                    caption: "Notifications et aperçu profil — idéalement 512×512 px.",
                    url: $logoIconURL,
                    pickerItem: $logoIconPhotoItem,
                    pickIcon: "square.grid.3x3.fill",
                    corner: 14,
                    onPick: { item in
                        await loadLogoIconFromPicker(item)
                    }
                )
            }
            }

            if sections.showContact {
                sectionCard(title: "Coordonnées", systemImage: "mappin.and.ellipse") {
                    labeledField("Adresse", caption: nil) {
                        AddressSearchField(text: $address, placeholder: "Rechercher une adresse…")
                    }
                    labeledField("Téléphone", caption: nil) {
                        TextField("06 12 34 56 78", text: $phone)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.phonePad)
                    }
                    labeledField("E-mail de contact", caption: nil) {
                        TextField("contact@exemple.fr", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                }
            }

            if sections.showEngagement && sections.showSocialMetrics && sections.showSocialMetricsOAuthCard {
                SocialMetricsEngagementSection()
            }

            if sections.showEngagement {
                if sections.mergeEngagementIntoSingleCard {
                    Group {
                        if sections.embedEngagementWithoutSectionCard {
                            engagementMergedInnerContent()
                        } else if sections.hideEngagementCardTitle {
                            sectionCard(title: nil, systemImage: nil) {
                                engagementMergedInnerContent()
                            }
                        } else if !sections.showSocialNetworksEngagement, !EngagementTemporaryVisibility.hideGoogleReviewsUI {
                            sectionCard(title: mergedEngagementCardTitle ?? "Avis Google", headerAssetName: "SocialGoogle") {
                                engagementMergedInnerContent()
                            }
                        } else {
                            sectionCard(
                                title: mergedEngagementCardTitle,
                                systemImage: mergedEngagementCardSystemImage
                            ) {
                                engagementMergedInnerContent()
                            }
                        }
                    }
                } else if !EngagementTemporaryVisibility.hideGoogleReviewsUI {
                    sectionCard(title: "Avis Google", headerAssetName: "SocialGoogle") {
                        if sections.useGoogleCommerceDashboard {
                            GoogleReviewsCommerceDashboardView(
                                placeIdTrimmed: engagement.googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines),
                                showTitleRow: !sections.suppressGoogleDashboardTitleRow,
                                emptyStateHighlightsConfigureButton: true
                            )
                            googleCommerceConfigureButton
                        } else {
                            socialGoogleRow()
                        }
                    }
                }

            if sections.showSocialNetworksEngagement {
                sectionCard(title: "Réseaux sociaux", systemImage: "bubble.left.and.bubble.right") {
                    socialEngagementRow(mode: .instagram, shortName: "Instagram", channel: $engagement.instagram)
                    socialEngagementRow(mode: .tiktok, shortName: "TikTok", channel: $engagement.tiktok)
                    socialEngagementRow(mode: .facebook, shortName: "Facebook", channel: $engagement.facebook)
                    if !SocialLinkMode.twitter.isTemporarilyHiddenInAvisReseaux {
                        socialEngagementRow(mode: .twitter, shortName: "X", channel: $engagement.twitter)
                    }
                    if !SocialLinkMode.snapchat.isTemporarilyHiddenInAvisReseaux {
                        socialEngagementRow(mode: .snapchat, shortName: "Snapchat", channel: $engagement.snapchat)
                    }
                    if !SocialLinkMode.linkedin.isTemporarilyHiddenInAvisReseaux {
                        socialEngagementRow(mode: .linkedin, shortName: "LinkedIn", channel: $engagement.linkedin)
                    }
                    socialEngagementRow(mode: .youtube, shortName: "YouTube", channel: $engagement.youtube)
                }

                if !SocialLinkMode.trustpilot.isTemporarilyHiddenInAvisReseaux || !SocialLinkMode.tripadvisor.isTemporarilyHiddenInAvisReseaux {
                    sectionCard(title: "Autres avis", systemImage: "text.quote") {
                        if !SocialLinkMode.trustpilot.isTemporarilyHiddenInAvisReseaux {
                            socialEngagementRow(mode: .trustpilot, shortName: "Trustpilot", channel: $engagement.trustpilot)
                        }
                        if !SocialLinkMode.tripadvisor.isTemporarilyHiddenInAvisReseaux {
                            socialEngagementRow(mode: .tripadvisor, shortName: "Tripadvisor", channel: $engagement.tripadvisor)
                        }
                    }
                }
            }
            }

            if let msg = savedMessage {
                Label(msg, systemImage: "checkmark.circle.fill")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.success)
            }
            if let err = profileSaveError {
                Text(err)
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.error)
            }
        }
        .onAppear {
            loadProfile()
            Task {
                await loadProfileFromServer()
                await loadSocialMissionsCache()
                await MainActor.run { suppressAutosave = false }
                if !sections.useGoogleCommerceDashboard {
                    await loadGoogleMetricsSnapshot()
                }
            }
        }
        .onChange(of: organizationName) { _, _ in scheduleAutosave() }
        .onChange(of: email) { _, _ in scheduleAutosave() }
        .onChange(of: phone) { _, _ in scheduleAutosave() }
        .onChange(of: address) { _, _ in scheduleAutosave() }
        .onChange(of: logoURL) { _, _ in scheduleAutosave() }
        .onChange(of: logoIconURL) { _, _ in scheduleAutosave() }
        .onChange(of: engagement) { _, _ in scheduleAutosave() }
        .onChange(of: engagement.googlePlaceId) { _, _ in
            if !sections.useGoogleCommerceDashboard {
                Task { await loadGoogleMetricsSnapshot() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassEngagementOAuthDidComplete)) { _ in
            Task {
                await loadProfileFromServer()
                if !sections.useGoogleCommerceDashboard {
                    await loadGoogleMetricsSnapshot()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassSocialMissionsDidSave)) { _ in
            Task { await loadSocialMissionsCache() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenGoogleBusinessSetupSheet)) { _ in
            runEngagementOAuth(.googleBusiness)
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassAdoptMatchedGooglePlaceId)) { note in
            guard let placeId = note.userInfo?["placeId"] as? String,
                  !placeId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            engagement.googlePlaceId = placeId
            scheduleAutosave()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .socialEdit(let mode, let title):
                NavigationStack {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(mode.helperCaption)
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(mode.fieldPlaceholder, text: socialInputBinding(mode: mode))
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .keyboardType(mode.prefersShortInput ? .asciiCapable : .URL)
                            .autocorrectionDisabled()
                            .padding(.top, 4)
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Terminé") { activeSheet = nil }
                                .fontWeight(.semibold)
                        }
                    }
                }
            case .socialMissions:
                if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                    SocialMissionsSheet(slug: slug) {
                        Task { await loadSocialMissionsCache() }
                    }
                } else {
                    Text("Commerce non chargé").padding()
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        sectionCard(title: title as String?, systemImage: systemImage as String?, content: content)
    }

    /// En-tête de section avec image depuis les assets (ex. `SocialGoogle`).
    private func sectionCard<Content: View>(title: String, headerAssetName: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(headerAssetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 6, y: 2)
    }

    private func sectionCard<Content: View>(title: String?, systemImage: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title, let systemImage {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(title)
                        .font(AppTheme.Fonts.headline())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: AppTheme.Colors.shadow, radius: 6, y: 2)
    }

    private func labeledField<C: View>(_ title: String, caption: String?, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if caption != nil { EmptyView() }
            content()
        }
    }

    private func logoBlock(
        title: String,
        caption: String?,
        url: Binding<String>,
        pickerItem: Binding<PhotosPickerItem?>,
        pickIcon: String,
        corner: CGFloat,
        onPick: @escaping (PhotosPickerItem?) async -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if caption != nil { EmptyView() }
            HStack(spacing: AppTheme.Spacing.md) {
                BusinessLogoView(logoURL: url.wrappedValue.isEmpty ? nil : url.wrappedValue, size: 56, cornerRadius: corner)
                PhotosPicker(selection: pickerItem, matching: .images, photoLibrary: .shared()) {
                    Label("Changer", systemImage: pickIcon)
                }
                .onChange(of: pickerItem.wrappedValue) { _, new in
                    guard new != nil else { return }
                    Task { await onPick(new) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func scheduleAutosave() {
        guard !suppressAutosave else { return }
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await saveProfile()
        }
    }

    private func handleSocialRowTap(mode: SocialLinkMode, shortName: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch mode {
        case .google:
            runEngagementOAuth(.googleBusiness)
        case .instagram, .facebook:
            runEngagementOAuth(.meta)
        case .youtube:
            runEngagementOAuth(.youtube)
        case .tiktok:
            runEngagementOAuth(.tiktok)
        case .twitter, .snapchat, .linkedin, .trustpilot, .tripadvisor:
            activeSheet = .socialEdit(mode, shortName)
        }
    }

    private func runEngagementOAuth(_ kind: EngagementOAuthBusyKind) {
        guard oauthBusy == nil else { return }
        oauthBusy = kind
        profileSaveError = nil
        Task {
            let outcome: EngagementOAuthLauncher.Outcome
            switch kind {
            case .meta:
                outcome = await EngagementOAuthLauncher.connectMeta()
            case .youtube:
                outcome = await EngagementOAuthLauncher.connectYouTube()
            case .tiktok:
                outcome = await EngagementOAuthLauncher.connectTikTok()
            case .googleBusiness:
                outcome = await EngagementOAuthLauncher.connectGoogleBusiness()
            }
            await MainActor.run {
                oauthBusy = nil
                switch outcome {
                case .success:
                    savedMessage = "Compte connecté"
                    profileSaveError = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if savedMessage == "Compte connecté" { savedMessage = nil }
                    }
                    NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
                case .failure(let msg):
                    profileSaveError = msg
                case .cancelled:
                    break
                }
            }
        }
    }

    /// Liaison directe au formulaire pour sauvegardes automatiques via `onChange(of: engagement)`.
    private func socialInputBinding(mode: SocialLinkMode) -> Binding<String> {
        Binding(
            get: {
                switch mode {
                case .google: return engagement.googlePlaceId
                case .instagram: return engagement.instagram.input
                case .tiktok: return engagement.tiktok.input
                case .facebook: return engagement.facebook.input
                case .twitter: return engagement.twitter.input
                case .snapchat: return engagement.snapchat.input
                case .linkedin: return engagement.linkedin.input
                case .youtube: return engagement.youtube.input
                case .trustpilot: return engagement.trustpilot.input
                case .tripadvisor: return engagement.tripadvisor.input
                }
            },
            set: { newValue in
                var e = engagement
                switch mode {
                case .google:
                    e.googlePlaceId = newValue
                case .instagram:
                    var c = e.instagram
                    c.input = newValue
                    e.instagram = c
                case .tiktok:
                    var c = e.tiktok
                    c.input = newValue
                    e.tiktok = c
                case .facebook:
                    var c = e.facebook
                    c.input = newValue
                    e.facebook = c
                case .twitter:
                    var c = e.twitter
                    c.input = newValue
                    e.twitter = c
                case .snapchat:
                    var c = e.snapchat
                    c.input = newValue
                    e.snapchat = c
                case .linkedin:
                    var c = e.linkedin
                    c.input = newValue
                    e.linkedin = c
                case .youtube:
                    var c = e.youtube
                    c.input = newValue
                    e.youtube = c
                case .trustpilot:
                    var c = e.trustpilot
                    c.input = newValue
                    e.trustpilot = c
                case .tripadvisor:
                    var c = e.tripadvisor
                    c.input = newValue
                    e.tripadvisor = c
                }
                engagement = e
            }
        )
    }

    private func loadSocialMissionsCache() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run { socialMissionsCache = nil }
            return
        }
        do {
            let resp: SocialMissionsResponse = try await APIClient.shared.request(.dashboardSocialMissions(slug: slug))
            await MainActor.run { socialMissionsCache = resp }
        } catch {
            if !APIError.isBenignRequestCancellation(error) {
                await MainActor.run { socialMissionsCache = nil }
            }
        }
    }

    private func socialMissionConfig(for mode: SocialLinkMode) -> SocialMissionConfig? {
        guard let cache = socialMissionsCache else { return nil }
        switch mode {
        case .instagram: return cache.instagram
        case .tiktok: return cache.tiktok
        case .facebook: return cache.facebook
        case .twitter: return cache.twitter
        default: return nil
        }
    }

    private func socialRowSubtitle(mode: SocialLinkMode, channel: UrlChannelForm) -> String {
        if let cfg = socialMissionConfig(for: mode) {
            let u = cfg.username.trimmingCharacters(in: .whitespacesAndNewlines)
            if !u.isEmpty {
                let at = "@\(u)"
                if cfg.enabled {
                    return "\(at) · +\(cfg.points) pts client"
                }
                return at
            }
        }
        let handle = channel.input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !handle.isEmpty {
            let display = handle.hasPrefix("@") ? handle : "@\(handle)"
            return display
        }
        switch mode {
        case .instagram, .facebook, .youtube, .tiktok:
            return "Toucher pour connecter le compte"
        default:
            return "Toucher pour saisir ou coller un lien"
        }
    }

    private var connectSocialNetworksSubtitle: String {
        guard let cache = socialMissionsCache else {
            return "Instagram, TikTok, Facebook, X — missions & points clients"
        }
        let labels: [(String, SocialMissionConfig?)] = [
            ("IG", cache.instagram),
            ("TikTok", cache.tiktok),
            ("FB", cache.facebook),
            ("X", cache.twitter),
        ]
        let connected = labels.compactMap { tag, cfg -> String? in
            guard let cfg, cfg.enabled else { return nil }
            let u = cfg.username.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !u.isEmpty else { return nil }
            return "\(tag) @\(u)"
        }
        if connected.isEmpty {
            return "Configurer les @ et les points offerts aux clients"
        }
        return connected.joined(separator: " · ")
    }

    private func socialEngagementRow(mode: SocialLinkMode, shortName: String, channel: Binding<UrlChannelForm>) -> some View {
        let subtitle = socialRowSubtitle(mode: mode, channel: channel.wrappedValue)
        let oauthBusyHere: Bool = {
            switch mode {
            case .instagram, .facebook: return oauthBusy == .meta
            case .youtube: return oauthBusy == .youtube
            case .tiktok: return oauthBusy == .tiktok
            default: return false
            }
        }()
        return Button {
            handleSocialRowTap(mode: mode, shortName: shortName)
        } label: {
            HStack(spacing: 10) {
                socialPlatformBadge(mode: mode)
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if oauthBusyHere {
                    ProgressView()
                        .scaleEffect(0.9)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(oauthBusyHere)
        .contextMenu {
            if mode == .instagram || mode == .facebook || mode == .youtube || mode == .tiktok {
                Button("Saisir ou coller un lien") {
                    activeSheet = .socialEdit(mode, shortName)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, cornerRadius: 16)
        .padding(.vertical, 4)
    }

    private func loadGoogleMetricsSnapshot() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            await MainActor.run { googleMetricsChannel = nil }
            return
        }
        let showLoadingSpinner = await MainActor.run { googleMetricsChannel == nil }
        if showLoadingSpinner {
            await MainActor.run { googleMetricsLoading = true }
        }
        defer {
            Task { @MainActor in
                googleMetricsLoading = false
            }
        }
        do {
            let s: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetrics(slug: slug))
            await MainActor.run {
                googleMetricsChannel = s.channels.first { $0.channel == "google_review" }
            }
        } catch {
            if APIError.isBenignRequestCancellation(error) {
                return
            }
            await MainActor.run { googleMetricsChannel = nil }
        }
    }

    private func refreshGoogleMetricsFromPlaces() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        await MainActor.run { googleMetricsRefreshing = true }
        defer { Task { @MainActor in googleMetricsRefreshing = false } }
        do {
            let _: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetricsRefresh(slug: slug))
            await loadGoogleMetricsSnapshot()
        } catch {}
    }

    /// CTA en bas de la section Google (onglet Commerce).
    @ViewBuilder
    private var googleCommerceConfigureButton: some View {
        let gbpConnected = (googleMetricsChannel?.oauthConnected == true)
        VStack(spacing: 10) {
            // Carte principale TOUJOURS visible : tableau de bord complet Google Business (gère lui-même
            // l'état « non connecté » en proposant un CTA de connexion OAuth).
            if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                NavigationLink {
                    GoogleBusinessHubView(slug: slug)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.white.opacity(0.18))
                                .frame(width: 40, height: 40)
                            Image(systemName: "sparkles")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Tableau de bord Google Business")
                                    .font(.subheadline.weight(.bold))
                                Text("NEW")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.white))
                            }
                            Text(gbpConnected
                                 ? "Avis live, IA, posts, Q&A, stats, horaires, photos"
                                 : "Connectez-vous pour gérer avis live, posts, Q&A, stats…")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.92))
                                .lineLimit(2)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.13, green: 0.45, blue: 0.99), Color(red: 0.48, green: 0.25, blue: 0.95)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: AppTheme.Colors.primary.opacity(0.35), radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                runEngagementOAuth(.googleBusiness)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: gbpConnected ? "link.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text(gbpConnected ? "Reconnecter Google Business" : "Connecter Google Business")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if oauthBusy == .googleBusiness {
                        ProgressView()
                            .scaleEffect(0.9)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .disabled(oauthBusy != nil)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.primary.opacity(0.22), lineWidth: 1)
            )
        }
        .padding(.top, 8)
    }

    /// Bouton "Connecter mes réseaux" — ouvre SocialMissionsSheet (Instagram, TikTok, Facebook, X).
    private var connectSocialNetworksButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            activeSheet = .socialMissions
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "person.2.wave.2.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connecter mes réseaux")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(connectSocialNetworksSubtitle)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.Colors.primary.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.Colors.primary.opacity(0.18), lineWidth: 1)
        )
    }

    /// Ligne Google : logo seul à gauche, capsule note + avis à droite (pas de libellé « Google », pas de Place ID).
    private func socialGoogleRow() -> some View {
        let placeLinked = !engagement.googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return Button {
            handleSocialRowTap(mode: .google, shortName: "Avis Google")
        } label: {
            HStack(spacing: 14) {
                socialPlatformBadge(mode: .google)
                    .frame(width: 30, height: 30)
                Spacer(minLength: 8)
                googleInlineMetricsPill(placeLinked: placeLinked)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, cornerRadius: 16)
        .padding(.vertical, 4)
        .contextMenu {
            if placeLinked {
                Button {
                    Task { await refreshGoogleMetricsFromPlaces() }
                } label: {
                    if googleMetricsRefreshing {
                        Label("Rafraîchissement…", systemImage: "arrow.clockwise")
                    } else {
                        Label("Rafraîchir les avis", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(googleMetricsRefreshing)
            }
        }
    }

    @ViewBuilder
    private func googleInlineMetricsPill(placeLinked: Bool) -> some View {
        if googleMetricsLoading {
            ProgressView()
                .scaleEffect(0.85)
                .frame(minWidth: 72, alignment: .trailing)
        } else if !placeLinked {
            Text("Configurer")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.Colors.textSecondary.opacity(0.08))
                .clipShape(Capsule())
        } else if let latest = googleMetricsChannel?.latest {
            let m = latest.metrics
            let rating = m["rating"]
            let count = m["reviews_count"]
            if rating != nil || count != nil {
                HStack(spacing: 8) {
                    if let r = rating {
                        HStack(spacing: 3) {
                            Text("★")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
                            Text(String(format: "%.1f", r))
                                .font(.system(size: 15, weight: .semibold, design: .default))
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                        }
                    }
                    if let c = count {
                        if rating != nil {
                            Text("·")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.45))
                        }
                        Text("\(Int(c)) avis")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.08)))
                .overlay(Capsule().strokeBorder(AppTheme.Colors.primary.opacity(0.12), lineWidth: 1))
            } else {
                googleMetricsEmptyDashPill()
            }
        } else {
            googleMetricsEmptyDashPill()
        }
    }

    private func googleMetricsEmptyDashPill() -> some View {
        Text("—")
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.Colors.textSecondary.opacity(0.06))
            .clipShape(Capsule())
    }

    private func socialPlatformBadge(mode: SocialLinkMode) -> some View {
        let assetName = socialPlatformAssetName(mode: mode)
        return Group {
            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.black)
                    Image(systemName: mode == .twitter ? "xmark" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 22, height: 22)
            }
        }
    }

    private func socialPlatformAssetName(mode: SocialLinkMode) -> String? {
        switch mode {
        case .google:
            return "SocialGoogle"
        case .instagram:
            return "SocialInstagram"
        case .tiktok:
            return "SocialTikTok"
        case .facebook:
            return "SocialFacebook"
        case .snapchat:
            return "SocialSnapchat"
        case .linkedin:
            return "SocialLinkedIn"
        case .trustpilot:
            return "SocialTrustpilot"
        case .tripadvisor:
            return "SocialTripadvisor"
        case .twitter, .youtube:
            return nil
        }
    }

    private func loadProfile() {
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        organizationName = template?.displayName ?? business.name ?? "Mon établissement"
        email = business.email ?? ""
        phone = business.phone ?? ""
        address = business.address ?? ""
        logoURL = template?.logoURL ?? business.logoURL ?? ""
        logoIconURL = template?.logoIconURL ?? ""
    }

    private func loadProfileFromServer() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        await MainActor.run {
            autosaveTask?.cancel()
            autosaveTask = nil
        }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            await MainActor.run {
                suppressAutosave = true
                MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
                if let name = settings.organizationName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    organizationName = name
                    if let t = dataService.currentCardTemplate() { t.displayName = name }
                }
                if let addr = settings.locationAddress, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    address = addr
                }
                let b = dataService.createOrGetCurrentBusiness()
                if let addr = settings.locationAddress { b.address = addr }
                if let name = settings.organizationName, !name.isEmpty { b.name = name }
                if let u = settings.logoUrl, !u.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !CardLogoStorage.isLocalPendingLogoReference(logoURL) {
                        logoURL = u
                        dataService.currentCardTemplate()?.logoURL = u
                    }
                }
                if let u = settings.logoIconUrl, !u.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if !CardLogoStorage.isLocalPendingLogoIconReference(logoIconURL) {
                        logoIconURL = u
                        dataService.currentCardTemplate()?.logoIconURL = u
                    }
                }
                var eng = EngagementFormState(from: settings.engagementRewards)
                let serverPlaceEmpty = eng.googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                let cachedPlace = MerchantLinkedPlaceCache.read()
                var filledGoogleFromOnboardingCache = false
                if serverPlaceEmpty,
                   let pid = cachedPlace.placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                    eng.googlePlaceId = pid
                    filledGoogleFromOnboardingCache = true
                }
                engagement = eng
                let synced = engagement.googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
                if !synced.isEmpty {
                    MerchantLinkedPlaceCache.save(placeId: synced, description: cachedPlace.description)
                }
                try? viewContext.save()
                suppressAutosave = false
                if filledGoogleFromOnboardingCache {
                    scheduleAutosave()
                }
            }
        } catch {
            await MainActor.run { suppressAutosave = false }
        }
    }

    private func geocodeAddressForServer(_ query: String) async -> (lat: Double, lng: Double)? {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }
        return await withCheckedContinuation { cont in
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = q
            MKLocalSearch(request: request).start { response, _ in
                guard let item = response?.mapItems.first else {
                    cont.resume(returning: nil)
                    return
                }
                let c = item.mf_searchCoordinate
                cont.resume(returning: (c.latitude, c.longitude))
            }
        }
    }

    private func saveProfile() async {
        isSaving = true
        savedMessage = nil
        profileSaveError = nil
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        let nameFinal = organizationName.trimmingCharacters(in: .whitespaces)
        let finalName = nameFinal.isEmpty ? "Mon établissement" : nameFinal

        let localName = sections.showIdentity ? finalName : (business.name ?? finalName)
        let localEmail = sections.showContact ? (email.isEmpty ? nil : email) : business.email
        let localPhone = sections.showContact ? (phone.isEmpty ? nil : phone) : business.phone
        let localAddress = sections.showContact ? (address.isEmpty ? nil : address) : business.address
        let localLogo = sections.showIdentity ? (logoURL.isEmpty ? nil : logoURL) : business.logoURL
        dataService.updateBusiness(name: localName, email: localEmail, phone: localPhone, address: localAddress, logoURL: localLogo)
        if let t = template {
            if sections.showIdentity {
            t.displayName = finalName
            if !logoURL.isEmpty { t.logoURL = logoURL }
            if !logoIconURL.isEmpty { t.logoIconURL = logoIconURL }
            }
            t.updatedAt = Date()
            try? viewContext.save()
        }

        var serverSyncFailed = false
        var serverErrorMessage: String?

        if let slug = AuthStorage.currentBusinessSlug, let t = template {
            let bgHex = t.primaryColorHex ?? AppTheme.WalletCardAppearanceDefaults.backgroundHex
            let fgHex = t.accentColorHex ?? AppTheme.WalletCardAppearanceDefaults.bodyTextHex
            let requiredStamps = Int(t.requiredStamps)
            var logoBase64: String?
            var logoUrl: String?
            var logoIconBase64: String?
            if sections.showIdentity {
            let trimmedLogo = logoURL.trimmingCharacters(in: .whitespaces)
            if !trimmedLogo.isEmpty {
                if trimmedLogo.lowercased().hasPrefix("http://") || trimmedLogo.lowercased().hasPrefix("https://") {
                    let url = URL(string: trimmedLogo)
                    if let url, url.host() != APIConfig.baseURL.host() || !url.path.contains("/logo") {
                        logoUrl = trimmedLogo
                    }
                } else if trimmedLogo.contains("CardLogos") || trimmedLogo.hasPrefix("/") {
                    logoBase64 = CardLogoStorage.compressedWalletStripLogoBase64FromFile(path: trimmedLogo)
                }
            }
            let trimmedIcon = logoIconURL.trimmingCharacters(in: .whitespaces)
            if !trimmedIcon.isEmpty {
                if trimmedIcon.lowercased().hasPrefix("http://") || trimmedIcon.lowercased().hasPrefix("https://") {
                    let url = URL(string: trimmedIcon)
                    if let url, url.host() == APIConfig.baseURL.host(), url.path.contains("/logo-icon") {
                        // déjà servi par l’API
                    }
                } else if trimmedIcon.contains("CardLogos") || trimmedIcon.hasPrefix("/") {
                    logoIconBase64 = CardLogoStorage.compressedBase64LogoIconFromFile(path: trimmedIcon)
                }
            }
            }
            let addrTrim = sections.showContact ? address.trimmingCharacters(in: .whitespaces) : ""
            let coords = addrTrim.isEmpty ? nil : await geocodeAddressForServer(addrTrim)

            do {
                var patch = FullDashboardSettingsPatch()
                if sections.showIdentity {
                patch.organizationName = finalName
                patch.backgroundColor = Self.hexDigitsForDashboard(bgHex)
                patch.foregroundColor = Self.hexDigitsForDashboard(fgHex)
                patch.requiredStamps = requiredStamps
                }
                if sections.showContact {
                patch.locationAddress = addrTrim.isEmpty ? nil : addrTrim
                }
                if let c = coords {
                    patch.locationLat = c.lat
                    patch.locationLng = c.lng
                }
                if sections.showIdentity {
                patch.stampEmoji = t.stampEmoji.flatMap { $0.isEmpty ? nil : String($0.prefix(32)) }
                }
                if let logoBase64 { patch.logoBase64 = logoBase64 }
                if let logoIconBase64 { patch.logoIconBase64 = logoIconBase64 }
                if let logoUrl { patch.logoUrl = logoUrl }
                if sections.showEngagement {
                patch.engagementRewards = engagement.toPatch()
                }
                _ = try await APIClient.shared.request(APIEndpoint.patchDashboardSettings(slug: slug, patch: patch)) as EmptyResponse
                if logoBase64 != nil {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let apiLogoURL = "\(base)/api/businesses/\(slug)/logo"
                    t.logoURL = apiLogoURL
                    let b = dataService.createOrGetCurrentBusiness()
                    b.logoURL = apiLogoURL
                    try? viewContext.save()
                    await MainActor.run { logoURL = apiLogoURL }
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoUploadAtKey)
                }
                if logoIconBase64 != nil {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let apiIconURL = "\(base)/api/businesses/\(slug)/logo-icon"
                    t.logoIconURL = apiIconURL
                    try? viewContext.save()
                    await MainActor.run { logoIconURL = apiIconURL }
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoIconUploadAtKey)
                }
                await loadProfileFromServer()
                await syncService.syncAfterServerMutation()
            } catch {
                if APIError.isBenignRequestCancellation(error) {
                    // Autosave / sync : une requête PATCH précédente a été annulée — pas d’erreur à afficher.
                } else {
                    serverSyncFailed = true
                    serverErrorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                }
            }
        }

        await MainActor.run {
            isSaving = false
            if serverSyncFailed {
                profileSaveError = serverErrorMessage ?? "Synchronisation impossible."
                savedMessage = nil
            } else {
                savedMessage = "Enregistré"
                profileSaveError = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedMessage = nil }
            }
        }
    }

    private func loadLogoFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            imageCropPayload = ImageCropPayload(image: image, spec: .walletStripLogo)
            logoPhotoItem = nil
        }
    }

    private func loadLogoIconFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        await MainActor.run {
            imageCropPayload = ImageCropPayload(image: image, spec: .squareIcon)
            logoIconPhotoItem = nil
        }
    }

    private func applyEstablishmentCroppedImage(_ cropped: UIImage, spec: ImageCropSpec) {
        switch spec {
        case .walletStripLogo:
            let path = CardLogoStorage.saveImage(cropped)
            logoURL = path ?? ""
            if let p = path {
                dataService.updateBusiness(name: nil, email: nil, phone: nil, address: nil, logoURL: p)
                if let t = dataService.currentCardTemplate() {
                    t.logoURL = p
                    t.updatedAt = Date()
                    try? viewContext.save()
                }
            }
        case .squareIcon:
            let path = CardLogoStorage.saveLogoIconImage(cropped)
            logoIconURL = path ?? ""
            if let p = path, let t = dataService.currentCardTemplate() {
                t.logoIconURL = p
                t.updatedAt = Date()
                try? viewContext.save()
            }
        case .stampIcon:
            break
        case .walletCardBackground:
            break
        case .flyerPromoLogo, .flyerCustomBackground:
            break
        }
    }

    private static func hexDigitsForDashboard(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return nil }
        return t.hasPrefix("#") ? String(t.dropFirst()) : t
    }
}



