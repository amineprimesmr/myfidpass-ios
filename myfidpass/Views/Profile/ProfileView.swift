//
//  ProfileView.swift
//  myfidpass
//
//  Onglet Commerce : identité commerçant, formulaire établissement, accès Réglages.
//

import SwiftUI
import CoreData
import UIKit

private struct CommerceSetupMetrics {
    let step1Done: Bool
    let step2Done: Bool
}

/// Navigation vers le hub Flyer QR depuis l’onglet Commerce (plus d’onglet Flyer dédié).
private enum CommerceFlyerDestination: Hashable {
    case flyer
    case flyerAndMyCard
    /// Assistant IA : formulaire vierge pour une nouvelle création (confirmé dans l’alerte Commerce).
    case flyerRecreate
}

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @EnvironmentObject private var tabRouter: MainTabRouter
    @StateObject private var dataService: DataService
    @State private var organizationName: String = ""
    @State private var logoURL: String = ""
    @State private var settingsSnapshot: BusinessSettingsResponse?
    @State private var flyerLooksCustomized = false
    /// Étape 2 : valeur de secours tant que `settingsSnapshot` n’est pas arrivé (hydratée depuis le cache disque).
    @State private var cachedEngagementStepDone = false
    /// Alimentés par `GET …/dashboard/flyer` pour le bloc « Flyer enregistré » sur la checklist Commerce.
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
                                commerceSetupChecklistCard
                                    .padding(.top, 10)
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
            }
            .sheet(isPresented: $showSettingsSheet) {
                NavigationStack {
                    SettingsView()
                        .environmentObject(authService)
                        .environmentObject(syncService)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .sheet(isPresented: $showCommercePublicQRSheet) {
                CommercePublicQRSheet(urlString: commercePublicPageURLString)
            }
            .fullScreenCover(isPresented: $showCommerceSavedFlyerLarge) {
                CommerceSavedFlyerLargePreviewView(
                    shareURL: commerceFlyerShareURL,
                    customBgDataURL: commerceFlyerCustomBgDataURL,
                    bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                    businessSlug: AuthStorage.currentBusinessSlug,
                    onDismiss: { showCommerceSavedFlyerLarge = false }
                )
            }
            .navigationDestination(for: CommerceFlyerDestination.self) { dest in
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
        }
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

    private var commerceSetupMetrics: CommerceSetupMetrics {
        let step2: Bool = {
            if let settings = settingsSnapshot {
                return engagementStepDone(from: settings)
            }
            return cachedEngagementStepDone
        }()

        return CommerceSetupMetrics(
            step1Done: flyerLooksCustomized,
            step2Done: step2
        )
    }

    private func engagementStepDone(from settings: BusinessSettingsResponse) -> Bool {
        guard let e = settings.engagementRewards else { return false }
        let googleOk = (e.googleReview?.enabled == true)
            && !(e.googleReview?.placeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return }
        guard let cached = CommerceFlyerStateCache.load(slug: slug) else { return }
        flyerLooksCustomized = cached.flyerRegistered
        cachedEngagementStepDone = cached.engagementStepDone
        commerceFlyerShareURL = cached.shareURL
        if let b = cached.bootstrapPreviewB64, !b.isEmpty {
            commerceFlyerBootstrapPreviewB64 = b
        }
        commerceFlyerCustomBgDataURL = cached.customBgDataURL
    }

    private var commerceSetupChecklistCard: some View {
        let m = commerceSetupMetrics
        let completed = [m.step1Done, m.step2Done].filter { $0 }.count

        return VStack(alignment: .leading, spacing: 14) {
            Text("Préparez-vous à lancer")
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("\(completed) sur 2 étapes terminées")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.primary.opacity(0.1), in: Capsule())
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: completed)

            VStack(spacing: 0) {
                Group {
                    if m.step1Done {
                        CommerceFlyerSavedBlockView(
                            customBgDataURL: commerceFlyerCustomBgDataURL,
                            bootstrapPreviewBase64: commerceFlyerBootstrapPreviewB64,
                            businessSlug: AuthStorage.currentBusinessSlug,
                            onOpenFlyerHub: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                showCommerceSavedFlyerLarge = true
                            }
                        )
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                    } else {
                        commerceSetupRow(
                            step: 1,
                            title: "Créer le flyer QR",
                            done: false,
                            systemImage: "qrcode"
                        ) {
                            commerceNavPath.append(CommerceFlyerDestination.flyer)
                        }
                    }
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: m.step1Done)

                commerceSetupDivider

                VStack(alignment: .leading, spacing: 12) {
                    commerceSetupStepHeader(
                        step: 2,
                        title: "",
                        done: m.step2Done,
                        systemImage: "bubble.left.and.bubble.right.fill"
                    )
                    MerchantEstablishmentForm(context: viewContext, sections: .engagementOnlyCommerceInline)
                        .environmentObject(syncService)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.Colors.background.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(16)
    }

    private var commerceSetupDivider: some View {
        Divider().padding(.leading, 52)
    }

    /// En-tête d’étape (non cliquable) — même style que `commerceSetupRow` sans chevron.
    private func commerceSetupStepHeader(
        step: Int,
        title: String,
        done: Bool,
        systemImage: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(done ? AppTheme.Colors.success.opacity(0.18) : AppTheme.Colors.textSecondary.opacity(0.12))
                    .frame(width: 36, height: 36)
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.success)
                } else {
                    Text("\(step)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary.opacity(0.9))
                if !title.isEmpty {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func commerceSetupRow(
        step: Int,
        title: String,
        done: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(done ? AppTheme.Colors.success.opacity(0.18) : AppTheme.Colors.textSecondary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.success)
                    } else {
                        Text("\(step)")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary.opacity(0.9))
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.7))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(PressableScaleButtonStyle())
    }

    private var storeInitials: String {
        let source = organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty { return "Mb" }
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "Mb" : letters
    }

    private var userInitials: String {
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
                if let st = flyer.flyerPrefs?.state {
                    flyerLooksCustomized = st != .default
                } else {
                    flyerLooksCustomized = false
                }
                let trimmedShare = (flyer.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedShare.isEmpty {
                    commerceFlyerShareURL = LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
                } else {
                    commerceFlyerShareURL = trimmedShare
                }
                commerceFlyerCustomBgDataURL = flyer.flyerPrefs?.customBgDataUrl
                commerceFlyerBootstrapPreviewB64 = FlyerBootstrapPreviewPayloadBuilder.base64(from: flyer, businessSlug: slug)
                let engagement = engagementStepDone(from: settings)
                cachedEngagementStepDone = engagement
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
            }
        } catch {}
    }
}

private struct PressableScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.8), value: configuration.isPressed)
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

private struct CommercePublicQRSheet: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss

    private var qrLogicalSide: CGFloat { min(UIScreen.main.bounds.width - 48, 340) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Clients : ils scannent et arrivent sur votre page fidélité.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    if urlString.isEmpty {
                        ContentUnavailableView(
                            "Lien indisponible",
                            systemImage: "link.badge.plus",
                            description: Text("Connectez un commerce ou réessayez dans un instant.")
                        )
                    } else if let img = QRCodeGenerator.generateQR(from: urlString, size: qrLogicalSide * UIScreen.main.scale) {
                        Image(uiImage: img)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: qrLogicalSide, height: qrLogicalSide)
                            .padding(20)
                            .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)

                        Text(urlString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            UIPasteboard.general.string = urlString
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Label("Copier le lien", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ContentUnavailableView(
                            "QR indisponible",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Réessayez dans un instant.")
                        )
                    }
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("QR code fidélité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    ProfileView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(MainTabRouter())
}
