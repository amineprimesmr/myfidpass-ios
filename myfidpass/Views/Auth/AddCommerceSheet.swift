//
//  AddCommerceSheet.swift
//  myfidpass
//
//  Feuille « Ajouter un commerce » : même UX / design que l’étape établissement du premier lancement
//  (`MyfidpassMerchantOnboardingFlow` → `MerchantOBEstablishmentSearchContent`) + `POST /api/businesses/create-from-place`.
//

import SwiftUI
import UIKit

struct AddCommerceSheet: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var syncService: SyncService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @StateObject private var hapticManager = HapticManager.shared

    @State private var selectedPlaceId: String?
    @State private var selectedDescription: String?
    @State private var relaxRequirement = false
    @State private var isPredictionsVisible = false
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canConfirm: Bool {
        guard let pid = selectedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !pid.isEmpty
    }

    /// Place IDs Google déjà connus pour les commerces du compte (cache réglages) — filet avec le filtre serveur sur `/api/places/autocomplete`.
    private var googlePlaceIdsAlreadyLinkedOnAccount: Set<String> {
        var out = Set<String>()
        for b in authService.businesses {
            let slug = b.slug.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !slug.isEmpty else { continue }
            if let pid = ScanFlowSettingsCache.cached(for: slug)?.engagementRewards?.googleReview?.placeId?
                .trimmingCharacters(in: .whitespacesAndNewlines), !pid.isEmpty {
                out.insert(pid)
            }
        }
        return out
    }

    private var establishmentSearchTopReserved: CGFloat {
        if horizontalSizeClass == .regular { return 56 }
        return MyfidpassOnboardingConstants.titleAreaHeight
            + MyfidpassOnboardingConstants.titleToContentSpacing
            + MyfidpassOnboardingConstants.processStyleFieldExtraSpacing
    }

    private var horizontalGutter: CGFloat {
        horizontalSizeClass == .regular ? 40 : 16
    }

    var body: some View {
        ZStack {
            AppTheme.Colors.background
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            AnimatedOnboardingGlow(
                currentStep: 0,
                visitedStepsCount: 1,
                totalStepsForFlow: 1
            )
            .opacity(0.22)
            .ignoresSafeArea(.all)
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: establishmentSearchTopReserved)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        GoogleEstablishmentPicker(
                            selectedPlaceId: $selectedPlaceId,
                            selectedDescription: $selectedDescription,
                            relaxRequirement: $relaxRequirement,
                            compactIntro: true,
                            processEstablishmentStyle: true,
                            alreadyAddedPlaceIds: googlePlaceIdsAlreadyLinkedOnAccount,
                            onPredictionsVisibilityChanged: { visible in
                                isPredictionsVisible = visible
                            }
                        )
                        .padding(.horizontal, horizontalGutter)

                        if let error = errorMessage {
                            Text(error)
                                .font(AppTheme.Fonts.subheadline())
                                .foregroundStyle(Color.red.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                                .padding(.top, 16)
                        }

                        Color.clear.frame(height: 24)
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.onboardingTransition, value: isPredictionsVisible)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomContinueBar
        }
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(isCreating)
        .task {
            await authService.refreshMerchantBillingStateFromServer(force: true)
        }
    }

    /// CTA fixé en bas : le clavier remonte la zone sûre (plus de `Spacer` dans un `ZStack` sans hauteur max).
    private var bottomContinueBar: some View {
        VStack(spacing: 0) {
            Button(action: confirmAddCommerce) {
                Group {
                    if isCreating {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.primary)
                                .scaleEffect(0.9)
                            Text("CRÉATION…")
                                .font(.system(size: 20, weight: .black))
                        }
                    } else {
                        Text("CONTINUER")
                            .font(.system(size: 20, weight: .black))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .glassStyle()
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .tint(.primary)
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .disabled(!canConfirm || isCreating)
            .opacity(canConfirm && !isCreating ? 1.0 : 0.5)
            .allowsHitTesting(canConfirm && !isCreating)
        }
        .frame(maxWidth: .infinity)
        .background(AppTheme.Colors.background.opacity(0.94))
    }

    private func confirmAddCommerce() {
        guard let placeId = selectedPlaceId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !placeId.isEmpty else { return }
        let rawDescription = selectedDescription?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let establishmentNamePreview = establishmentName(from: rawDescription)
        guard !establishmentNamePreview.isEmpty else { return }

        Task { @MainActor in
            await authService.refreshMerchantBillingStateFromServer(force: true)
            guard authService.canCreateBusiness else {
                NotificationCenter.default.postOpenMerchantSubscription(
                    usedBusinesses: authService.usedBusinesses,
                    allowedBusinesses: authService.allowedBusinesses,
                    addingAnotherCommerce: true,
                    pendingCommerceName: establishmentNamePreview
                )
                return
            }
            await performConfirmAddCommerceAfterQuotaCheck(
                establishmentName: establishmentNamePreview,
                placeId: placeId
            )
        }
    }

    @MainActor
    private func performConfirmAddCommerceAfterQuotaCheck(establishmentName: String, placeId: String) async {
        hapticManager.impact(.medium)
        isCreating = true
        errorMessage = nil
        defer { isCreating = false }
        do {
            try await performCreateCommerce(establishmentName: establishmentName, placeId: placeId)
            hapticManager.notification(.success)
            dismiss()
        } catch let apiError as APIError {
            await authService.refreshMerchantBillingStateFromServer(force: true)
            Self.openPaywallIfCommerceQuotaBlocked(
                apiError,
                authService: authService,
                pendingCommerceName: establishmentName
            )
                errorMessage = userFacingCreateCommerceError(apiError)
        } catch {
            errorMessage = "Impossible de créer le commerce. Vérifiez votre connexion."
        }
    }

    /// Création principale (lieu Google + nom), puis repli `POST /api/businesses` si l’API renvoie 404 (route absente / ancien proxy).
    private func performCreateCommerce(establishmentName: String, placeId: String) async throws {
        do {
            let response = try await APIClient.shared.request(
                .createBusinessFromPlace(establishmentName: establishmentName, googlePlaceId: placeId)
            ) as CreateBusinessFromPlaceResponse
            await finalizeAfterCommerceCreated(
                responseSlug: response.slug,
                responseName: response.name,
                responseOrganizationName: response.organizationName,
                responseDashboardToken: response.dashboardToken,
                businessesFromResponse: response.businesses,
                fallbackDisplayName: establishmentName
            )
        } catch let api as APIError {
            if api.isHTTPResourceMissing {
                let classic = try await createCommerceViaClassicEndpoint(name: establishmentName)
                await finalizeAfterCommerceCreated(
                    responseSlug: classic.slug,
                    responseName: classic.name,
                    responseOrganizationName: classic.organizationName,
                    responseDashboardToken: classic.dashboardToken,
                    businessesFromResponse: nil,
                    fallbackDisplayName: establishmentName
                )
                return
            }
            throw api
        }
    }

    /// Met à jour la session locale puis synchronise en arrière-plan (évite rafales `/me` + sync qui provoquaient des 401 / refresh concurrents).
    private func finalizeAfterCommerceCreated(
        responseSlug: String?,
        responseName: String?,
        responseOrganizationName: String?,
        responseDashboardToken: String?,
        businessesFromResponse: [BusinessDTO]?,
        fallbackDisplayName: String
    ) async {
        authService.finishBusinessSwitch()
        authService.applyImmediateBusinessesFromCreationIfNeeded(businessesFromResponse)

        let nameCandidates: [String?] = [responseName, responseOrganizationName, Optional(fallbackDisplayName)]
        let trimmedNames: [String] = nameCandidates.compactMap { opt in
            opt?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let displayResolved = trimmedNames.first(where: { !$0.isEmpty }) ?? "Commerce"
        let tokenTrimmed: String? = {
            guard let raw = responseDashboardToken?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
            return raw
        }()

        if let slug = responseSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty {
            authService.ensurePendingCreatedBusinessVisibleLocally(
                slug: slug,
                displayName: displayResolved,
                dashboardToken: tokenTrimmed
            )
            authService.selectBusiness(slug: slug, showSwitchingOverlay: false)
        }
        await authService.refreshBusinessesIfNeeded(force: true)

        authService.finishBusinessSwitch()

        // Sync hors du chemin critique : une erreur réseau/auth ici ne doit pas annuler la création réussie.
        Task { @MainActor in
            await syncService.syncAfterServerMutation()
        }
    }

    private func establishmentName(from rawDescription: String) -> String {
        let mainText: String = {
            let parts = rawDescription.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard let head = parts.first else { return rawDescription }
            let trimmed = String(head).trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? rawDescription : trimmed
        }()
        return mainText.isEmpty ? rawDescription : mainText
    }

    private static func openPaywallIfCommerceQuotaBlocked(
        _ error: APIError,
        authService: AuthService,
        pendingCommerceName: String? = nil
    ) {
        switch error {
        case .subscriptionRequired, .businessQuotaReached:
            NotificationCenter.default.postOpenMerchantSubscription(
                usedBusinesses: authService.usedBusinesses,
                allowedBusinesses: authService.allowedBusinesses,
                addingAnotherCommerce: true,
                pendingCommerceName: pendingCommerceName
            )
        default:
            break
        }
    }

    private func userFacingCreateCommerceError(_ error: APIError) -> String {
        switch error {
        case .unauthorized:
            return "Connexion expirée. Fermez cet écran, reconnectez-vous (Apple ou e-mail), puis réessayez."
        case .subscriptionRequired:
            return "Abonnement requis. L’écran de paiement s’ouvre pour choisir le forfait adapté."
        case .businessQuotaReached:
            if authService.merchantScanBenchAccessActive {
                return "Quota serveur pas à jour. Paramètres → Sécurité caisse : vérifiez 102 / 102, Enregistrer, puis réessayez."
            }
            return "Limite de commerces atteinte. L’écran de paiement s’ouvre pour passer au forfait supérieur."
        case .businessPlaceAlreadyLinked(let message):
            return message
        default:
            return error.errorDescription ?? "Impossible de créer le commerce."
        }
    }

    private func createCommerceViaClassicEndpoint(name: String) async throws -> CreateBusinessResponse {
        var baseSlug = Self.slugifyEstablishmentName(name)
        if baseSlug.isEmpty { baseSlug = "commerce" }
        for suffix in 0 ..< 24 {
            let slug: String = {
                if suffix == 0 { return String(baseSlug.prefix(60)) }
                let extra = "-\(suffix)"
                let maxBase = max(1, 60 - extra.count)
                return String(baseSlug.prefix(maxBase)) + extra
            }()
            let payload = CreateBusinessPayload(name: name, slug: slug, organizationName: name)
            do {
                return try await APIClient.shared.request(.createBusiness(payload: payload)) as CreateBusinessResponse
            } catch let api as APIError {
                if case .server(let code, _) = api, code == 409 {
                    continue
                }
                throw api
            }
        }
        throw APIError.server(statusCode: 409, message: "Impossible d’attribuer un identifiant unique au commerce. Réessayez.")
    }

    private static func slugifyEstablishmentName(_ name: String) -> String {
        let folded = name.folding(options: .diacriticInsensitive, locale: Locale(identifier: "fr_FR"))
        let lower = folded.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let replaced = lower.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        let trimmed = replaced.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = trimmed.isEmpty ? "commerce" : trimmed
        return String(base.prefix(48))
    }
}
