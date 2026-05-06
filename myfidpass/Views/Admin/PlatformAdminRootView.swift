//
//  PlatformAdminRootView.swift
//  myfidpass
//
//  Hub unique **Commerces** (recherche + pilotage) ; pages dédiées : Statistiques, Comptes, Paiements.
//

import SwiftUI

// MARK: - Navigation

private enum AdminRoute: Hashable {
    case statistics
    case accounts
    case payments
    case commerce(AdminBusinessRow)
}

/// Racine admin : une pile de navigation, page d’accueil = liste des commerces.
struct PlatformAdminRootView: View {
    @EnvironmentObject private var authService: AuthService

    var body: some View {
        NavigationStack {
            PlatformAdminCommerceHubView()
                .navigationDestination(for: AdminRoute.self) { route in
                    switch route {
                    case .statistics:
                        PlatformAdminStatisticsPage()
                    case .accounts:
                        PlatformAdminAccountsPage()
                    case .payments:
                        PlatformAdminPaymentsPage()
                    case .commerce(let business):
                        PlatformAdminCommerceDetailPage(business: business)
                    }
                }
        }
        .tint(AppTheme.Colors.primary)
    }
}

// MARK: - Hub (page principale)

private struct PlatformAdminCommerceHubView: View {
    @EnvironmentObject private var authService: AuthService
    @State private var businesses: [AdminBusinessRow] = []
    @State private var overview: AdminOverviewResponse?
    @State private var search = ""
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hubHeader
                statsStrip
                quickLinksSection
                commerceSectionHeader
                if isLoading && businesses.isEmpty {
                    ProgressView("Chargement des commerces…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let loadError {
                    Text(loadError)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Colors.error)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredBusinesses) { b in
                            commerceCard(b)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Administration")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $search, prompt: "Rechercher un commerce, slug, e-mail…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Label("Mode commerçant", systemImage: "briefcase.fill")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button(role: .destructive) {
                        authService.logout()
                    } label: {
                        Label("Déconnexion", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await loadAll() }
        .refreshable { await loadAll() }
    }

    private var hubHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tous les commerces")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Recherchez, ouvrez la fiche ou pilotez le tableau de bord comme le commerçant (carte, notifs, flyer).")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(.top, 4)
    }

    private var statsStrip: some View {
        HStack(spacing: 10) {
            statPill(title: "Comptes", value: overview?.usersCount)
            statPill(title: "Commerces", value: overview?.businessesCount)
            statPill(title: "Abos actifs", value: overview?.activeSubscriptionsCount)
        }
    }

    private func statPill(title: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text(value.map(String.init) ?? "—")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .appCardShadowLight()
    }

    private var quickLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Données plateforme")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                adminNavRow(
                    route: .statistics,
                    icon: "chart.bar.doc.horizontal.fill",
                    title: "Statistiques",
                    subtitle: "Vue globale des comptes et abonnements"
                )
                Divider().padding(.leading, 52)
                adminNavRow(
                    route: .accounts,
                    icon: "person.3.fill",
                    title: "Comptes commerçants",
                    subtitle: "Tous les utilisateurs inscrits"
                )
                Divider().padding(.leading, 52)
                adminNavRow(
                    route: .payments,
                    icon: "creditcard.fill",
                    title: "Paiements Stripe",
                    subtitle: "Abonnements, packs flyer — journal admin"
                )
            }
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .appCardShadowLight()
        }
    }

    private func adminNavRow(route: AdminRoute, icon: String, title: String, subtitle: String) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 36, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var commerceSectionHeader: some View {
        HStack {
            Text("Commerces")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)
            Spacer()
            Text("\(filteredBusinesses.count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.Colors.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.Colors.primary.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private func commerceCard(_ b: AdminBusinessRow) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(b.organizationName ?? b.name ?? "Sans nom")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text(b.slug)
                        .font(.caption.monospaced())
                        .foregroundStyle(AppTheme.Colors.primary)
                }
                Spacer(minLength: 0)
                subscriptionBadge(b)
            }

            if let em = b.ownerEmail, !em.isEmpty {
                Label(em, systemImage: "envelope.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            HStack(spacing: 8) {
                Label("\(b.memberCount ?? 0) membres", systemImage: "person.2.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                if let created = b.createdAt, !created.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(created)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 10) {
                NavigationLink(value: AdminRoute.commerce(b)) {
                    Label("Fiche & réglages", systemImage: "doc.text.magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    authService.selectBusiness(slug: b.slug, showSwitchingOverlay: false)
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Label("Piloter", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .appCardShadowLight()
    }

    private func subscriptionBadge(_ b: AdminBusinessRow) -> some View {
        let st = (b.ownerSubscriptionStatus ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let label: String = {
            if st.isEmpty { return "Sans abo" }
            if st == "active" || st == "trialing" { return st == "trialing" ? "Essai / actif" : "Abonné" }
            if st == "past_due" { return "Paiement en retard" }
            return st.replacingOccurrences(of: "_", with: " ")
        }()
        let color: Color = {
            if st == "active" || st == "trialing" { return AppTheme.Colors.success }
            if st == "past_due" { return AppTheme.Colors.warning }
            if st.isEmpty { return AppTheme.Colors.textSecondary }
            return AppTheme.Colors.textSecondary
        }()
        return Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var filteredBusinesses: [AdminBusinessRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return businesses }
        return businesses.filter { b in
            [b.slug, b.name, b.organizationName, b.ownerEmail, b.ownerPlanId, b.ownerSubscriptionStatus]
                .compactMap { $0?.lowercased() }
                .contains { $0.contains(q) }
        }
    }

    private func loadAll() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            async let o: AdminOverviewResponse = APIClient.shared.request(.adminOverview)
            async let r: AdminBusinessesListResponse = APIClient.shared.request(
                .adminBusinesses(q: nil, limit: 500, offset: 0)
            )
            overview = try await o
            businesses = try await r.businesses
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Statistiques

private struct PlatformAdminStatisticsPage: View {
    @EnvironmentObject private var authService: AuthService
    @State private var overview: AdminOverviewResponse?
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Vue agrégée de la base (comptes utilisateurs, fiches commerces, lignes d’abonnement Stripe actives / essai / période de grâce).")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let loadError {
                    Text(loadError).foregroundStyle(AppTheme.Colors.error)
                } else if let o = overview {
                    VStack(spacing: 12) {
                        bigStatRow(title: "Comptes utilisateurs", value: o.usersCount, hint: "Inscriptions / connexions logiciel")
                        bigStatRow(title: "Fiches commerce", value: o.businessesCount, hint: "Programmes fidélité créés")
                        bigStatRow(
                            title: "Abonnements actifs (Stripe)",
                            value: o.activeSubscriptionsCount,
                            hint: "Statuts : active, trialing, past_due"
                        )
                    }
                }
            }
            .padding(16)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Statistiques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Image(systemName: "briefcase.fill")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func bigStatRow(title: String, value: Int?, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value.map(String.init) ?? "—")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(AppTheme.Colors.primary)
            Text(hint)
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .appCardShadowLight()
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            overview = try await APIClient.shared.request(.adminOverview)
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Comptes

private struct PlatformAdminAccountsPage: View {
    @EnvironmentObject private var authService: AuthService
    @State private var users: [AdminUserRow] = []
    @State private var search = ""
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tous les comptes ayant accès au logiciel. Les pastilles « admin » ont accès à cette console.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            ForEach(filteredUsers) { u in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(u.email ?? u.id)
                            .font(.body.weight(.semibold))
                        if u.isAdminFlag {
                            Text("ADMIN")
                                .font(.caption2.weight(.heavy))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.Colors.primary.opacity(0.2))
                                .foregroundStyle(AppTheme.Colors.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    if let n = u.name, !n.isEmpty {
                        Text(n)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let c = u.createdAt, !c.isEmpty {
                        Text("Créé : \(c)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Comptes")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "E-mail, nom…")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Image(systemName: "briefcase.fill")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if isLoading && users.isEmpty {
                ProgressView()
            }
        }
    }

    private var filteredUsers: [AdminUserRow] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return users }
        return users.filter { u in
            [u.email, u.name, u.id].compactMap { $0?.lowercased() }.contains { $0.contains(q) }
        }
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let r: AdminUsersListResponse = try await APIClient.shared.request(.adminUsers(q: nil, limit: 500, offset: 0))
            users = r.users
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Paiements

private struct PlatformAdminPaymentsPage: View {
    @EnvironmentObject private var authService: AuthService
    @State private var events: [AdminEventRow] = []
    @State private var loadError: String?
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Événements liés à Stripe (checkout abonnement, pack flyer). Les renouvellements automatiques peuvent apparaître selon la config serveur.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.error)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
            ForEach(events) { ev in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(paymentKindTitle(ev.eventType))
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        if let t = ev.createdAt {
                            Text(t)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    if let detail = prettyPayload(ev.payloadJson), !detail.isEmpty {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if let sid = ev.stripeEventId, !sid.isEmpty {
                        Text("Stripe : \(sid)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Paiements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Image(systemName: "briefcase.fill")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .overlay {
            if isLoading && events.isEmpty {
                ProgressView()
            }
        }
    }

    private func paymentKindTitle(_ type: String) -> String {
        let t = type.lowercased()
        if t.contains("subscription") { return "Abonnement" }
        if t.contains("flyer") { return "Pack flyer" }
        return type
    }

    private func prettyPayload(_ json: String?) -> String? {
        guard let json, let d = json.data(using: .utf8) else { return nil }
        guard let obj = try? JSONSerialization.jsonObject(with: d) else {
            return String(json.prefix(280))
        }
        guard let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let s = String(data: pretty, encoding: .utf8) else { return nil }
        return s.count > 1200 ? String(s.prefix(1200)) + "…" : s
    }

    private func load() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let r: AdminEventsListResponse = try await APIClient.shared.request(
                .adminEvents(limit: 250, filter: "payments")
            )
            events = r.events
        } catch {
            loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Fiche commerce

private struct PlatformAdminCommerceDetailPage: View {
    @EnvironmentObject private var authService: AuthService
    let business: AdminBusinessRow

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    detailSection(title: "Identité") {
                        detailRow("Nom affiché", business.organizationName ?? business.name ?? "—")
                        detailRow("Slug", business.slug)
                        detailRow("ID interne", business.id)
                    }
                    detailSection(title: "Propriétaire") {
                        detailRow("E-mail", business.ownerEmail ?? "—")
                        detailRow("ID utilisateur", business.userId ?? "—")
                        detailRow("Abonnement Stripe", (business.ownerSubscriptionStatus ?? "—").replacingOccurrences(of: "_", with: " "))
                        detailRow("Formule", business.ownerPlanId ?? "—")
                    }
                    detailSection(title: "Activité") {
                        detailRow("Membres (cartes)", "\(business.memberCount ?? 0)")
                        detailRow("Créé le", business.createdAt ?? "—")
                    }
                }

                VStack(spacing: 12) {
                    Button {
                        authService.selectBusiness(slug: business.slug, showSwitchingOverlay: false)
                        Task { await authService.openMerchantWorkspaceFromAdmin() }
                    } label: {
                        Label("Ouvrir l’espace commerçant (réglages, carte, notifs, flyer)", systemImage: "slider.horizontal.3")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Text("Vous basculez sur l’interface habituelle avec ce commerce présélectionné. Le bandeau « Administration » permet d’en revenir.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Fiche commerce")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await authService.openMerchantWorkspaceFromAdmin() }
                } label: {
                    Image(systemName: "briefcase.fill")
                }
            }
        }
    }

    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .appCardShadowLight()
        }
    }

    private func detailRow(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(k)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(v)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Ombre

private extension View {
    func appCardShadowLight() -> some View {
        shadow(color: AppTheme.Colors.shadow.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
