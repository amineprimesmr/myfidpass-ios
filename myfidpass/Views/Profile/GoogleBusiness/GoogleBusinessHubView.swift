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
    @Published var isRetryingLocation: Bool = false
    @Published var retryLocationError: String?
    /// Après un refus Google (quota), on évite de relancer l’API en rafale — aligné avec le message « 1 minute ».
    @Published var retryLocationCooldownUntil: Date?
    @Published var errorMessage: String?
    @Published var notConnected: Bool = false
    @Published var configuredPlaceId: String?
    @Published var isPlaceMismatch: Bool = false
    @Published var unresolvedPlaceBinding: Bool = false

    /// Noms lisibles (via Places API) pour les deux fiches — nil tant que le chargement n'est pas terminé.
    @Published var configuredPlaceName: String?
    @Published var matchedPlaceName: String?
    @Published var isLoadingPlaceNames: Bool = false

    private let slug: String

    /// Désactive « Actualiser » tant qu’on est dans la fenêtre post-quota.
    var isRetryLocationCooldownActive: Bool {
        guard let u = retryLocationCooldownUntil else { return false }
        return u > Date()
    }

    /// Compte à rebours pour l’affichage (secondes), nil si pas de cooldown.
    func retryLocationCooldownSecondsRemaining(from reference: Date) -> Int? {
        guard let u = retryLocationCooldownUntil, u > reference else { return nil }
        return max(0, Int(ceil(u.timeIntervalSince(reference))))
    }

    init(slug: String) {
        self.slug = slug
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await GoogleBusinessAPI.shared.status(slug: slug)
            let settings: BusinessSettingsResponse? = try? await APIClient.shared.request(.businessSettings(slug: slug))
            let configured = settings?.engagementRewards?.googleReview?.placeId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let expected = (configured?.isEmpty == false) ? configured : nil
            let matched = s.matchedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines)
            let linked = (matched?.isEmpty == false) ? matched : nil
            self.status = s
            self.notConnected = !s.connected
            self.configuredPlaceId = expected
            self.isPlaceMismatch = s.connected && expected != nil && linked != nil && expected != linked
            self.unresolvedPlaceBinding = s.connected && expected != nil && linked == nil && !s.locationPending
            self.errorMessage = nil

            if isPlaceMismatch || unresolvedPlaceBinding {
                await loadPlaceNames(configuredId: expected, matchedId: linked)
            }
        } catch APIError.server(let code, _) where code == 409 {
            self.notConnected = true
            self.errorMessage = nil
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Noms lisibles

    private func loadPlaceNames(configuredId: String?, matchedId: String?) async {
        isLoadingPlaceNames = true
        defer { isLoadingPlaceNames = false }
        async let cn = fetchPlaceName(configuredId)
        async let mn = fetchPlaceName(matchedId)
        let (configName, matchedName) = await (cn, mn)
        self.configuredPlaceName = configName
        self.matchedPlaceName = matchedName
    }

    private func fetchPlaceName(_ placeId: String?) async -> String? {
        guard let id = placeId?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else { return nil }
        if let res = try? await APIClient.shared.request(.placesPlaceDetails(placeId: id)) as PlacesPlaceDetailsResponse {
            let name = (res.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let addr = (res.formattedAddress ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return addr.isEmpty ? name : "\(name), \(addr)"
            }
        }
        return String(id.prefix(24)) + (id.count > 24 ? "…" : "")
    }

    // MARK: - Actions mismatch

    /// Adopte le matchedPlaceId comme fiche configurée du commerce.
    /// Poste la notification qui déclenche la mise à jour + autosave dans EstablishmentEditorView.
    func adoptMatchedPlace() {
        guard let matchedId = status?.matchedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines), !matchedId.isEmpty else { return }
        NotificationCenter.default.postAdoptMatchedGooglePlaceId(matchedId)
        // Mise à jour optimiste locale pour effacer immédiatement la bannière
        configuredPlaceId = matchedId
        configuredPlaceName = matchedPlaceName
        isPlaceMismatch = false
        unresolvedPlaceBinding = false
    }

    // MARK: - Pending location retry

    func retryPendingLocation() async {
        guard !isRetryingLocation else { return }
        guard !isRetryLocationCooldownActive else { return }
        isRetryingLocation = true
        retryLocationError = nil
        defer { isRetryingLocation = false }
        do {
            let result = try await GoogleBusinessAPI.shared.retryPendingLocation(slug: slug)
            if result.resolved {
                retryLocationCooldownUntil = nil
                await load()
            } else {
                let raw = result.lastError ?? ""
                if raw == "token_expired_reconnect_required" || raw.contains("credentials") || raw.contains("invalid_grant") {
                    retryLocationError = "Session Google expirée. Tapez « Reconnecter »."
                } else if raw == "no_locations" || raw.contains("no_locations") {
                    retryLocationError = "Aucune fiche trouvée sur ce compte. Tapez « Reconnecter » avec le compte qui gère votre établissement Google."
                } else if raw == "google_api_quota" || raw.contains("quota") || raw.contains("Quota") || raw.contains("RESOURCE_EXHAUSTED") {
                    // Cooldown côté client pour ne pas enchaîner les appels inutiles (soulage l’utilisateur + le serveur).
                    retryLocationCooldownUntil = Date().addingTimeInterval(75)
                    retryLocationError = "Limite temporaire côté Google. Patientez ~1 min avant d’appuyer à nouveau sur « Actualiser », ou réessayez plus tard."
                } else if raw == "retry_cooldown" {
                    retryLocationError = "Dernière tentative trop récente — patientez quelques secondes."
                } else if raw.isEmpty {
                    retryLocationError = "Fiche introuvable. Tapez « Reconnecter »."
                } else if raw.count > 120 {
                    retryLocationError = "Erreur Google. Tapez « Reconnecter » pour refaire la connexion."
                } else {
                    retryLocationError = raw
                }
            }
        } catch {
            retryLocationError = "Échec de la connexion. Vérifiez votre réseau et réessayez."
        }
    }

    // MARK: - Sync / actions

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
    /// Pousse le rafraîchissement du libellé du cooldown (1 s) tant que `retryLocationCooldownUntil` est actif.
    @State private var retryCooldownNow = Date()

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessHubViewModel(slug: slug))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if vm.notConnected {
                    notConnectedState
                } else if vm.status?.locationPending == true {
                    locationPendingBanner
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { t in
            if vm.status?.locationPending == true, vm.retryLocationCooldownUntil != nil { retryCooldownNow = t }
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
                        .font(.system(.title3, design: .default, weight: .bold))
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

            // Carte mismatch / unresolved toujours en premier plan si présente
            if vm.isPlaceMismatch || vm.unresolvedPlaceBinding {
                placeBindingWarningCard
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

    // MARK: - Carte mismatch / unresolved (refaite)

    private var placeBindingWarningCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            // — Titre selon le cas —
            if vm.isPlaceMismatch {
                Label("Fiches différentes", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.orange)
            } else {
                Label("Aucune fiche associée", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.orange)
            }

            // — Détail des deux fiches (mismatch uniquement) —
            if vm.isPlaceMismatch {
                VStack(alignment: .leading, spacing: 6) {
                    placeRow(
                        icon: "building.2",
                        label: "Votre commerce",
                        name: vm.configuredPlaceName,
                        fallbackId: vm.configuredPlaceId,
                        isLoading: vm.isLoadingPlaceNames
                    )
                    placeRow(
                        icon: "link",
                        label: "Compte Google connecté",
                        name: vm.matchedPlaceName ?? vm.status?.locationTitle,
                        fallbackId: vm.status?.matchedPlaceId,
                        isLoading: vm.isLoadingPlaceNames
                    )
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.orange.opacity(0.07))
                )

                Text("Ces deux fiches ne correspondent pas. Choisissez la correction à appliquer :")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                // unresolvedPlaceBinding
                let commerceName = vm.configuredPlaceName ?? vm.configuredPlaceId ?? "configurée"
                Text("Le compte Google connecté ne gère aucune fiche correspondant à votre commerce (\(commerceName)). Reconnectez-vous avec le compte Google propriétaire de cette fiche.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // — Boutons d'action —
            HStack(spacing: 8) {
                if vm.isPlaceMismatch {
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        vm.adoptMatchedPlace()
                    } label: {
                        Text("Adopter la fiche connectée")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(AppTheme.Colors.success.opacity(0.14)))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    NotificationCenter.default.post(name: .myfidpassOpenGoogleBusinessSetupSheet, object: nil)
                } label: {
                    Text(vm.isPlaceMismatch ? "Reconnecter" : "Reconnecter un compte")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.14)))
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
        )
    }

    /// Ligne nom de fiche avec état de chargement.
    private func placeRow(icon: String, label: String, name: String?, fallbackId: String?, isLoading: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                if isLoading && name == nil {
                    ProgressView().controlSize(.mini)
                } else {
                    Text(name ?? fallbackId ?? "—")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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
                .font(.system(.title3, design: .default, weight: .bold))
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
                        .font(.system(.body, design: .default, weight: .semibold))
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
        return CommerceStatsGoogleMapsOpener.mapsPlaceURL(placeId: placeId)?.absoluteString
    }

    private func newReviewUrlString() -> String? {
        guard let placeId = vm.status?.matchedPlaceId, !placeId.isEmpty else { return nil }
        return "https://search.google.com/local/writereview?placeid=\(placeId)"
    }

    // MARK: - Location pending state

    private var locationPendingBanner: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(vm.isRetryingLocation ? AppTheme.Colors.primary.opacity(0.10) : Color.orange.opacity(0.12))
                        .frame(width: 72, height: 72)
                    if vm.isRetryingLocation {
                        ProgressView()
                            .controlSize(.large)
                            .tint(AppTheme.Colors.primary)
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                }
                Text(vm.isRetryingLocation ? "Identification en cours…" : "Fiche non identifiée")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                if let err = vm.retryLocationError {
                    Text(err)
                        .font(.subheadline)
                        .foregroundStyle(vm.isRetryLocationCooldownActive ? AppTheme.Colors.textSecondary : Color.red.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    if let s = vm.retryLocationCooldownSecondsRemaining(from: retryCooldownNow), s > 0 {
                        Text("Bouton « Actualiser » disponible dans ~\(s) s")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                } else {
                    Text("Votre compte Google Business est connecté mais la fiche n'a pas encore pu être identifiée. Tapez « Actualiser » pour réessayer, ou reconnectez votre compte Google.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 12) {
                Button {
                    Task { await vm.retryPendingLocation() }
                } label: {
                    Group {
                        if vm.isRetryingLocation {
                            Label("Identification…", systemImage: "arrow.clockwise")
                        } else if vm.isRetryLocationCooldownActive {
                            Label("Patientez…", systemImage: "clock")
                        } else {
                            Label("Actualiser", systemImage: "arrow.clockwise")
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .background(Capsule().fill(AppTheme.Colors.primary.opacity(0.12)))
                    .foregroundStyle((vm.isRetryLocationCooldownActive && !vm.isRetryingLocation) ? AppTheme.Colors.textSecondary : AppTheme.Colors.primary)
                }
                .buttonStyle(.plain)
                .disabled(vm.isRetryingLocation || vm.isRetryLocationCooldownActive)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    NotificationCenter.default.post(name: .myfidpassOpenGoogleBusinessSetupSheet, object: nil)
                } label: {
                    Label("Reconnecter", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(Capsule().fill(Color.orange.opacity(0.12)))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .disabled(vm.isRetryingLocation)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.Colors.cardBackground)
                .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 3)
        )
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
                    .font(.system(.title2, design: .default, weight: .bold))
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
