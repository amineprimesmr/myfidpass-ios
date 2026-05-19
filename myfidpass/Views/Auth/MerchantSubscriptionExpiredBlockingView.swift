//
//  MerchantSubscriptionExpiredBlockingView.swift
//  myfidpass
//
//  Essai gratuit terminé sans abonnement : blocage visuel, CTA vers la page de paiement SaaS.
//

import SwiftUI

/// Date indicative affichée avant tout paiement : fin du 1er mois à 1 € (+1 mois calendaire).
private func merchantPromoCoverageEndDisplayString() -> String {
    let end = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
    let f = DateFormatter()
    f.locale = Locale(identifier: "fr_FR")
    f.calendar = Calendar.current
    f.dateFormat = "dd/MM/yyyy"
    return f.string(from: end)
}

struct MerchantSubscriptionExpiredBlockingView: View {
    let businessName: String
    var onOpenSettings: () -> Void
    var onContinueToPayment: () -> Void

    private var coverageLine: String {
        let d = merchantPromoCoverageEndDisplayString()
        return "Payez 1 € puis profitez de Myfidpass jusqu’au \(d)."
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.02, green: 0.02, blue: 0.03)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.92))
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(.white.opacity(0.12)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Réglages")

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accueil")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                                .textCase(.uppercase)
                            Text(businessName)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, max(8, geo.safeAreaInsets.top > 0 ? 4 : 8))
                    .padding(.bottom, 20)

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Reprenez vos activités pour 1 €")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(coverageLine)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Sans engagement, annulez à tout moment.")
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.white.opacity(0.55))

                        MerchantSubscriptionLegalDisclosureView(isAnnualPlan: nil, compact: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22)

                    Spacer(minLength: 24)

                    Button(action: onContinueToPayment) {
                        Text("Continuer")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 22)
                    .padding(.bottom, max(28, geo.safeAreaInsets.bottom + 16))
                    .accessibilityLabel("Continuer vers le paiement")
                }
            }
        }
        .allowsHitTesting(true)
    }
}

#if DEBUG
#Preview {
    MerchantSubscriptionExpiredBlockingView(
        businessName: "Café démo",
        onOpenSettings: {},
        onContinueToPayment: {}
    )
}
#endif
