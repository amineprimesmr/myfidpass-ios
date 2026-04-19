//
//  GoogleReviewsSetupSheet.swift
//  myfidpass
//
//  Lie la fiche Google Maps du commerce (Place ID) pour la mission « avis Google ».
//

import SwiftUI

/// Formulaire guidé : réutilise le lieu choisi à l’inscription, recherche optionnelle, saisie manuelle du Place ID.
struct GoogleReviewsSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @Binding var googlePlaceId: String
    @Binding var googleAutoVerifyEnabled: Bool
    /// Appelé quand le Place ID ou la validation auto changent (sauvegarde serveur côté parent).
    var onValuesCommitted: (() -> Void)? = nil

    @State private var pickerPlaceId: String?
    @State private var pickerDescription: String?
    @State private var relaxUnused = false
    @State private var manualPlaceId = ""
    @State private var localAutoVerify = true
    /// `false` quand un lieu est déjà connu (inscription ou serveur) : on affiche la carte récap plutôt que la recherche.
    @State private var showSearchSection = false
    @State private var isLoadingDetails = false
    /// Évite de pousser les bindings pendant l’hydratation initiale (sinon sauvegardes en rafale).
    @State private var isHydrating = true
    /// Métriques canal Google (OAuth Business + aperçu avis).
    @State private var googleChannelRow: SocialMetricsChannelRow?
    @State private var googleLocationPending = false
    @State private var googleMetricsLoading = false
    @State private var googleBusinessError: String?
    @State private var isConnectingGoogleBusiness = false

    private var effectivePlaceId: String {
        let fromPicker = (pickerPlaceId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !fromPicker.isEmpty { return fromPicker }
        return manualPlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var previewReviewURL: URL? {
        let id = effectivePlaceId
        guard !id.isEmpty else { return nil }
        var c = URLComponents(string: "https://search.google.com/local/writereview")!
        c.queryItems = [URLQueryItem(name: "placeid", value: id)]
        return c.url
    }

    private var linkedTitle: String {
        let d = (pickerDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty else { return "Fiche Google Maps" }
        let parts = d.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        return parts.first ?? d
    }

    private var linkedSubtitle: String? {
        let d = (pickerDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !d.isEmpty else { return nil }
        let parts = d.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 { return String(parts[1]) }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !EngagementTemporaryVisibility.hideGoogleBusinessOAuthInReviewsSheet {
                    googleBusinessLiveSection
                }

                infoBlock

                if isLoadingDetails {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Chargement de votre fiche…")
                            .font(AppTheme.Fonts.caption())
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !showSearchSection, !effectivePlaceId.isEmpty {
                    linkedPlaceBlock
                }

                if showSearchSection || effectivePlaceId.isEmpty {
                    sectionTitle("1. Rechercher votre commerce")
                    Text(
                        "Choisissez votre établissement dans les suggestions — comme à l’inscription. Il s’agit de la fiche Google Maps du lieu, pas de votre compte Gmail."
                    )
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                    GoogleEstablishmentPicker(
                        selectedPlaceId: $pickerPlaceId,
                        selectedDescription: $pickerDescription,
                        relaxRequirement: $relaxUnused,
                        compactIntro: true
                    )
                    .onChange(of: pickerPlaceId) { _, new in
                        if let id = new?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
                            manualPlaceId = id
                        }
                        if !isHydrating { syncBindingsFromLocalState() }
                    }
                }

                Divider()
                    .padding(.vertical, 4)

                sectionTitle(showSearchSection || effectivePlaceId.isEmpty ? "2. Ou coller le Place ID" : "Place ID (avancé)")
                Text(
                    "Si vous connaissez déjà l’identifiant (souvent une chaîne commençant par ChIJ), collez-le ci‑dessous."
                )
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

                TextField("Ex. ChIJN1t_tDeuEmsRUsoyG83frY4", text: $manualPlaceId)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: manualPlaceId) { _, new in
                        let t = new.trimmingCharacters(in: .whitespacesAndNewlines)
                        if pickerPlaceId != nil, pickerPlaceId != t { pickerPlaceId = nil; pickerDescription = nil }
                        if !isHydrating { syncBindingsFromLocalState() }
                    }

                Toggle(isOn: $localAutoVerify) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Validation automatique")
                            .font(.body.weight(.medium))
                        Text(
                            "Après que le client revienne depuis Google, la mission peut être validée automatiquement (recommandé)."
                        )
                        .font(AppTheme.Fonts.caption2())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .tint(AppTheme.Colors.primary)
                .padding(.top, 4)
                .onChange(of: localAutoVerify) { _, _ in
                    if !isHydrating { syncBindingsFromLocalState() }
                }

                linksBlock
            }
            .padding(18)
        }
        .background(AppTheme.Colors.background.opacity(0.35))
        .navigationTitle("Avis Google")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Terminé") {
                    syncBindingsFromLocalState()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            await MainActor.run { isHydrating = true }
            await hydrateFromOnboardingOrServer()
            await MainActor.run { isHydrating = false }
            if !EngagementTemporaryVisibility.hideGoogleBusinessOAuthInReviewsSheet {
                await loadGoogleBusinessSection()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassEngagementOAuthDidComplete)) { _ in
            guard !EngagementTemporaryVisibility.hideGoogleBusinessOAuthInReviewsSheet else { return }
            Task { await loadGoogleBusinessSection() }
        }
    }

    private func loadGoogleBusinessSection() async {
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else {
            return
        }
        await MainActor.run { googleMetricsLoading = true }
        defer { Task { @MainActor in googleMetricsLoading = false } }
        do {
            let s: SocialMetricsSummaryResponse = try await APIClient.shared.request(.dashboardSocialMetrics(slug: slug))
            let row = s.channels.first { $0.channel == "google_review" }
            await MainActor.run {
                googleChannelRow = row
                googleLocationPending = s.googleBusinessLocationPending == true
                // Ne pas effacer ici les erreurs OAuth (quota, etc.) : `loadGoogleBusinessSection` est appelée juste après un échec connexion.
                if row?.oauthConnected == true { googleBusinessError = nil }
            }
        } catch {
            await MainActor.run { googleBusinessError = "Impossible de charger les avis." }
        }
    }

    private func startGoogleBusinessOAuthFlow() {
        isConnectingGoogleBusiness = true
        googleBusinessError = nil
        Task {
            let outcome = await EngagementOAuthLauncher.connectGoogleBusiness()
            await MainActor.run {
                isConnectingGoogleBusiness = false
                switch outcome {
                case .success:
                    NotificationCenter.default.post(name: .myfidpassEngagementOAuthDidComplete, object: nil)
                case .failure(let msg):
                    googleBusinessError = msg
                case .cancelled:
                    break
                }
            }
            await loadGoogleBusinessSection()
        }
    }

    @ViewBuilder
    private var googleBusinessLiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Avis en direct (Google Business)")
            Text(
                "Connectez-vous avec le compte Google qui gère votre fiche d’établissement : avis réels et mise à jour. Si vous avez déjà indiqué le lieu ci‑dessous, nous l’associons à la bonne fiche quand c’est possible."
            )
            .font(AppTheme.Fonts.caption())
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if googleMetricsLoading, googleChannelRow == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let err = googleBusinessError {
                Text(err)
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.error)
            }

            let gbpConnected = googleChannelRow?.oauthConnected == true
            if gbpConnected {
                Label("Compte Google Business connecté", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.success)

                if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
                    NavigationLink {
                        GoogleBusinessHubView(slug: slug)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ouvrir le tableau de bord complet")
                                    .font(.subheadline.weight(.semibold))
                                Text("Avis, posts, Q&A, stats, horaires, photos")
                                    .font(.caption2)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.85)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: AppTheme.Colors.primary.opacity(0.3), radius: 6, x: 0, y: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            if gbpConnected, googleLocationPending {
                Label(
                    "Liaison avec ta fiche établissement en attente (quota Google). Utilise « Rafraîchir les avis » sur le profil ou réessaie plus tard — nous finalisons dès que l’API répond.",
                    systemImage: "clock.arrow.circlepath"
                )
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                startGoogleBusinessOAuthFlow()
            } label: {
                HStack(spacing: 10) {
                    if isConnectingGoogleBusiness {
                        ProgressView()
                    }
                    Text(gbpConnected ? "Reconnecter un autre compte" : "Connecter Google Business")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
            .disabled(isConnectingGoogleBusiness)

            if let samples = googleChannelRow?.reviewsSample, !samples.isEmpty {
                sectionTitle("Derniers avis")
                ForEach(samples) { r in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text((r.author?.isEmpty == false) ? (r.author ?? "") : "Avis")
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 8)
                            if let stars = r.rating, stars > 0 {
                                Text(String(format: "★ %.0f", stars))
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                        if let t = r.text, !t.isEmpty {
                            Text(t)
                                .font(AppTheme.Fonts.caption())
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.Colors.cardBackground.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            } else if gbpConnected {
                Text("Aucun avis renvoyé pour l’instant — touchez « Rafraîchir les avis » sur la ligne Google du profil (menu contextuel) ou attendez la prochaine synchro.")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.primary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Fusionne compte / cache marchand, puis complète le libellé via l’API si besoin.
    private func hydrateFromOnboardingOrServer() async {
        let cur = googlePlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cached = MerchantLinkedPlaceCache.read()
        let resolvedId = !cur.isEmpty ? cur : (cached.placeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            manualPlaceId = resolvedId
            localAutoVerify = googleAutoVerifyEnabled
            showSearchSection = resolvedId.isEmpty
        }

        guard !resolvedId.isEmpty else { return }

        if let desc = cached.description?.trimmingCharacters(in: .whitespacesAndNewlines), !desc.isEmpty,
           resolvedId == (cached.placeId ?? "").trimmingCharacters(in: .whitespacesAndNewlines) {
            await MainActor.run {
                pickerPlaceId = resolvedId
                pickerDescription = desc
            }
            return
        }

        await MainActor.run { isLoadingDetails = true }

        do {
            let res: PlacesPlaceDetailsResponse = try await APIClient.shared.request(.placesPlaceDetails(placeId: resolvedId))
            let name = res.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let addr = res.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            await MainActor.run {
                pickerPlaceId = res.placeId
                if !name.isEmpty, !addr.isEmpty {
                    pickerDescription = "\(name), \(addr)"
                } else if !name.isEmpty {
                    pickerDescription = name
                } else {
                    pickerDescription = resolvedId
                }
            }
        } catch {
            await MainActor.run {
                pickerPlaceId = resolvedId
                pickerDescription = String(resolvedId.prefix(28)) + (resolvedId.count > 28 ? "…" : "")
            }
        }

        await MainActor.run { isLoadingDetails = false }
    }

    private var linkedPlaceBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("Fiche utilisée pour les avis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppTheme.Colors.success)
            }

            Text(
                "C’est le lieu que vous aviez indiqué à l’inscription (ou déjà enregistré). Vous pouvez enregistrer tel quel ou changer la fiche ci‑dessous."
            )
            .font(AppTheme.Fonts.caption())
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            GroupedSettingsCard {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: GroupedSettingsMetrics.iconBoxCorner, style: .continuous)
                            .fill(AppTheme.Colors.success.opacity(0.18))
                            .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(linkedTitle)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .multilineTextAlignment(.leading)
                        if let sub = linkedSubtitle, !sub.isEmpty {
                            Text(sub)
                                .font(.subheadline)
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            }

            if #available(iOS 26.0, *) {
                Button {
                    showSearchSection = true
                    pickerPlaceId = nil
                    pickerDescription = nil
                } label: {
                    Text("Changer de fiche Google Maps")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            } else {
                Button {
                    showSearchSection = true
                    pickerPlaceId = nil
                    pickerDescription = nil
                } label: {
                    Text("Changer de fiche Google Maps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Ce n’est pas une connexion à votre compte Google")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            } icon: {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            Text(
                EngagementTemporaryVisibility.hideGoogleBusinessOAuthInReviewsSheet
                    ? "Pour la mission « laisser un avis », l’app utilise la fiche Google Maps ci‑dessous (Place ID public) : le client ouvre la page pour rédiger son avis. Aucune connexion à votre compte Google n’est nécessaire."
                    : "Pour la mission « laisser un avis », l’app utilise le lieu Maps ci‑dessous (lien page avis pour le client). Pour consulter vos avis côté commerçant, connectez Google Business en haut de l’écran."
            )
            .font(AppTheme.Fonts.caption())
            .foregroundStyle(AppTheme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.Colors.textPrimary)
    }

    private var linksBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Aide")
            linkButton(title: "Ouvrir Google Maps", systemImage: "map", url: LegalURLs.googleMaps)
            linkButton(
                title: "Trouver le Place ID (outil Google)",
                systemImage: "link",
                url: LegalURLs.googlePlaceIdFinder
            )
            if let previewReviewURL {
                linkButton(title: "Voir la page avis (aperçu)", systemImage: "star.bubble", url: previewReviewURL)
            }
        }
        .padding(.top, 8)
    }

    private func linkButton(title: String, systemImage: String, url: URL) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(width: 24)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func syncBindingsFromLocalState() {
        let id = effectivePlaceId.trimmingCharacters(in: .whitespacesAndNewlines)
        googlePlaceId = id
        googleAutoVerifyEnabled = localAutoVerify
        if !id.isEmpty {
            MerchantLinkedPlaceCache.save(placeId: id, description: pickerDescription)
        }
        onValuesCommitted?()
    }
}
