//
//  CustomMerchantProPaywallView.swift
//  myfidpass
//
//  Paywall PRO maison : frise d’essai (timeline) + formules, prix via StoreKit / RevenueCat.
//

import SwiftUI
import UIKit
import RevenueCat

/// Accent violet (frise d’abonnement type timeline, cohérent avec la page de vente d’icône).
private let paywallAccent = Color(red: 0.60, green: 0.36, blue: 0.99)

private enum PaywallPlanKind {
    case monthly
    case annual
}

private enum PaywallHaptics {
    /// Retour tactile marqué au changement mensuel / annuel.
    static func planToggleChanged() {
        let g = UIImpactFeedbackGenerator(style: .heavy)
        g.prepare()
        g.impactOccurred(intensity: 1.0)
    }
}

struct CustomMerchantProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState
    /// Paywall **bloquant** (après connexion) : pas de bouton fermer.
    var allowsCloseButton: Bool = true
    /// Si non nil : appelé au tap sur « X » ; sinon `dismiss()` seul (ex. feuille modale).
    var onCloseRequested: (() -> Void)? = nil
    /// Espace sous le bord supérieur du contenu (ex. sheet sans tiret : plus d’air avant le titre).
    var headerExtraTopPadding: CGFloat = 4

    @State private var annualPackage: Package?
    @State private var monthlyPackage: Package?
    @State private var selectedPlan: PaywallPlanKind = .monthly
    @State private var loadError: String?
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?
    @State private var animateTimelineBorder = false
    @State private var isCloseButtonRevealed = false

    private let bottomBarClearance: CGFloat = 116
    private var planChangeAnimation: Animation {
        .spring(response: 0.38, dampingFraction: 0.86, blendDuration: 0.12)
    }

    var body: some View {
        ZStack {
            if isLoadingOfferings {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            } else if let loadError {
                VStack(spacing: 16) {
                    Text(loadError)
                        .font(AppTheme.Fonts.subheadline())
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Réessayer") {
                        Task { await loadOfferings() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerBlock
                        subscriptionValueTimeline
                        plansCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomBarClearance)
                }
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
        .task {
            await loadOfferings()
            if !animateTimelineBorder {
                withAnimation(.linear(duration: 4.8).repeatForever(autoreverses: false)) {
                    animateTimelineBorder = true
                }
            }
        }
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
        VStack(alignment: .leading, spacing: 12) {
            if allowsCloseButton, isCloseButtonRevealed {
                HStack {
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
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            headline
        }
        .padding(.top, headerExtraTopPadding)
        .padding(.bottom, 28)
        .animation(.easeOut(duration: 0.32), value: isCloseButtonRevealed)
        .task(id: allowsCloseButton) {
            guard allowsCloseButton else {
                isCloseButtonRevealed = false
                return
            }
            isCloseButtonRevealed = false
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            isCloseButtonRevealed = true
        }
    }

    private var paywallTitleResolved: String {
        if isLoadingOfferings, monthlyPackage == nil, annualPackage == nil {
            return MerchantSubscriptionPricingCopy.paywallTitle
        }
        let line2 = MerchantIAPProductTimeline.paywallSecondHeadlineLine(
            monthly: monthlyPackage?.storeProduct,
            annual: annualPackage?.storeProduct
        )
        return MerchantSubscriptionPricingCopy.paywallTitleLine1 + "\n" + line2
    }

    private var headline: some View {
        Text(paywallTitleResolved)
            .foregroundStyle(.white)
            .font(AppTheme.Fonts.title())
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Frise verticale (accès app → abonnement App Store)

    private var subscriptionValueTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            paywallTimelineRow(
                isLast: false,
                title: {
                    Text(timelineStep1Title)
                        .font(timelineTitleFont)
                        .foregroundStyle(.white)
                        .contentTransition(.interpolate)
                        .animation(planChangeAnimation, value: selectedPlan)
                },
                subtitle: timelineStep1Subtitle
            )
            paywallTimelineRow(
                isLast: false,
                title: { timelineStep2TitleText },
                subtitle: timelineStep2Subtitle
            )
            paywallTimelineRow(
                isLast: true,
                title: {
                    Text("Toujours – Sans engagement, annulable à tout moment")
                        .font(timelineTitleFont)
                        .foregroundStyle(.white)
                },
                subtitle: nil
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(minHeight: 312, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [paywallAccent.opacity(0.12), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(animatedTimelineBorder)
        .padding(.bottom, 28)
    }

    private var animatedTimelineBorder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.16, green: 0.17, blue: 0.20),
                            Color(red: 0.45, green: 0.30, blue: 1.00),
                            Color(red: 0.22, green: 0.58, blue: 1.00),
                            Color(red: 0.20, green: 0.22, blue: 0.28),
                            Color(red: 0.63, green: 0.36, blue: 1.00),
                            Color(red: 0.30, green: 0.72, blue: 1.00),
                            Color(red: 0.14, green: 0.16, blue: 0.22),
                            Color(red: 0.45, green: 0.30, blue: 1.00)
                        ]),
                        center: .center,
                        angle: .degrees(animateTimelineBorder ? 360 : 0)
                    ),
                    lineWidth: 2.2
                )
                .shadow(color: Color(red: 0.50, green: 0.38, blue: 1.00).opacity(0.55), radius: 7, y: 0)
                .blendMode(.plusLighter)
        }
    }

    private var timelineTitleFont: Font { AppTheme.Fonts.headline() }
    private var timelineSubtitleColor: Color { Color.white.opacity(0.52) }

    private var timelineStep1Title: String {
        MerchantSubscriptionPricingCopy.appAccessStepTitle
    }

    private var timelineStep1Subtitle: String {
        MerchantSubscriptionPricingCopy.appAccessStepDetail
    }

    @ViewBuilder
    private var timelineStep2TitleText: some View {
        Text(
            MerchantIAPProductTimeline.paywallStep2Title(
                monthly: monthlyPackage?.storeProduct,
                annual: annualPackage?.storeProduct,
                selectedIsAnnual: selectedPlan == .annual
            )
        )
        .font(timelineTitleFont)
        .foregroundStyle(.white)
        .contentTransition(.interpolate)
        .animation(planChangeAnimation, value: selectedPlan)
    }

    private var timelineStep2Subtitle: String? {
        MerchantIAPProductTimeline.paywallStep2Detail(
            monthly: monthlyPackage?.storeProduct,
            annual: annualPackage?.storeProduct,
            selectedIsAnnual: selectedPlan == .annual
        )
    }

    private func referenceTwelveMonthRackString(monthly: Package, annual: Package) -> String? {
        let mP = monthly.storeProduct
        let aP = annual.storeProduct
        let twelve = mP.price * Decimal(12)
        guard twelve > aP.price, twelve > 0 else { return nil }
        // Indicatif 12 mois au tarif mensuel (pas d’API `priceFormatStyle` sur l’abstraction RC).
        return "12× \(mP.localizedPriceString) / an"
    }

    private struct PaywallDottedVLine: View {
        var color: Color
        var height: CGFloat
        var body: some View {
            Canvas { context, size in
                var p = Path()
                p.move(to: CGPoint(x: size.width * 0.5, y: 0))
                p.addLine(to: CGPoint(x: size.width * 0.5, y: size.height))
                context.stroke(
                    p,
                    with: .color(color),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4])
                )
            }
            .frame(width: 20, height: height)
        }
    }

    private func paywallTimelineRow<Title: View>(
        isLast: Bool,
        @ViewBuilder title: () -> Title,
        subtitle: String?
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(paywallAccent)
                        .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                        .font(.system(.caption2, design: .default, weight: .bold))
                        .foregroundStyle(.white)
                }
                if !isLast {
                    PaywallDottedVLine(color: paywallAccent.opacity(0.88), height: 42)
                }
            }
            .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                title()
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppTheme.Fonts.subheadline())
                        .foregroundStyle(timelineSubtitleColor)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.interpolate)
                }
            }
            .animation(planChangeAnimation, value: selectedPlan)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, isLast ? 0 : 28)
    }

    // MARK: - Formules (défaut mensuel + toggle annuel)

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: 18) {
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 0)
    }

    // MARK: - Toggle forfait annuel
    private var annualPlanBinding: Binding<Bool> {
        Binding(
            get: { selectedPlan == .annual },
            set: { isAnnual in
                PaywallHaptics.planToggleChanged()
                withAnimation(planChangeAnimation) {
                    selectedPlan = isAnnual ? .annual : .monthly
                }
            }
        )
    }

    @ViewBuilder
    private var annualPlanTogglePillSavingsOrPrice: some View {
        if selectedPlan == .annual {
            Group {
                if let p = annualPackage?.storeProduct {
                    Text("\(p.localizedPriceString) / an")
                } else {
                    Text("— / an")
                }
            }
            .font(AppTheme.Fonts.caption().weight(.semibold))
            .foregroundStyle(.black)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.08))
            )
        } else if let s = savingsPercent, s > 0 {
            Text("-\(s)%")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .monospacedDigit()
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.12))
                )
        }
    }

    private var annualPlanTogglePill: some View {
        HStack(alignment: .center, spacing: 8) {
            Text("Forfait annuel")
                .font(AppTheme.Fonts.headline())
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.88)
                .layoutPriority(1)

            annualPlanTogglePillSavingsOrPrice
                .contentTransition(.interpolate)
                .animation(planChangeAnimation, value: selectedPlan)

            Spacer(minLength: 4)

            Toggle("", isOn: annualPlanBinding)
                .labelsHidden()
                .tint(.black)
                .scaleEffect(0.92)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 320, alignment: .leading)
        .modifier(AnnualPlanPillGlassCompatModifier())
        .accessibilityElement(children: .combine)
    }

    private var savingsPercent: Int? {
        guard let annual = annualPackage?.storeProduct,
              let monthly = monthlyPackage?.storeProduct
        else { return nil }
        return Self.percentSavingsAnnualVsMonthly(annualPrice: annual.price, monthlyPrice: monthly.price)
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchaseSelectedPlan() }
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
                        .contentTransition(.interpolate)
                        .animation(planChangeAnimation, value: selectedPlan)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(selectedPackage == nil || isPurchasing)
        .opacity(selectedPackage == nil ? 0.55 : 1)
    }

    private var stickyBottomPurchaseBar: some View {
        VStack(spacing: 0) {
            if annualPackage != nil, monthlyPackage != nil {
                annualPlanTogglePill
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 40)
            }
            purchaseButton
            legalRow
                .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.top, 0)
        .padding(.bottom, 8)
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly: monthlyPackage
        case .annual: annualPackage
        }
    }

    // MARK: - Pied de page légal / restaurer

    private var legalRow: some View {
        HStack(alignment: .center, spacing: 12) {
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

            Spacer(minLength: 6)

            Text("Annulable à tout moment")
                .font(AppTheme.Fonts.caption().weight(.medium))
                .foregroundStyle(Color.black.opacity(0.62))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .tint(Color.black.opacity(0.78))
        .padding(.horizontal, 2)
        .padding(.bottom, 6)
    }

    // MARK: - RevenueCat

    @MainActor
    private func loadOfferings() async {
        isLoadingOfferings = true
        loadError = nil
        defer { isLoadingOfferings = false }

        guard Purchases.isConfigured else {
            loadError = "Les abonnements App Store ne sont pas encore disponibles sur cet appareil. Utilise l’abonnement via site web en attendant."
            annualPackage = nil
            monthlyPackage = nil
            return
        }

        do {
            let offerings = try await Purchases.shared.offerings()
            let current = offerings.current
            let annual = current?.annual
                ?? current?.package(identifier: "$rc_annual")
                ?? current?.availablePackages.first(where: { $0.packageType == .annual })

            let monthly = current?.monthly
                ?? current?.package(identifier: "$rc_monthly")
                ?? current?.availablePackages.first(where: { $0.packageType == .monthly })

            if annual == nil && monthly == nil {
                loadError = "Aucun abonnement trouvé. Ajoute les packages mensuel et annuel à l’offre « current » dans RevenueCat, puis synchronise avec App Store Connect."
                annualPackage = nil
                monthlyPackage = nil
                return
            }

            annualPackage = annual
            monthlyPackage = monthly

            if annual != nil, monthly != nil {
                selectedPlan = .monthly
            } else if annual != nil {
                selectedPlan = .annual
            } else {
                selectedPlan = .monthly
            }
        } catch {
            loadError = error.localizedDescription
            annualPackage = nil
            monthlyPackage = nil
        }
    }

    @MainActor
    private func purchaseSelectedPlan() async {
        guard let pkg = selectedPackage else { return }
        guard Purchases.isConfigured else {
            purchaseError = "Les achats App Store sont temporairement indisponibles."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        purchaseError = nil

        do {
            let result = try await Purchases.shared.purchase(package: pkg)
            if result.userCancelled { return }
            await revenueCatSubscriptionState.refreshCustomerInfo()
            await self.authService.syncRevenueCatSubscriptionWithServerAfterPurchase()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    @MainActor
    private func restorePurchases() async {
        guard Purchases.isConfigured else {
            purchaseError = "Les achats App Store sont temporairement indisponibles."
            return
        }
        isRestoring = true
        defer { isRestoring = false }
        do {
            _ = try await Purchases.shared.restorePurchases()
            await revenueCatSubscriptionState.refreshCustomerInfo()
            await self.authService.syncRevenueCatSubscriptionWithServerAfterPurchase()
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Formatage

    private static func percentSavingsAnnualVsMonthly(annualPrice: Decimal, monthlyPrice: Decimal) -> Int? {
        let twelve: Decimal = 12
        let yearIfMonthly = monthlyPrice * twelve
        guard yearIfMonthly > 0, yearIfMonthly > annualPrice else { return nil }
        let ratio = (yearIfMonthly - annualPrice) / yearIfMonthly
        let n = NSDecimalNumber(decimal: ratio)
        return Int((n.doubleValue * 100).rounded())
    }

    private func frenchPeriodPhrase(_ period: SubscriptionPeriod) -> String {
        MerchantIAPProductTimeline.frenchPeriodPhrase(period)
    }

    private func frenchAfterTrialPhrase(_ period: SubscriptionPeriod) -> String {
        frenchPeriodPhrase(period)
    }
}

/// Forfait annuel : verre **décoratif** (pas `buttonStyle(.glass)` = pas d’effet « bouton système » cliquable).
/// Variante `.clear` : le plus transparent ; les couleurs du fond passent derrière (doc Apple « Applying Liquid Glass »).
/// Rayon très grand = capsule (arrondi max sur la pastille).
private struct AnnualPlanPillGlassCompatModifier: ViewModifier {
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
        .environmentObject(RevenueCatSubscriptionState())
}
