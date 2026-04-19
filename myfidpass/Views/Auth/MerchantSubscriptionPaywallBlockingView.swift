//
//  MerchantSubscriptionPaywallBlockingView.swift
//  myfidpass
//
//  Écran plein écran après la fin des 24 h d’essai : pas d’accès à l’app tant que l’abonnement
//  n’est pas actif (équivalent au bandeau « mode découverte », mais bloquant).
//

import SwiftUI
import CoreData

private enum MerchantPaywallAuxRoute: Hashable {
    case statistics
    case statisticsDetail(CommerceStatisticDetailTopic, String)
}

/// Paywall plein écran (fond noir, CTA type « Continuer ») — aligné sur la maquette fournie.
struct MerchantSubscriptionPaywallBlockingView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState

    var onContinue: () -> Void

    @State private var settingsForTopBar: BusinessSettingsResponse?
    @State private var paywallFlyerShareURL: String = ""
    @State private var showSettingsSheet = false
    @State private var showCommercePublicQRSheet = false
    @State private var paywallAuxNavPath = NavigationPath()

    /// Dernier jour du mois civil courant (offre affichée « à 1 € » jusqu’à cette date).
    private var oneEuroPromoEndDateString: String {
        let cal = Calendar.current
        let now = Date()
        var c = cal.dateComponents([.year, .month], from: now)
        c.day = 1
        guard let firstDay = cal.date(from: c),
              let lastDay = cal.date(byAdding: DateComponents(month: 1, day: -1), to: firstDay)
        else {
            return ""
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "d MMMM yyyy"
        return df.string(from: lastDay)
    }

    private var paywallBodyLine1: String {
        let date = oneEuroPromoEndDateString
        if date.isEmpty {
            return "Payez 1 € / mois pour retrouver l’accès à votre tableau de bord."
        }
        return "Payez 1 € / mois jusqu’au \(date)"
    }

    private var activeBusiness: BusinessDTO? {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !slug.isEmpty, let b = authService.businesses.first(where: { $0.slug == slug }) {
            return b
        }
        return authService.businesses.first
    }

    private var commerceLine: String {
        let raw = activeBusiness?.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !raw.isEmpty { return raw }
        let name = activeBusiness?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        return "Mon commerce"
    }

    private var topBarOrganizationTitle: String {
        if let n = settingsForTopBar?.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        return commerceLine
    }

    private var commercePublicPageURLString: String {
        let s = paywallFlyerShareURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !s.isEmpty { return s }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return ""
        }
        return LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""
    }

    /// Stabilise le `.task` : évite relances multiples et annule proprement si la vue disparaît.
    private var paywallLoadSlug: String? {
        let s = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return s.isEmpty ? nil : s
    }

    var body: some View {
        NavigationStack(path: $paywallAuxNavPath) {
            paywallRootContent
                .navigationDestination(for: MerchantPaywallAuxRoute.self) { route in
                    switch route {
                    case .statistics:
                        MerchantStatisticsDashboardScreen(
                            onRequestStatisticDetail: { topic, periodKey in
                                paywallAuxNavPath.append(MerchantPaywallAuxRoute.statisticsDetail(topic, periodKey))
                            }
                        )
                        .environment(\.managedObjectContext, viewContext)
                    case let .statisticsDetail(topic, periodKey):
                        MerchantStatisticRevolutDetailScreen(topic: topic, initialPeriodRaw: periodKey)
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
        }
    }

    private var paywallRootContent: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Reprenez vos activités pour 1 €")
                        .font(.system(size: 36, weight: .medium, design: .default))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(paywallBodyLine1)
                        Text("Sans engagement, annulez à tout moment")
                    }
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 24)

                Button(action: onContinue) {
                    Text("Continuer")
                        .font(.system(size: 17, weight: .bold, design: .default))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            CommerceTopBarView(
                organizationDisplayName: topBarOrganizationTitle,
                settings: settingsForTopBar,
                onQR: { showCommercePublicQRSheet = true },
                onSettings: { showSettingsSheet = true }
            )
        }
        .preferredColorScheme(.dark)
        .task(id: paywallLoadSlug) {
            guard let slug = paywallLoadSlug else { return }
            await loadPaywallCommerceContext(slug: slug)
        }
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                SettingsView(onRequestOpenStatistics: {
                    showSettingsSheet = false
                    DispatchQueue.main.async {
                        paywallAuxNavPath.append(MerchantPaywallAuxRoute.statistics)
                    }
                })
                .environmentObject(authService)
                .environmentObject(syncService)
                .environmentObject(revenueCatSubscriptionState)
                .environment(\.managedObjectContext, viewContext)
            }
        }
        .sheet(isPresented: $showCommercePublicQRSheet) {
            CommercePublicQRSheet(urlString: commercePublicPageURLString)
        }
    }

    /// Requêtes **séquentielles** (pas `async let` en parallèle) : le double GET simultané pouvait provoquer des crashes allocateur (`freed pointer was not the last allocation`) selon l’état réseau / abo.
    private func loadPaywallCommerceContext(slug: String) async {
        let fallbackPublicURL = LegalURLs.fidelityCardPage(slug: slug)?.absoluteString ?? ""

        do {
            let settings: BusinessSettingsResponse = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug))
            try Task.checkCancellation()
            await MainActor.run { settingsForTopBar = settings }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                settingsForTopBar = nil
                paywallFlyerShareURL = fallbackPublicURL
            }
            return
        }

        do {
            let flyer: DashboardFlyerGetResponse = try await APIClient.shared.request(APIEndpoint.dashboardFlyerGet(slug: slug))
            try Task.checkCancellation()
            let trimmedShare = (flyer.shareUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            await MainActor.run {
                paywallFlyerShareURL = trimmedShare.isEmpty ? fallbackPublicURL : trimmedShare
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run { paywallFlyerShareURL = fallbackPublicURL }
        }
    }
}

#Preview {
    MerchantSubscriptionPaywallBlockingView(onContinue: {})
        .environmentObject(AuthService())
        .environmentObject(SyncService(container: PersistenceController.preview.container))
        .environmentObject(RevenueCatSubscriptionState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
