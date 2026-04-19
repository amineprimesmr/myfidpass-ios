//
//  GoogleBusinessHubView.swift
//  myfidpass
//
//  Tableau de bord Google Business Profile (avis, posts, Q&A, insights, horaires, photos).
//  Entry point depuis l'onglet Commerce, après connexion du compte Google Business.
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessHubViewModel: ObservableObject {
    @Published var status: GoogleBusinessStatus?
    @Published var isLoading: Bool = false
    @Published var isSyncing: Bool = false
    @Published var isRegisteringPubSub: Bool = false
    @Published var errorMessage: String?
    @Published var notConnected: Bool = false

    private let slug: String

    init(slug: String) {
        self.slug = slug
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await GoogleBusinessAPI.shared.status(slug: slug)
            self.status = s
            self.notConnected = !s.connected
            self.errorMessage = nil
        } catch APIError.server(let code, _) where code == 409 {
            self.notConnected = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func syncNow() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        do {
            _ = try await GoogleBusinessAPI.shared.syncReviews(slug: slug)
            await load()
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func markAllSeen() async {
        do {
            try await GoogleBusinessAPI.shared.markAllReviewsSeen(slug: slug)
            await load()
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Enregistre le topic Google Pub/Sub pour recevoir les événements avis en quasi temps réel.
    func registerPubSubNow() async {
        guard !isRegisteringPubSub else { return }
        isRegisteringPubSub = true
        defer { isRegisteringPubSub = false }
        do {
            try await GoogleBusinessAPI.shared.registerPubSubNotifications(slug: slug)
            await load()
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct GoogleBusinessHubView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessHubViewModel
    @State private var deepLinkReviewId: String?
    @State private var pushReviewId: String?

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessHubViewModel(slug: slug))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if vm.notConnected {
                    notConnectedState
                } else {
                    headerCard
                    if let err = vm.errorMessage, vm.status == nil {
                        errorBanner(err)
                    } else {
                        sectionsGrid
                        quickActions
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Google Business")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load()
        }
        .refreshable {
            await vm.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .googleBusinessNewReviewReceived)) { note in
            if let id = note.userInfo?["review_id"] as? String {
                pushReviewId = id
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { pushReviewId != nil },
            set: { if !$0 { pushReviewId = nil } }
        )) {
            GoogleBusinessReviewsListView(slug: slug, focusedReviewId: pushReviewId)
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image("SocialGoogle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.status?.locationTitle ?? "Fiche Google Business")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    if let avg = vm.status?.counts.averageRating {
                        HStack(spacing: 4) {
                            stars(rating: avg)
                            Text(String(format: "%.1f  ·  %d avis", avg, vm.status?.counts.total ?? 0))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                    } else if let total = vm.status?.counts.total, total > 0 {
                        Text("\(total) avis")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                Spacer()
            }

            if let c = vm.status?.counts {
                HStack(spacing: 10) {
                    kpi(title: "Non répondus", value: String(c.unreplied), tint: .orange, systemImage: "message.badge.filled.fill")
                    kpi(title: "Négatifs", value: String(c.negativesUnreplied), tint: .red, systemImage: "exclamationmark.triangle.fill")
                    kpi(title: "Nouveaux", value: String(c.unseen), tint: AppTheme.Colors.primary, systemImage: "sparkles")
                }
            }

            if vm.status?.connected == true && vm.status?.locationPending != true {
                pubsubInstantRow
            }

            HStack(spacing: 8) {
                Button {
                    Task { await vm.syncNow() }
                } label: {
                    HStack(spacing: 6) {
                        if vm.isSyncing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(vm.isSyncing ? "Synchronisation…" : "Actualiser")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.14)))
                    .foregroundStyle(AppTheme.Colors.primary)
                }
                .disabled(vm.isSyncing)
                if (vm.status?.counts.unseen ?? 0) > 0 {
                    Button {
                        Task { await vm.markAllSeen() }
                    } label: {
                        Text("Tout marquer comme vu")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AppTheme.Colors.textPrimary.opacity(0.08)))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 3)
        )
    }

    @ViewBuilder
    private func stars(rating: Double) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                let full = Double(i) + 1 <= rating
                let half = !full && Double(i) + 0.5 <= rating
                Image(systemName: full ? "star.fill" : (half ? "star.leadinghalf.filled" : "star"))
                    .font(.caption2)
                    .foregroundStyle(Color(hex: "F5B301"))
            }
        }
    }

    private func kpi(title: String, value: String, tint: Color, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint.opacity(0.08))
        )
    }

    private var pubsubInstantRow: some View {
        Group {
            if vm.status?.pubsubLiveNotifications == true {
                Label("Alertes nouveaux avis quasi instantanées", systemImage: "bolt.horizontal.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(hex: "34C759"))
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    if let err = vm.status?.pubsubLastError, !err.isEmpty {
                        Text("Notifications instantanées : \(err)")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("Active la liaison Google Pub/Sub pour des alertes avis plus rapides que la synchronisation périodique.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    Button {
                        Task { await vm.registerPubSubNow() }
                    } label: {
                        HStack(spacing: 6) {
                            if vm.isRegisteringPubSub {
                                ProgressView().controlSize(.small)
                            }
                            Text(vm.isRegisteringPubSub ? "Connexion…" : "Activer les alertes rapides")
                                .font(.caption.weight(.semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.Colors.textPrimary.opacity(0.08)))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    }
                    .disabled(vm.isRegisteringPubSub)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.Colors.primary.opacity(0.06))
                )
            }
        }
    }

    // MARK: - Sections grid

    private var sectionsGrid: some View {
        VStack(spacing: 12) {
            NavigationLink {
                GoogleBusinessReviewsListView(slug: slug, focusedReviewId: deepLinkReviewId)
            } label: {
                sectionRow(
                    iconName: "star.bubble.fill",
                    tint: Color(hex: "F5B301"),
                    title: "Avis clients",
                    subtitle: subtitleForReviews(),
                    badge: (vm.status?.counts.unreplied ?? 0) > 0 ? String(vm.status!.counts.unreplied) : nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoogleBusinessPostsView(slug: slug)
            } label: {
                sectionRow(
                    iconName: "megaphone.fill",
                    tint: Color(hex: "0A84FF"),
                    title: "Publications Google",
                    subtitle: "Actus, événements, offres promotionnelles",
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoogleBusinessQnAView(slug: slug)
            } label: {
                sectionRow(
                    iconName: "questionmark.bubble.fill",
                    tint: Color(hex: "4CAF50"),
                    title: "Questions & réponses",
                    subtitle: "Répondez aux questions des clients",
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoogleBusinessInsightsView(slug: slug)
            } label: {
                sectionRow(
                    iconName: "chart.line.uptrend.xyaxis",
                    tint: Color(hex: "34C759"),
                    title: "Statistiques",
                    subtitle: "Vues, clics téléphone, itinéraires",
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoogleBusinessHoursView(slug: slug)
            } label: {
                sectionRow(
                    iconName: "clock.fill",
                    tint: Color(hex: "FF9F0A"),
                    title: "Horaires & infos fiche",
                    subtitle: "Adresse, site, horaires, description",
                    badge: nil
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                GoogleBusinessPhotosView(slug: slug)
            } label: {
                sectionRow(
                    iconName: "photo.on.rectangle.angled",
                    tint: Color(hex: "AF52DE"),
                    title: "Photos de la fiche",
                    subtitle: "Ajoutez ou supprimez des photos",
                    badge: nil
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func subtitleForReviews() -> String {
        let c = vm.status?.counts
        let unreplied = c?.unreplied ?? 0
        let total = c?.total ?? 0
        if unreplied > 0 {
            return "\(unreplied) sans réponse sur \(total) avis"
        }
        if total > 0 {
            return "\(total) avis — tous répondus "
        }
        return "Répondez, IA, star, archive"
    }

    private func sectionRow(iconName: String, tint: Color, title: String, subtitle: String, badge: String?) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.red))
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.7))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 4, x: 0, y: 1.5)
        )
    }

    // MARK: - Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Actions rapides")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)

            if let mapsUrl = mapsUrlString(), let url = URL(string: mapsUrl) {
                Link(destination: url) {
                    actionRow(icon: "map.fill", tint: .blue, title: "Voir ma fiche sur Google Maps")
                }
                .buttonStyle(.plain)
            }
            if let reviewUri = newReviewUrlString(), let url = URL(string: reviewUri) {
                Link(destination: url) {
                    actionRow(icon: "square.and.arrow.up.fill", tint: .orange, title: "Partager le lien pour demander un avis")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 4)
    }

    private func actionRow(icon: String, tint: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Spacer()
            Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 3, x: 0, y: 1)
        )
    }

    private func mapsUrlString() -> String? {
        guard let placeId = vm.status?.matchedPlaceId, !placeId.isEmpty else { return nil }
        return "https://www.google.com/maps/place/?q=place_id:\(placeId)"
    }

    private func newReviewUrlString() -> String? {
        guard let placeId = vm.status?.matchedPlaceId, !placeId.isEmpty else { return nil }
        return "https://search.google.com/local/writereview?placeid=\(placeId)"
    }

    // MARK: - Not connected state

    private var notConnectedState: some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 80)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [Color(red: 0.13, green: 0.45, blue: 0.99), Color(red: 0.48, green: 0.25, blue: 0.95)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    )
                Text("Tableau de bord Google Business")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Connectez votre compte Google qui gère la fiche de votre établissement pour débloquer toutes les fonctionnalités ci‑dessous.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
            }

            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "star.bubble.fill", tint: Color(red: 0.96, green: 0.70, blue: 0.0), title: "Avis clients en direct", subtitle: "Notification à chaque nouvel avis, réponses IA, star/archive")
                featureRow(icon: "megaphone.fill", tint: Color(red: 0.04, green: 0.52, blue: 1.0), title: "Posts Google", subtitle: "Actualités, événements, offres promotionnelles")
                featureRow(icon: "questionmark.bubble.fill", tint: Color(red: 0.30, green: 0.69, blue: 0.31), title: "Questions & réponses", subtitle: "Répondez directement aux clients")
                featureRow(icon: "chart.line.uptrend.xyaxis", tint: Color(red: 0.20, green: 0.78, blue: 0.35), title: "Statistiques Google", subtitle: "Vues, appels, itinéraires, clics site")
                featureRow(icon: "clock.fill", tint: Color(red: 1.0, green: 0.62, blue: 0.04), title: "Horaires & infos fiche", subtitle: "Mise à jour instantanée sur Google Maps")
                featureRow(icon: "photo.on.rectangle.angled", tint: Color(red: 0.69, green: 0.32, blue: 0.87), title: "Photos de la fiche", subtitle: "Ajoutez, triez, supprimez vos photos")
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.Colors.cardBackground)
                    .shadow(color: AppTheme.Colors.shadow, radius: 6, x: 0, y: 2)
            )

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                NotificationCenter.default.post(name: .myfidpassOpenGoogleBusinessSetupSheet, object: nil)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Connecter Google Business")
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
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

            Text("Aucune donnée n'est stockée sans votre accord. Vous pouvez révoquer l'accès à tout moment dans votre compte Google.")
                .font(.caption2)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            Spacer()
        }
    }

    // MARK: - Error banner

    private func errorBanner(_ msg: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Connexion Google Business requise", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(msg)
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
    }
}

// MARK: - Notification.Name

extension Notification.Name {
    static let googleBusinessNewReviewReceived = Notification.Name("googleBusinessNewReviewReceived")
}
