//
//  CustomMerchantProPaywallView.swift
//  myfidpass
//
//  Paywall PRO — style Bevel (fond clair, features défilantes, cartes Mensuel / Annuel).
//

import StoreKit
import SwiftUI
import UIKit

struct CustomMerchantProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService

    var allowsCloseButton: Bool = true
    var onCloseRequested: (() -> Void)? = nil
    /// Feuille modale (pastille essai, quota) — titre plus haut, zone features un peu plus haute.
    var isSheetPresentation: Bool = false
    var headerExtraTopPadding: CGFloat = 4
    var closeButtonRevealDelay: TimeInterval = 5
    var requiredCommerceSlots: Int? = nil
    /// Contexte post-inscription : nom du commerce sous le titre.
    var signupCommerceDisplayName: String? = nil
    /// Ajout d’un commerce (quota plein).
    var addingAnotherCommerce: Bool = false
    /// Nom du futur commerce (avant paiement).
    var pendingCommerceName: String? = nil

    /// `true` = mensuel, `false` = annuel (défaut annuel comme Bevel).
    @State private var isMonthlyPlanSelected = false
    @State private var selectedTargetSlots: Int = 1
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?
    @State private var isCloseButtonRevealed = false
    @State private var showsPaywallLegalMenu = false
    @State private var measuredTopSafeInset: CGFloat = 0
    @State private var appleIntroOfferAvailable: Bool?
    @State private var didCompletePaywallSuccess = false
    @ObservedObject private var appleStore = MerchantAppleSubscriptionStore.shared

    private var paidSlotsBaseline: Int {
        min(5, max(1, authService.allowedBusinesses))
    }

    private var effectiveCommerceSlots: Int {
        min(5, max(1, selectedTargetSlots))
    }

    private var initialTargetSlots: Int {
        if let requiredCommerceSlots {
            return min(5, max(1, requiredCommerceSlots))
        }
        return MerchantAppleSubscriptionProducts.slotsToPurchase(
            usedBusinesses: authService.usedBusinesses,
            allowedBusinesses: authService.allowedBusinesses,
            addingAnotherCommerce: addingAnotherCommerce
        )
    }

    private var showsCommerceQuotaSection: Bool { true }

    private var pricingUpgradeQuote: MerchantMultiPricing.Quote {
        MerchantMultiPricing.quote(from: paidSlotsBaseline, to: effectiveCommerceSlots)
    }

    private var supportsAnnualPlanToggle: Bool {
        MerchantAppleSubscriptionProducts.supportsAnnualPlan(slots: effectiveCommerceSlots)
    }

    private var introOfferEligibilityTaskKey: String {
        "\(effectiveCommerceSlots)-\(selectedPlanIsAnnual)-\(appleStore.isLoadingProducts)"
    }

    private var selectedPlanIsAnnual: Bool {
        supportsAnnualPlanToggle && !isMonthlyPlanSelected
    }

    private var selectedPlanAvailableOnStore: Bool {
        appleStore.isProductAvailable(slots: effectiveCommerceSlots, annual: selectedPlanIsAnnual)
    }

    private var paywallRootTopPadding: CGFloat {
        if isSheetPresentation {
            return max(0, measuredTopSafeInset * 0.2) + headerExtraTopPadding
        }
        return measuredTopSafeInset + headerExtraTopPadding
    }

    private var titleBlockTopPadding: CGFloat { isSheetPresentation ? 2 : 10 }
    private var titleBlockBottomPadding: CGFloat { isSheetPresentation ? 12 : 22 }
    private var featuresScrollMinHeight: CGFloat { isSheetPresentation ? 272 : 0 }
    private var bottomSectionTopPadding: CGFloat { isSheetPresentation ? 8 : 14 }

    var body: some View {
        ZStack {
            PaywallBevelBackdrop()

            VStack(spacing: 0) {
                topChrome

                titleBlock
                    .padding(.horizontal, 28)
                    .padding(.top, titleBlockTopPadding)
                    .padding(.bottom, titleBlockBottomPadding)

                if showsCommerceQuotaSection {
                    PaywallCommerceQuotaSection(
                        businesses: authService.businessesForMerchantSwitcher,
                        usedBusinesses: authService.usedBusinesses,
                        allowedBusinesses: authService.allowedBusinesses,
                        hasActiveSubscription: authService.hasEncashedMerchantSubscription,
                        addingAnotherCommerce: addingAnotherCommerce,
                        pendingCommerceName: pendingCommerceName ?? signupCommerceDisplayName,
                        selectedTargetSlots: $selectedTargetSlots
                    )
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
                }

                PaywallBevelAutoScrollingFeatures(
                    primary: PaywallBevelFeatureCatalog.primary,
                    alsoIncluded: PaywallBevelFeatureCatalog.alsoIncluded
                )
                .padding(.top, isSheetPresentation ? 0 : 4)
                .padding(.bottom, isSheetPresentation ? 6 : 12)
                .frame(minHeight: featuresScrollMinHeight)
                .frame(maxHeight: .infinity)
                .layoutPriority(isSheetPresentation ? 2 : 1)

                bottomSection
            }
            .padding(.top, paywallRootTopPadding)
        }
        .preferredColorScheme(.light)
        .alert("Achat", isPresented: Binding(
            get: { purchaseError != nil },
            set: { if !$0 { purchaseError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let purchaseError { Text(purchaseError) }
        }
        .sheet(isPresented: Binding(
            get: { legalSafariURL != nil },
            set: { if !$0 { legalSafariURL = nil } }
        )) {
            if let url = legalSafariURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
        .task {
            await appleStore.loadProductsIfNeeded(force: true)
            await refreshAppleIntroOfferAvailability()
        }
        .task(id: introOfferEligibilityTaskKey) {
            await refreshAppleIntroOfferAvailability()
        }
        .onAppear {
            refreshMeasuredTopSafeInset()
            selectedTargetSlots = initialTargetSlots
            isMonthlyPlanSelected = true
        }
        .onChange(of: requiredCommerceSlots) { _, _ in
            selectedTargetSlots = initialTargetSlots
        }
        .onChange(of: addingAnotherCommerce) { _, _ in
            selectedTargetSlots = initialTargetSlots
        }
        .onChange(of: effectiveCommerceSlots) { _, _ in
            if !supportsAnnualPlanToggle {
                isMonthlyPlanSelected = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassAppleStoreTransactionSynced)) { _ in
            Task { await handleBackgroundAppleStoreTransactionSynced() }
        }
        .onChange(of: authService.hasEncashedMerchantSubscription) { _, active in
            guard active, !didCompletePaywallSuccess, !isPurchasing else { return }
            Task { await handleBackgroundAppleStoreTransactionSynced() }
        }
    }

    private func refreshMeasuredTopSafeInset() {
        measuredTopSafeInset = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .windows
            .first(where: { $0.isKeyWindow })?
            .safeAreaInsets.top ?? 0
    }

    // MARK: - Header

    private var topChrome: some View {
        HStack {
            if allowsCloseButton, isCloseButtonRevealed {
                Button {
                    if let onCloseRequested { onCloseRequested() } else { dismiss() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.35))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Fermer")
            } else {
                Color.clear.frame(width: 36, height: 36)
            }

            Spacer(minLength: 0)

            Button { showsPaywallLegalMenu = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options et informations légales")
            .popover(isPresented: $showsPaywallLegalMenu, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                paywallLegalMenuPopover
                    .presentationCompactAdaptation(.popover)
            }
        }
        .padding(.horizontal, 18)
        .animation(.easeOut(duration: 0.32), value: isCloseButtonRevealed)
        .task(id: "\(allowsCloseButton)-\(closeButtonRevealDelay)") {
            guard allowsCloseButton else {
                isCloseButtonRevealed = false
                return
            }
            isCloseButtonRevealed = false
            let nanos = UInt64(max(0, closeButtonRevealDelay) * 1_000_000_000)
            if nanos > 0 { try? await Task.sleep(nanoseconds: nanos) }
            isCloseButtonRevealed = true
        }
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            Text(MerchantSubscriptionPricingCopy.paywallBevelTitle)
                .font(.system(size: 27, weight: .heavy))
                .foregroundStyle(Color(red: 0.06, green: 0.07, blue: 0.09))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)

            if let signupCommerceDisplayName {
                let trimmed = signupCommerceDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    Text(trimmed)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                }
            }
        }
    }

    // MARK: - Bas (CTA)

    private var bottomSection: some View {
        VStack(spacing: 14) {
            Text(paywallPricingIntroLine)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.10, green: 0.11, blue: 0.13))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            PaywallBevelContinueButton(
                title: paywallContinueButtonTitle,
                isLoading: isPurchasing,
                isEnabled: paywallContinueButtonEnabled
            ) {
                Task { await purchaseWithAppStore() }
            }

            Text(paywallFooterCommitmentText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.19, blue: 0.22))

            if !appleStore.isLoadingProducts, !selectedPlanAvailableOnStore {
                Text(appleStore.loadProductsError
                    ?? "Cette offre n’est pas encore disponible sur l’App Store. Réessayez dans quelques minutes.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, isSheetPresentation ? 22 : 28)
        .padding(.top, bottomSectionTopPadding)
    }

    // MARK: - Prix

    private var paywallPricingIntroLine: String {
        "Le premier mois à 1€, puis \(pricingUpgradeQuote.toMonthlyLabel) / mois"
    }

    private var paywallFooterCommitmentText: String {
        "Puis \(pricingUpgradeQuote.toMonthlyLabel)/mois sans engagement"
    }

    private var paywallContinueButtonTitle: String {
        if pricingUpgradeQuote.isUpgrade, authService.hasEncashedMerchantSubscription {
            return "Passer à \(effectiveCommerceSlots) commerces"
        }
        return MerchantSubscriptionPricingCopy.paywallContinueCta
    }

    private var paywallContinueButtonEnabled: Bool {
        selectedPlanAvailableOnStore && !appleStore.isLoadingProducts && !isPurchasing
    }

    @MainActor
    private func refreshAppleIntroOfferAvailability() async {
        guard selectedPlanAvailableOnStore else {
            appleIntroOfferAvailable = nil
            return
        }
        appleIntroOfferAvailable = await appleStore.canPurchaseWithAppleIntroOffer(
            slots: effectiveCommerceSlots,
            annual: selectedPlanIsAnnual
        )
    }

    // MARK: - Menu légal

    private var paywallLegalMenuPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            paywallLegalMenuRow(symbol: "hand.raised", title: "Politique de confidentialité") {
                showsPaywallLegalMenu = false
                legalSafariURL = LegalURLs.privacyPolicy
            }
            paywallLegalMenuRow(symbol: "doc.text", title: "Conditions (EULA)") {
                showsPaywallLegalMenu = false
                legalSafariURL = LegalURLs.termsOfUse
            }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            paywallLegalMenuRow(symbol: "tag", title: "Code promo Apple") {
                showsPaywallLegalMenu = false
                MerchantAppleSubscriptionStore.presentOfferCodeRedemptionSheet()
            }
        }
        .padding(.vertical, 6)
        .frame(minWidth: 248, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func paywallLegalMenuRow(symbol: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.72))
                    .frame(width: 22, alignment: .center)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - StoreKit

    @MainActor
    private func handleBackgroundAppleStoreTransactionSynced() async {
        guard !didCompletePaywallSuccess else { return }
        if let response = appleStore.lastSuccessfulSyncResponse {
            authService.applyAppleSubscriptionSync(response, purchasedSlots: effectiveCommerceSlots)
        }
        _ = await authService.refreshMerchantBillingStateWithRetries()
        if authService.hasEncashedMerchantSubscription {
            await completePaywallAfterSuccessfulPayment()
            return
        }
        if let response = appleStore.lastSuccessfulSyncResponse,
           AuthService.appleSyncResponseGrantsPaidAccess(response) {
            authService.applyAppleSubscriptionSync(response, purchasedSlots: effectiveCommerceSlots)
            await completePaywallAfterSuccessfulPayment()
        }
    }

    @MainActor
    private func completePaywallAfterSuccessfulPayment() async {
        guard !didCompletePaywallSuccess else { return }
        _ = await authService.refreshMerchantBillingStateWithRetries()
        if addingAnotherCommerce || effectiveCommerceSlots > authService.allowedBusinesses {
            authService.applyPostPurchaseQuotaUnlock(minimumSlots: effectiveCommerceSlots)
        }
        let quotaUnlocked = addingAnotherCommerce && authService.canCreateBusiness
        guard authService.hasEncashedMerchantSubscription || quotaUnlocked else { return }
        didCompletePaywallSuccess = true
        if authService.isCompletingSignupPaywallPhase {
            authService.confirmSignupPaywallPaymentInThisSession()
            authService.finishSignupPaywallPhase(honorPaidThankYou: true)
        } else {
            dismiss()
            NotificationCenter.default.post(name: .myfidpassSubscriptionPaymentCompleted, object: nil)
            if addingAnotherCommerce || authService.canCreateBusiness {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    NotificationCenter.default.post(name: .myfidpassOpenAddCommerceSheet, object: nil)
                }
            }
        }
    }

    @MainActor
    private func purchaseWithAppStore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseError = nil
        do {
            let annual = supportsAnnualPlanToggle && !isMonthlyPlanSelected
            let syncResponse = try await appleStore.purchase(slots: effectiveCommerceSlots, annual: annual)
            if await finalizeStoreKitPaymentAfterServerConfirmation(initialSync: syncResponse) {
                await completePaywallAfterSuccessfulPayment()
            }
        } catch MerchantAppleSubscriptionStoreError.userCancelled {
            return
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription
                ?? appleStore.loadProductsError
                ?? error.localizedDescription
        }
        if purchaseError != nil,
           appleIntroOfferAvailable == false,
           appleStore.hasIntroductoryOfferConfigured(slots: effectiveCommerceSlots, annual: selectedPlanIsAnnual) {
            purchaseError = (purchaseError ?? "") + "\n\n" + MerchantSubscriptionPricingCopy.paywallAppleOfferCodeFallbackNote
        }
    }

    /// Valide côté serveur (`GET /me` + cache sync) avant tout « Merci » ou déblocage PRO.
    @MainActor
    private func finalizeStoreKitPaymentAfterServerConfirmation(
        initialSync: PaymentAppleSyncResponse?
    ) async -> Bool {
        if let initialSync {
            authService.applyAppleSubscriptionSync(initialSync, purchasedSlots: effectiveCommerceSlots)
        }
        if authService.hasEncashedMerchantSubscription {
            return true
        }
        let confirmed = await authService.refreshMerchantBillingStateWithRetries()
        if confirmed { return true }
        if let initialSync, AuthService.appleSyncResponseGrantsPaidAccess(initialSync) {
            authService.applyAppleSubscriptionSync(initialSync, purchasedSlots: effectiveCommerceSlots)
            return true
        }
        purchaseError =
                "L’App Store a bien répondu, mais MyFidpass n’a pas confirmé l’abonnement payant. Réessayez dans un instant."
        return false
    }
}

#Preview {
    CustomMerchantProPaywallView()
        .environmentObject(AuthService())
}
