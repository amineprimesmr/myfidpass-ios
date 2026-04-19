//
//  CustomMerchantProPaywallView.swift
//  myfidpass
//
//  Paywall PRO maison : 1 mois offert puis 49,99 €/mois ou 399 €/an (prix réels via StoreKit / RevenueCat).
//

import SwiftUI
import RevenueCat

/// Accent vert « néon » proche de la maquette.
private let paywallAccentGreen = Color(red: 0.25, green: 0.98, blue: 0.42)

private enum PaywallPlanKind {
    case monthly
    case annual
}

struct CustomMerchantProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var revenueCatSubscriptionState: RevenueCatSubscriptionState
    /// Si non nil : appelé au tap sur « X » (ex. paywall racine post-inscription) ; sinon `dismiss()` seul.
    var onCloseRequested: (() -> Void)? = nil

    @State private var annualPackage: Package?
    @State private var monthlyPackage: Package?
    @State private var selectedPlan: PaywallPlanKind = .annual
    @State private var loadError: String?
    @State private var isLoadingOfferings = true
    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var purchaseError: String?
    @State private var legalSafariURL: URL?

    private let bottomBarClearance: CGFloat = 88

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoadingOfferings {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
            } else if let loadError {
                VStack(spacing: 16) {
                    Text(loadError)
                        .font(.subheadline)
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
                        featureTable
                        plansCard
                        legalRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, bottomBarClearance)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadOfferings()
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
            ZStack {
                Text("Choisissez votre formule PRO")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.45))

                HStack {
                    Button {
                        if let onCloseRequested {
                            onCloseRequested()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.top, 4)

            headline
        }
        .padding(.bottom, 28)
    }

    private var headline: some View {
        (Text("COMMENCEZ VOTRE ")
            .foregroundStyle(.white)
         + Text(trialGreenPhrase)
            .foregroundStyle(paywallAccentGreen)
         + Text(" !")
            .foregroundStyle(.white))
        .font(.system(size: 26, weight: .heavy))
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Texte vert du titre : aligné sur l’offre d’essai StoreKit (cible : 1 mois gratuit).
    private var trialGreenPhrase: String {
        guard let intro = primaryFreeTrialIntro else {
            return "1 MOIS OFFERT"
        }
        let p = intro.subscriptionPeriod
        if p.unit == .month, p.value == 1 { return "1 MOIS OFFERT" }
        switch (p.unit, p.value) {
        case (.day, 7): return "7 JOURS OFFERTS"
        case (.week, 1): return "1 SEMAINE OFFERTE"
        case (.day, 1): return "1 JOUR OFFERT"
        case (.day, let d) where d > 1: return "\(d) JOURS OFFERTS"
        default:
            return "ESSAI · \(frenchPeriodPhrase(p).uppercased())"
        }
    }

    /// Premier essai gratuit trouvé sur les produits chargés (mensuel / annuel).
    private var primaryFreeTrialIntro: StoreProductDiscount? {
        for p in [monthlyPackage?.storeProduct, annualPackage?.storeProduct].compactMap({ $0 }) {
            if let d = p.introductoryDiscount, d.paymentMode == .freeTrial { return d }
        }
        return nil
    }

    // MARK: - Tableau comparatif

    private var featureTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("GRATUIT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .frame(width: 72)
                Text("PRO")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(paywallAccentGreen)
                    .frame(width: 72)
            }
            .padding(.bottom, 14)

            ForEach(Array(featureRows.enumerated()), id: \.offset) { _, row in
                featureRow(title: row.title, free: row.free, pro: row.pro)
            }
        }
        .padding(.bottom, 28)
    }

    private var featureRows: [(title: String, free: Bool, pro: Bool)] {
        [
            ("Accompagnement dédié", false, true),
            ("Statistiques avancées", false, true),
            ("Carte fidélité & campagnes PRO", false, true),
            ("Sans publicité", false, true),
            ("Accès hors ligne", true, true),
        ]
    }

    private func featureRow(title: String, free: Bool, pro: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                checkCell(on: free, activeColor: Color.white.opacity(0.35))
                    .frame(width: 72)
                checkCell(on: pro, activeColor: paywallAccentGreen)
                    .frame(width: 72)
            }
            .padding(.vertical, 12)

            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
        }
    }

    private func checkCell(on: Bool, activeColor: Color) -> some View {
        Group {
            if on {
                Image(systemName: "checkmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(activeColor)
            } else {
                Color.clear.frame(width: 15, height: 15)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formules (mensuel + annuel)

    private var plansCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(sharedTrialLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let monthlyPackage {
                planOptionRow(
                    title: "Mensuel",
                    subtitle: "Renouvellement chaque mois après l’essai",
                    priceLine: "\(monthlyPackage.storeProduct.localizedPriceString) / mois",
                    badge: nil,
                    selected: selectedPlan == .monthly
                ) {
                    selectedPlan = .monthly
                }
            }

            if let annualPackage {
                planOptionRow(
                    title: "Annuel",
                    subtitle: "Une facture par an après l’essai",
                    priceLine: "\(annualPackage.storeProduct.localizedPriceString) / an",
                    badge: savingsPercent.map { "Économisez \($0) %" },
                    selected: selectedPlan == .annual
                ) {
                    selectedPlan = .annual
                }
            }

            purchaseButton
                .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
        )
        .padding(.bottom, 20)
    }

    private var sharedTrialLine: String {
        if let intro = primaryFreeTrialIntro {
            let durée = frenchPeriodPhrase(intro.subscriptionPeriod)
            return "Inclus : \(durée) gratuit sans payer, puis le tarif de l’option choisie (annulable avant la fin de l’essai)."
        }
        return "Inclus : 1 mois offert sans payer, puis le tarif de l’option choisie (annulable avant la fin de l’essai)."
    }

    private var savingsPercent: Int? {
        guard let annual = annualPackage?.storeProduct,
              let monthly = monthlyPackage?.storeProduct
        else { return nil }
        return Self.percentSavingsAnnualVsMonthly(annualPrice: annual.price, monthlyPrice: monthly.price)
    }

    private func planOptionRow(
        title: String,
        subtitle: String,
        priceLine: String,
        badge: String?,
        selected: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.black)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(paywallAccentGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(paywallAccentGreen.opacity(0.16))
                                )
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(priceLine)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.black)
                }
                Spacer(minLength: 8)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 26))
                    .foregroundStyle(selected ? paywallAccentGreen : Color.black.opacity(0.22))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? paywallAccentGreen : Color.black.opacity(0.08), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            Task { await purchaseSelectedPlan() }
        } label: {
            ZStack {
                Capsule(style: .continuous)
                    .fill(Color.black)

                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(paywallAccentGreen)
                            .frame(width: 10, height: 10)
                            .shadow(color: paywallAccentGreen.opacity(0.85), radius: 6, y: 0)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("LANCER MON ESSAI GRATUIT")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundStyle(.white)
                            Text(ctaSubtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
        }
        .buttonStyle(.plain)
        .disabled(selectedPackage == nil || isPurchasing)
        .opacity(selectedPackage == nil ? 0.55 : 1)
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .monthly: monthlyPackage
        case .annual: annualPackage
        }
    }

    private var ctaSubtitle: String {
        guard let pkg = selectedPackage else { return "" }
        let price = pkg.storeProduct.localizedPriceString
        let unit = selectedPlan == .annual ? "an" : "mois"
        if let intro = pkg.storeProduct.introductoryDiscount, intro.paymentMode == .freeTrial {
            let after = frenchAfterTrialPhrase(intro.subscriptionPeriod)
            return "après \(after), \(price) / \(unit)"
        }
        return "puis \(price) / \(unit)"
    }

    // MARK: - Pied de page légal / restaurer

    private var legalRow: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Button("Restaurer les achats") {
                    Task { await restorePurchases() }
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.55))
                .disabled(isRestoring || isPurchasing)

                if isRestoring {
                    ProgressView()
                        .scaleEffect(0.85)
                        .tint(.white.opacity(0.6))
                }
            }

            HStack(spacing: 16) {
                Button("Conditions d’utilisation") {
                    legalSafariURL = LegalURLs.termsOfUse
                }
                Button("Confidentialité") {
                    legalSafariURL = LegalURLs.privacyPolicy
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
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

            if annual != nil {
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
        switch period.unit {
        case .day:
            return period.value == 1 ? "1 jour" : "\(period.value) jours"
        case .week:
            return period.value == 1 ? "1 semaine" : "\(period.value) semaines"
        case .month:
            return period.value == 1 ? "1 mois" : "\(period.value) mois"
        case .year:
            return period.value == 1 ? "1 an" : "\(period.value) ans"
        @unknown default:
            return "1 mois"
        }
    }

    private func frenchAfterTrialPhrase(_ period: SubscriptionPeriod) -> String {
        frenchPeriodPhrase(period)
    }
}

#Preview {
    CustomMerchantProPaywallView()
        .environmentObject(RevenueCatSubscriptionState())
}
