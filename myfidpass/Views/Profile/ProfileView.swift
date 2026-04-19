//
//  ProfileView.swift
//  myfidpass
//
//  Onglet Commerce : identité commerçant, formulaire établissement, accès Réglages.
//

import SwiftUI
import CoreData
import UIKit

/// Navigation depuis l’onglet Commerce (hub Flyer, statistiques — plus d’onglet Flyer dédié).
private enum CommerceFlyerDestination: Hashable {
    case flyer
    case flyerAndMyCard
    /// Assistant IA : formulaire vierge pour une nouvelle création (confirmé dans l’alerte Commerce).
    case flyerRecreate
    case statistics
    /// Drill-down indicateur (style Revolut) ; `periodKey` = `CommerceStatsPeriodTab.rawValue`.
    case statisticsDetail(CommerceStatisticDetailTopic, String)
}

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState
    @EnvironmentObject private var tabRouter: MainTabRouter
    @StateObject private var dataService: DataService
    @State private var organizationName: String = ""
    @State private var logoURL: String = ""
    @State private var settingsSnapshot: BusinessSettingsResponse?
    @State private var flyerLooksCustomized = false
    /// Alimentés par `GET …/dashboard/flyer` pour le bloc flyer (aperçu Commerce).
    @State private var commerceFlyerShareURL: String = ""
    @State private var commerceFlyerCustomBgDataURL: String?
    /// JSON embed base64 (même source que l’éditeur) pour miniature **composite** (QR, roue, textes), pas seulement le fond IA.
    @State private var commerceFlyerBootstrapPreviewB64: String?
    @State private var showSettingsSheet = false
    @State private var showCommercePublicQRSheet = false
    @State private var showCommerceSavedFlyerLarge = false
    @State private var commerceNavPath = NavigationPath()

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var profileCanvas: Color {
        DashboardRevolutPalette(colorScheme: colorScheme).canvas
    }

    /// Même URL que la page client (SaaS « Lien et QR ») : `GET …/dashboard/flyer` puis repli `myfidpass.fr/fidelity/{slug}`.
    private var commercePublicPageURLString: String {
        let s = commerceFlyerShareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return ""
        }
        return LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
    }

    var body: some View {
        NavigationStack(path: $commerceNavPath) {
            ZStack(alignment: .top) {
                profileCanvas.ignoresSafeArea()
                VStack(spacing: 0) {
                    Color.black
                        .frame(height: 140)
                    Spacer()
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    commerceTopBar
                    ZStack {
                        AppTheme.Colors.cardBackground
                            .clipShape(TopRoundedShape(radius: 22))
                            .ignoresSafeArea(edges: .bottom)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                if shouldShowCommerceTrialSubscribePill, let trialEnd = authService.merchantTrialEndsAt {
                                    CommerceTrialPromoBannerView(trialEndsAt: trialEnd) {
                                        NotificationCenter.default.post(
                                            name: .myfidpassOpenMerchantTrialStripePaymentLink,
                                            object: nil
                                        )
                                    }
                                    .padding(.top, 10)
                                }
                                commerceSetupChecklistCard
                                    .padding(.top, shouldShowCommerceTrialSubscribePill ? 4 : 10)
                                Color.clear.frame(height: 20)
                            }
                            .padding(.horizontal, 14)
                            .padding(.bottom, 100)
                        }
                        .background(Color.clear)
                        .scrollIndicators(.hidden)
                        .refreshable {
                            await syncService.syncAfterServerMutation()
                            loadProfile()
                            await loadProfileFromServer()
                        }
                    }
                }

                if syncService.isSyncing && organizationName.isEmpty {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(AppTheme.Colors.primary)
                        Spacer()
                    }
                    .padding(.top, 120)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                syncMerchantFlyerHubPresentation()
                loadProfile()
                hydrateCommerceFromDiskCache()
                Task { await loadProfileFromServer() }
                // Préchauffage embed flyer après le cold start / la sync (WKWebView hors pic initial).
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    FlyerEmbedWarmup.startIfNeeded()
                }
            }
            .onChange(of: flyerLooksCustomized) { _, _ in
                pushFlyerOnboardingSync()
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(authService)
                        .environmentObject(syncService)
                        .environmentObject(revenueCatSubscriptionState)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showCommercePublicQRSheet) {
                CommercePublicQRSheet(urlString: commercePublicPageURLString)
            }
            .fullScreenCover(isPresented: $showCommerceSavedFlyerLarge) {
                CommerceSavedFlyerLargePreviewView(
                    shareURL: commercePublicPageURLString,
                    customBgDataURL: commerceFlyerCustomBgDataURL,
                    bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                    businessSlug: AuthStorage.currentBusinessSlug,
                    onDismiss: { showCommerceSavedFlyerLarge = false },
                    onConfirmRecreate: {
                        showCommerceSavedFlyerLarge = false
                        commerceNavPath.append(CommerceFlyerDestination.flyerRecreate)
                    }
                )
            }
            .navigationDestination(for: CommerceFlyerDestination.self) { dest in
                switch dest {
                case .statistics:
                    MerchantStatisticsDashboardScreen(
                        onRequestStatisticDetail: { topic, periodKey in
                            commerceNavPath.append(CommerceFlyerDestination.statisticsDetail(topic, periodKey))
                        }
                    )
                    .environment(\.managedObjectContext, viewContext)
                case let .statisticsDetail(topic, periodKey):
                    MerchantStatisticRevolutDetailScreen(topic: topic, initialPeriodRaw: periodKey)
                        .environment(\.managedObjectContext, viewContext)
                case .flyer, .flyerAndMyCard, .flyerRecreate:
                    MerchantProgramHubView(
                        context: viewContext,
                        seedOpenMyCard: dest == .flyerAndMyCard,
                        seedRecreateFlyer: dest == .flyerRecreate,
                        forceRefreshFlyerFromServer: dest == .flyer || dest == .flyerRecreate,
                        onFlyerSaveSuccessReturnToCommerce: {
                            if !commerceNavPath.isEmpty {
                                commerceNavPath.removeLast()
                            }
                        }
                    )
                    .environmentObject(syncService)
                    .environmentObject(authService)
                }
            }
            .onChange(of: commerceNavPath) { _, newPath in
                syncMerchantFlyerHubPresentation()
                // Refresh flyer status when user returns from MerchantProgramHubView
                if newPath.isEmpty {
                    Task { await loadProfileFromServer() }
                }
            }
            .onChange(of: tabRouter.selectedTab) { _, newTab in
                syncMerchantFlyerHubPresentation()
                if newTab == 2 {
                    Task { await loadProfileFromServer() }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassRemoteSyncDidMerge)) { _ in
                guard tabRouter.selectedTab == 2 else { return }
                Task { await loadProfileFromServer() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .myfidpassOpenMerchantStatistics)) { _ in
                if tabRouter.selectedTab != 2 {
                    tabRouter.selectedTab = 2
                }
                showSettingsSheet = false
                DispatchQueue.main.async {
                    commerceNavPath.append(CommerceFlyerDestination.statistics)
                }
            }
            .animation(MerchantMotion.navigationPath, value: commerceNavPath.count)
        }
    }

    /// Pastille 1 € dans le contenu Commerce (scroll), pas le bandeau global — masquée dans le hub Flyer.
    private var shouldShowCommerceTrialSubscribePill: Bool {
        guard authService.isMerchantTrialPeriodActive, authService.merchantTrialEndsAt != nil else { return false }
        return commerceNavPath.isEmpty
    }

    /// Masque la pastille d’essai dans `ContentView` tant que le hub Flyer est affiché (Commerce + navigation).
    private func syncMerchantFlyerHubPresentation() {
        tabRouter.isMerchantFlyerHubPresented = tabRouter.selectedTab == 2 && !commerceNavPath.isEmpty
    }

    /// Même source que la page Notifs : `GET …/notification-icon` (icône dédiée), pas le logo Ma Carte.
    private var commerceNotificationIconURL: String? {
        let t = settingsSnapshot?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return nil }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return nil }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return "\(base)/api/businesses/\(enc)/notification-icon"
    }

    @ViewBuilder
    private var commerceTopBarLeadingAvatar: some View {
        if let url = commerceNotificationIconURL {
            BusinessLogoView(
                logoURL: url,
                logoAssetContext: .campaignNotificationIcon,
                size: 34,
                cornerRadius: 10
            )
            .id(settingsSnapshot?.notificationIconUpdatedAt ?? "notification-icon")
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.green.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(storeInitials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.9))
                }
        }
    }

    private var commerceTopBar: some View {
        HStack(spacing: 12) {
            commerceTopBarLeadingAvatar
            Text(organizationName.isEmpty ? "Ma boutique" : organizationName)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showCommercePublicQRSheet = true
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
            .accessibilityLabel("Afficher le QR code de la page fidélité")
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color.black)
    }

    private func engagementStepDone(from settings: BusinessSettingsResponse) -> Bool {
        guard let e = settings.engagementRewards else { return false }
        let googleOk = (e.googleReview?.enabled == true)
            && !(e.googleReview?.placeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if EngagementTemporaryVisibility.commerceEngagementGoogleOnly {
            return googleOk
        }
        let others: [EngagementChannelDTO?] = {
            if EngagementTemporaryVisibility.hideSecondaryReviewNetworks {
                return [e.instagramFollow, e.tiktokFollow, e.facebookFollow, e.youtubeFollow]
            }
            return [
                e.instagramFollow, e.tiktokFollow, e.facebookFollow,
                e.twitterFollow, e.snapchatFollow, e.linkedinFollow, e.youtubeFollow,
                e.trustpilotReview, e.tripadvisorReview,
            ]
        }()
        let otherOk = others.contains {
            ($0?.enabled == true) && !(($0?.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        return googleOk || otherOk
    }

    /// Réhydrate flyer + bootstrap + lien depuis le dernier GET réussi (affichage instantané sans flash).
    private func hydrateCommerceFromDiskCache() {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            pushFlyerOnboardingSync()
            return
        }
        guard let cached = CommerceFlyerStateCache.load(slug: slug) else {
            pushFlyerOnboardingSync()
            return
        }
        let hasBootstrap = !(cached.bootstrapPreviewB64 ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCustomBgFile = !(cached.customBgDataURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        flyerLooksCustomized = cached.flyerRegistered || hasBootstrap || hasCustomBgFile
        commerceFlyerShareURL = cached.shareURL
        if let b = cached.bootstrapPreviewB64, !b.isEmpty {
            commerceFlyerBootstrapPreviewB64 = b
        }
        commerceFlyerCustomBgDataURL = cached.customBgDataURL
        pushFlyerOnboardingSync()
    }

    /// Aligne le verrou d’onglets (MainTabRouter) avec le cache / le serveur.
    private func pushFlyerOnboardingSync() {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if slug.isEmpty {
            tabRouter.syncFlyerOnboardingRequirement(flyerRegistered: false, hasBusinessSlug: false)
        } else {
            tabRouter.syncFlyerOnboardingRequirement(flyerRegistered: flyerLooksCustomized, hasBusinessSlug: true)
        }
    }

    private var commerceSetupChecklistCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 16) {
                Group {
                    if flyerLooksCustomized {
                        CommerceFlyerSavedBlockView(
                            customBgDataURL: commerceFlyerCustomBgDataURL,
                            bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                            businessSlug: AuthStorage.currentBusinessSlug,
                            onOpenFlyerHub: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showCommerceSavedFlyerLarge = true
                            }
                        )
                    } else {
                        commerceFlyerCreateRow
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: flyerLooksCustomized)
            }
            .commerceTabSectionCard(emphasizePrimaryAccent: false)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                commerceNavPath.append(CommerceFlyerDestination.statistics)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.Colors.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Statistiques")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                        Text("Panier, fidélité, campagnes")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                }
                .padding(14)
            }
            .buttonStyle(.plain)
            .commerceTabSectionCard(emphasizePrimaryAccent: false)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image("SocialGoogle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    Text("Avis Google")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                MerchantEstablishmentForm(
                    context: viewContext,
                    sections: .commerceGoogleStandalone
                )
                .environmentObject(syncService)
            }
            .commerceTabSectionCard(emphasizePrimaryAccent: true)
        }
        .padding(16)
    }

    /// Ratio canvas flyer (identique à `CommerceFlyerSavedBlockView`) — miniature alignée sur le flyer réel.
    private static let commerceFlyerThumbAspect: CGFloat = 2400.0 / 3600.0

    private var commerceFlyerCreateRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Créez votre Flyer de jeu")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text("Partagez-le en magasin ou en ligne : vos clients scannent le QR, ajoutent votre carte et jouent à la roue.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer(minLength: 0)
                Image("flyervide")
                    .resizable()
                    .scaledToFit()
                    .aspectRatio(Self.commerceFlyerThumbAspect, contentMode: .fit)
                    .frame(width: 288)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
            }
            .padding(.top, 18)
            .padding(.bottom, -12)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                commerceNavPath.append(CommerceFlyerDestination.flyer)
            } label: {
                Text("Créer mon flyer de jeu")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(MerchantPressableButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .flyerPrimaryCTAShake(shakeToken: tabRouter.flyerPrimaryCTAShakeToken)
        .task(id: tabRouter.selectedTab) {
            guard tabRouter.selectedTab == 2 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled, tabRouter.selectedTab == 2 else { return }
                tabRouter.triggerFlyerPrimaryCTAAutoShake()
            }
        }
    }

    private var storeInitials: String {
        let source = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty { return "Mb" }
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "Mb" : letters
    }

    private var userInitials: String {
        if let phone = authService.currentUserPhone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            let digits = phone.filter(\.isNumber)
            let tail = String(digits.suffix(2))
            return tail.isEmpty ? "ME" : tail
        }
        let mail = authService.currentUserEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !mail.isEmpty else { return "ME" }
        let local = mail.split(separator: "@").first.map(String.init) ?? mail
        let parts = local.split(whereSeparator: { $0 == "." || $0 == "_" || $0 == "-" }).prefix(2)
        let letters = parts.compactMap { $0.first }.map { String($0).uppercased() }.joined()
        return letters.isEmpty ? "ME" : letters
    }

    private func loadProfile() {
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        organizationName = template?.displayName ?? business.name ?? "Mon établissement"
        let cardLogo = template?.logoURL ?? business.logoURL ?? ""
        let icon = template?.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        logoURL = icon.isEmpty ? cardLogo : icon
    }

    private func loadProfileFromServer() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            // Parallélise les deux GET (settings + flyer) — économise 1-3 s de latence séquentielle.
            async let settingsTask: BusinessSettingsResponse = APIClient.shared.request(APIEndpoint.businessSettings(slug: slug))
            async let flyerTask: DashboardFlyerGetResponse = APIClient.shared.request(APIEndpoint.dashboardFlyerGet(slug: slug))
            let (settings, flyer) = try await (settingsTask, flyerTask)
            await MainActor.run {
                settingsSnapshot = settings
                flyerLooksCustomized = flyer.commerceIndicatesFlyerRegistered
                let trimmedShare = (flyer.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedShare.isEmpty {
                    commerceFlyerShareURL = LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
                } else {
                    commerceFlyerShareURL = trimmedShare
                }
                commerceFlyerCustomBgDataURL = flyer.flyerPrefs?.customBgDataUrl
                commerceFlyerBootstrapPreviewB64 = FlyerBootstrapPreviewPayloadBuilder.base64(from: flyer, businessSlug: slug)
                let engagement = engagementStepDone(from: settings)
                CommerceFlyerStateCache.save(
                    slug: slug,
                    flyerRegistered: flyerLooksCustomized,
                    shareURL: commerceFlyerShareURL,
                    bootstrapB64: commerceFlyerBootstrapPreviewB64,
                    engagementStepDone: engagement,
                    customBgDataURL: commerceFlyerCustomBgDataURL
                )
                MerchantLogoAssetCache.applyMerchantLogoTimestamps(from: settings)
                CampaignNotificationImageCache.applyPreviewTimestamps(from: settings)
                if let name = settings.organizationName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    organizationName = name
                    if let t = dataService.currentCardTemplate() {
                        t.displayName = name
                    }
                }
                let b = dataService.createOrGetCurrentBusiness()
                if let name = settings.organizationName, !name.isEmpty { b.name = name }
                let tpl = dataService.currentCardTemplate()
                if let u = settings.logoUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                    let cur = tpl?.logoURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !CardLogoStorage.isLocalPendingLogoReference(cur) {
                        tpl?.logoURL = u
                    }
                }
                if let u = settings.logoIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty {
                    let cur = tpl?.logoIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if !CardLogoStorage.isLocalPendingLogoIconReference(cur) {
                        tpl?.logoIconURL = u
                    }
                }
                try? viewContext.save()
                loadProfile()
                pushFlyerOnboardingSync()
            }
        } catch {}
    }
}

private extension View {
    /// Carte section onglet Commerce — variante Google avec léger accent couleur primaire.
    func commerceTabSectionCard(emphasizePrimaryAccent: Bool) -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.background.opacity(emphasizePrimaryAccent ? 0.62 : 0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        emphasizePrimaryAccent
                            ? AppTheme.Colors.primary.opacity(0.22)
                            : AppTheme.Colors.textSecondary.opacity(0.14),
                        lineWidth: 1
                    )
            )
    }
}

private struct TopRoundedShape: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, min(rect.width, rect.height) / 2)
        p.move(to: CGPoint(x: 0, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.width, y: r), control: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.closeSubpath()
        return p
    }
}

#Preview {
    ProfileView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(RevenueCatSubscriptionState())
        .environmentObject(MainTabRouter())
}
