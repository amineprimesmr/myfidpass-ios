//
//  CustomMerchantProPaywallView.swift
//  myfidpass
//
//  Paywall PRO maison : frise d’essai + souscription via **myfidpass.fr/paiement** (Stripe embarqué, pas d’IAP).
//

import SwiftUI
import UIKit

/// Accent violet (frise d’abonnement type timeline, cohérent avec la page de vente d’icône).
private let paywallAccent = Color(red: 0.60, green: 0.36, blue: 0.99)

/// Pastilles forfait (remise annuelle / prix mensuel) — verts doux, lisibles sur fond « verre ».
private enum PaywallPlanBadgeStyle {
    static let discountFill = Color(red: 0.86, green: 0.96, blue: 0.90)
    static let discountStroke = Color(red: 0.58, green: 0.82, blue: 0.68).opacity(0.85)
    static let discountText = Color(red: 0.08, green: 0.38, blue: 0.26)
    static let monthlyGradTop = Color(red: 0.14, green: 0.58, blue: 0.42)
    static let monthlyGradBottom = Color(red: 0.08, green: 0.42, blue: 0.52)
}

/// Espacement du rail vertical : hauteur du pointillé + marge inter-étape ≈ distance entre deux pastilles.
private enum PaywallTimelineMetrics {
    /// Longueur du segment sous un badge (remplace l’ancien 22 + le vide du padding inter-ligne).
    static let connectorToNextBadge: CGFloat = 48
    static let stepBottomPadding: CGFloat = 4
}

private enum PaywallHaptics {
    /// Retour tactile au changement mensuel / annuel Stripe.
    static func planToggleChanged() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare()
        g.impactOccurred(intensity: 1.0)
    }
}

struct CustomMerchantProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    /// Paywall **bloquant** (après connexion) : pas de bouton fermer.
    var allowsCloseButton: Bool = true
    /// Si non nil : appelé au tap sur « X » ; sinon `dismiss()` seul (ex. feuille modale).
    var onCloseRequested: (() -> Void)? = nil
    /// Espace sous le bord supérieur du contenu (ex. sheet sans tiret : plus d’air avant le titre).
    var headerExtraTopPadding: CGFloat = 4
    /// Délai avant d’afficher la croix (évite fermeture immédiate en feuille). Paywall **obligatoire** en essai : `0`.
    var closeButtonRevealDelay: TimeInterval = 5

    /// `false` = cycle **annuel** Stripe (défaut), `true` = **mensuel**. S’applique au compte (1 commerce) ou au commerce actif (2+).
    @State private var planSecondaryOptionEnabled: Bool = false
    @State private var isPurchasing = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?
    @State private var isCloseButtonRevealed = false

    private let bottomBarClearance: CGFloat = 116
    private var planChangeAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.12)
    }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerBlock
                    subscriptionValueTimeline
                }
                .padding(.horizontal, 20)
                .padding(.bottom, bottomBarClearance)
            }
        }
        .background {
            GeometryReader { proxy in
                Image("paypage")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            stickyBottomPurchaseBar
        }
        .preferredColorScheme(.dark)
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
    }

    // MARK: - Header

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(MerchantSubscriptionPricingCopy.paywallTitleLine1)
                    .font(.system(.largeTitle, design: .default, weight: .heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if allowsCloseButton, isCloseButtonRevealed {
                    Button {
                        if let onCloseRequested {
                            onCloseRequested()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(minWidth: 32, minHeight: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Fermer")
                }
            }
            if !MerchantSubscriptionPricingCopy.paywallUnderTitleLine.isEmpty {
                Text(MerchantSubscriptionPricingCopy.paywallUnderTitleLine)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, headerExtraTopPadding)
        .padding(.bottom, 20)
        .animation(.easeOut(duration: 0.32), value: isCloseButtonRevealed)
        .task(id: "\(allowsCloseButton)-\(closeButtonRevealDelay)") {
            guard allowsCloseButton else {
                isCloseButtonRevealed = false
                return
            }
            isCloseButtonRevealed = false
            let nanos = UInt64(max(0, closeButtonRevealDelay) * 1_000_000_000)
            if nanos > 0 {
                try? await Task.sleep(nanoseconds: nanos)
            }
            isCloseButtonRevealed = true
        }
    }

    // MARK: - Frise verticale (style timeline)

    private var subscriptionValueTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 1 — étape passée
            paywallTimelineStep(
                style: .completed,
                title: MerchantSubscriptionPricingCopy.paywallTimelineCompletedTitle,
                subtitle: MerchantSubscriptionPricingCopy.paywallTimelineCompletedDetail,
                connectorBelow: PaywallTimelineMetrics.connectorToNextBadge
            )
            // 2 — étape actuelle
            paywallTimelineStep(
                style: .current,
                title: {
                    Text(MerchantSubscriptionPricingCopy.paywallTimelineTodayStepTitle)
                        .font(AppTheme.Fonts.headline())
                        .foregroundStyle(.white)
                },
                subtitle: paywallTimelineTodayStepSubtitleLine,
                connectorBelow: PaywallTimelineMetrics.connectorToNextBadge
            )
            // 3 — bénéfice produit
            paywallTimelineStep(
                style: .upcoming(icon: "bell"),
                title: MerchantSubscriptionPricingCopy.paywallTimelineReminderTitle,
                subtitle: MerchantSubscriptionPricingCopy.paywallTimelineReminderDetail.isEmpty
                    ? nil
                    : MerchantSubscriptionPricingCopy.paywallTimelineReminderDetail,
                connectorBelow: PaywallTimelineMetrics.connectorToNextBadge
            )
            // 4 — fin accès
            paywallTimelineStep(
                style: .end(icon: "heart"),
                title: MerchantSubscriptionPricingCopy.paywallTimelineEndTitle,
                subtitle: paywallTimelineEndSubtitle,
                connectorBelow: 0,
                isLast: true
            )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .padding(.top, 6)
        .padding(.bottom, 28)
    }

    private var paywallTimelineEndSubtitle: String {
        paywallRecurringEngagementLine
    }

    /// Date indicative de fin du premier mois à 1 € (calendrier +1 mois à partir d’aujourd’hui, avant achat).
    private var paywallTodayStepPromoEndDateDisplay: String {
        let end = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.calendar = Calendar.current
        // Jour + mois en toutes lettres, sans année (ex. « 2 juin »).
        f.dateFormat = "d MMMM"
        return f.string(from: end)
    }

    /// Sous-titre sous « Aujourd’hui : Payez 1 € » (1 phrase + date).
    private var paywallTimelineTodayStepSubtitleLine: String {
        "Débloquez l’accès complet jusqu’au \(paywallTodayStepPromoEndDateDisplay)."
    }

    /// « Puis … » — formulation générique ; les montants exacts sont sur Stripe Checkout.
    private var paywallRecurringEngagementLine: String {
        if isMultiCommerceAccount {
            return planSecondaryOptionEnabled
                ? "Puis abonnement mensuel par commerce (Stripe), annulable à tout moment."
                : "Puis abonnement annuel par commerce (Stripe), annulable à tout moment."
        }
        return planSecondaryOptionEnabled
            ? "Puis tarif mensuel sur Stripe, annulable à tout moment."
            : "Puis tarif annuel sur Stripe, annulable à tout moment."
    }

    private enum PaywallTimelineNodeStyle {
        case completed
        case current
        case upcoming(icon: String)
        case end(icon: String)
    }

    @ViewBuilder
    private func paywallTimelineNode(style: PaywallTimelineNodeStyle) -> some View {
        switch style {
        case .completed:
            ZStack {
                Circle()
                    .fill(paywallAccent)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(Color.white.opacity(0.26), lineWidth: 1)
                    .frame(width: 28, height: 28)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40, alignment: .center)
        case .current:
            ZStack {
                Circle()
                    .stroke(paywallAccent.opacity(0.55), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Circle()
                    .fill(paywallAccent.opacity(0.22))
                    .frame(width: 30, height: 30)
                Image(systemName: "lock.open")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40, alignment: .center)
        case .upcoming(let icon), .end(let icon):
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 40, height: 40)
                Circle()
                    .stroke(paywallAccent.opacity(0.28), lineWidth: 1.2)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundStyle(Color.white.opacity(0.94))
            }
            .frame(width: 40, height: 40, alignment: .center)
        }
    }

    private struct PaywallTimelineVLine: View {
        var height: CGFloat
        var body: some View {
            let h = max(height, 0)
            ZStack {
                // Tirets verticaux + dégradé vers transparent (reliant les pastilles de la frise).
                Path { p in
                    p.move(to: CGPoint(x: 5.5, y: 0))
                    p.addLine(to: CGPoint(x: 5.5, y: h))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            paywallAccent.opacity(0.6),
                            paywallAccent.opacity(0.32),
                            paywallAccent.opacity(0.1),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(
                        lineWidth: 1.7,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: [3.5, 6.5]
                    )
                )
                // Léger liseré clair sur les tirets (lisible sur fond sombre / image).
                Path { p in
                    p.move(to: CGPoint(x: 5.5, y: 0))
                    p.addLine(to: CGPoint(x: 5.5, y: h))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.14),
                            Color.white.opacity(0.04),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(
                        lineWidth: 0.9,
                        lineCap: .round,
                        dash: [3.5, 6.5]
                    )
                )
            }
            .frame(width: 11, height: h, alignment: .top)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func paywallTimelineStep<Title: View>(
        style: PaywallTimelineNodeStyle,
        @ViewBuilder title: () -> Title,
        subtitle: String? = nil,
        connectorBelow: CGFloat,
        isLast: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Spacer(minLength: 0)
                    paywallTimelineNode(style: style)
                    Spacer(minLength: 0)
                }
                if connectorBelow > 0 {
                    PaywallTimelineVLine(height: connectorBelow)
                }
            }
            .frame(width: 40, alignment: .top)

            VStack(alignment: .leading, spacing: 0) {
                title()
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.Fonts.subheadline())
                        .foregroundStyle(Color.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                        .contentTransition(.interpolate)
                        .animation(.easeInOut(duration: 0.28), value: subtitle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 10)
        }
        .padding(.bottom, isLast ? 0 : PaywallTimelineMetrics.stepBottomPadding)
    }

    private func paywallTimelineStep(
        style: PaywallTimelineNodeStyle,
        title: String,
        subtitle: String? = nil,
        connectorBelow: CGFloat,
        isLast: Bool = false
    ) -> some View {
        paywallTimelineStep(style: style, title: {
            switch style {
            case .completed:
                Text(title)
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(paywallAccent)
                    .strikethrough(true, color: paywallAccent.opacity(0.7))
            case .current, .upcoming(_), .end(_):
                Text(title)
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(.white)
            }
        }, subtitle: subtitle, connectorBelow: connectorBelow, isLast: isLast)
    }

    // MARK: - Stripe (forfaits)

    /// Nombre de commerces à couvrir (1…5), aligné compte + API.
    private func desiredCommerceSlotTarget() -> Int {
        let n = max(authService.usedBusinesses, authService.businesses.count)
        return min(5, max(1, n))
    }

    /// **≥ 2** → Stripe Checkout par commerce actif ; **1** → Checkout sur abonnement compte (`create-checkout-session`).
    private var isMultiCommerceAccount: Bool {
        desiredCommerceSlotTarget() >= 2
    }

    private var planChannelPrimaryLabel: String {
        planSecondaryOptionEnabled ? "Mensuel · Stripe" : "Annuel · Stripe"
    }

    private var planSecondaryOptionBinding: Binding<Bool> {
        Binding(
            get: { planSecondaryOptionEnabled },
            set: { isOn in
                PaywallHaptics.planToggleChanged()
                withAnimation(planChangeAnimation) {
                    planSecondaryOptionEnabled = isOn
                }
            }
        )
    }

    /// Pastille « -33 % » — vert menthe discret.
    private var paywallAnnualDiscountMintBadge: some View {
        Text("-33%")
            .font(AppTheme.Fonts.caption().weight(.semibold))
            .foregroundStyle(PaywallPlanBadgeStyle.discountText)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(PaywallPlanBadgeStyle.discountFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(PaywallPlanBadgeStyle.discountStroke, lineWidth: 1)
            )
    }

    /// Pastille prix mensuel — dégradé vert / bleu-vert, texte blanc.
    private func paywallMonthlyPricePremiumBadge(priceLine: String) -> some View {
        Text(priceLine)
            .font(AppTheme.Fonts.caption().weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .monospacedDigit()
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PaywallPlanBadgeStyle.monthlyGradTop, PaywallPlanBadgeStyle.monthlyGradBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .shadow(color: PaywallPlanBadgeStyle.monthlyGradTop.opacity(0.35), radius: 4, y: 2)
    }

    private var multiCommerceMonthlyPriceLine: String {
        "34,99 € / mois"
    }

    @ViewBuilder
    private var planChannelTogglePillTrailingCapsule: some View {
        if isMultiCommerceAccount {
            if planSecondaryOptionEnabled {
                paywallMonthlyPricePremiumBadge(priceLine: multiCommerceMonthlyPriceLine)
            } else {
                paywallAnnualDiscountMintBadge
            }
        } else if planSecondaryOptionEnabled {
            paywallMonthlyPricePremiumBadge(priceLine: "À partir du tarif mensuel")
        } else {
            paywallAnnualDiscountMintBadge
        }
    }

    private var planChannelTogglePill: some View {
        Button {
            planSecondaryOptionBinding.wrappedValue.toggle()
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Text(planChannelPrimaryLabel)
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)
                    .layoutPriority(1)

                planChannelTogglePillTrailingCapsule
                    .contentTransition(.interpolate)
                    .animation(planChangeAnimation, value: planSecondaryOptionEnabled)
                    .animation(planChangeAnimation, value: isMultiCommerceAccount)

                Spacer(minLength: 4)

                Toggle("", isOn: .constant(planSecondaryOptionEnabled))
                    .labelsHidden()
                    .tint(.black)
                    .scaleEffect(0.92)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: 320, alignment: .leading)
            .modifier(PlanChannelPillGlassCompatModifier())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var purchaseButton: some View {
        Button {
            Task {
                if isMultiCommerceAccount {
                    await purchasePerBusinessStripeCheckout()
                } else {
                    await purchaseAccountStripeCheckout()
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black)
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(MerchantSubscriptionPricingCopy.purchaseCta)
                        .font(AppTheme.Fonts.headline())
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }

    private var stickyBottomPurchaseBar: some View {
        VStack(spacing: 0) {
            planChannelTogglePill
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 40)
            purchaseButton
            legalRow
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    // MARK: - Pied de page légal

    private var legalRow: some View {
        HStack(spacing: 10) {
            Button("Confidentialité") {
                legalSafariURL = LegalURLs.privacyPolicy
            }
            Text("|")
                .foregroundStyle(Color.black.opacity(0.35))
            Button("Conditions") {
                legalSafariURL = LegalURLs.termsOfUse
            }
        }
        .font(AppTheme.Fonts.caption().weight(.medium))
        .foregroundStyle(Color.black.opacity(0.72))
        .frame(maxWidth: .infinity, alignment: .center)
        .tint(Color.black.opacity(0.78))
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
    }

    // MARK: - Stripe Checkout

    @MainActor
    private func purchaseAccountStripeCheckout() async {
        let billingPlan = planSecondaryOptionEnabled ? "monthly" : "annual"
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseError = nil
        do {
            let response: CheckoutSessionResponse = try await APIClient.shared.request(
                .paymentCheckout(plan: billingPlan),
                responseType: CheckoutSessionResponse.self
            )
            let urlString = response.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let url = URL(string: urlString), !urlString.isEmpty else {
                purchaseError = "Impossible d’ouvrir la page de paiement Stripe."
                return
            }
            _ = await UIApplication.shared.open(url)
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    @MainActor
    private func purchasePerBusinessStripeCheckout() async {
        let slug = (AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                    ? AuthStorage.currentBusinessSlug
                    : authService.businesses.first?.slug)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !slug.isEmpty else {
            purchaseError = "Aucun commerce actif. Sélectionnez un commerce puis réessayez."
            return
        }
        let interval = planSecondaryOptionEnabled ? "month" : "year"
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseError = nil
        do {
            let response: CheckoutSessionResponse = try await APIClient.shared.request(
                .paymentBusinessCheckoutSession(businessSlug: slug, interval: interval),
                responseType: CheckoutSessionResponse.self
            )
            let urlString = response.url?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let url = URL(string: urlString), !urlString.isEmpty else {
                purchaseError = "Impossible d’ouvrir la page de paiement pour ce commerce."
                return
            }
            _ = await UIApplication.shared.open(url)
        } catch {
            purchaseError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Pastille bascule forfait : verre **décoratif** (pas `buttonStyle(.glass)` sur le `Toggle` système).
private struct PlanChannelPillGlassCompatModifier: ViewModifier {
    private static let pillCornerRadius: CGFloat = 999

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.clear, cornerRadius: Self.pillCornerRadius)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule(style: .continuous))
                .clipShape(Capsule(style: .continuous))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.42), Color.white.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.9
                        )
                )
                .shadow(color: Color.white.opacity(0.08), radius: 6, y: 2)
        }
    }
}

#Preview {
    CustomMerchantProPaywallView()
        .environmentObject(AuthService())
}
