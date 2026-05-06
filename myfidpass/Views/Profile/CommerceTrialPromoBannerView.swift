//
//  CommerceTrialPromoBannerView.swift
//  myfidpass
//
//  Bandeau promo essai — uniquement onglet Commerce : même lecture que la pastille flottante (1 € / temps restant),
//  format compact mais lisible, fond sombre quasi-noir avec halo bleu nuit au centre, compteur en rouge urgence,
//  CTA pilule blanche assumée. Typographie SF Pro (design système).
//

import SwiftUI

struct CommerceTrialPromoBannerView: View {
    let trialEndsAt: Date
    var onSubscribe: () -> Void

    /// Halo bleu nuit subtil au centre, posé sur un fond quasi-noir. Évite l’effet « carte grise » précédent.
    private static let centerGlow = RadialGradient(
        colors: [
            Color(red: 22 / 255, green: 32 / 255, blue: 48 / 255).opacity(0.95),
            Color(red: 10 / 255, green: 12 / 255, blue: 16 / 255),
            Color(red: 4 / 255, green: 5 / 255, blue: 7 / 255),
        ],
        center: .center,
        startRadius: 10,
        endRadius: 320
    )

    /// Voile linéaire diagonal par-dessus, très légèrement bleuté en haut-gauche pour donner de la profondeur.
    private static let diagonalOverlay = LinearGradient(
        colors: [
            Color(red: 16 / 255, green: 22 / 255, blue: 34 / 255).opacity(0.55),
            Color.clear,
            Color(red: 2 / 255, green: 3 / 255, blue: 5 / 255).opacity(0.35),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Rouge urgence pour le compteur de temps restant.
    private static let urgencyRed = Color(red: 255 / 255, green: 72 / 255, blue: 79 / 255)

    private static func bannerFont(_ size: CGFloat, weight: Font.Weight) -> Font {
        Font.system(size: size, weight: weight, design: .default)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            banner(now: context.date)
        }
    }

    private func banner(now: Date) -> some View {
        let remaining = MerchantTrialSubscribePillView.remainingLabel(until: trialEndsAt, now: now)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Profitez du premier mois à 1€")
                .font(Self.bannerFont(17, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            (
                Text("Plus que ")
                    .font(Self.bannerFont(13, weight: .medium))
                    .foregroundColor(.white.opacity(0.78))
                    + Text(remaining)
                    .font(Self.bannerFont(13, weight: .semibold))
                    .foregroundColor(Self.urgencyRed)
            )
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onSubscribe) {
                Text("Sélectionner un forfait")
                    .font(Self.bannerFont(15, weight: .bold))
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.10))
                    .tracking(0.2)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.6)
                    )
            }
            .buttonStyle(CommercePromoCTAButtonStyle())
            .padding(.top, 6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Self.centerGlow)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Self.diagonalOverlay)
                        .blendMode(.plusLighter)
                        .opacity(0.55)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.02),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profitez du premier mois à 1 euro. Plus que \(remaining). Sélectionner un forfait.")
    }
}

private struct CommercePromoCTAButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

#Preview {
    CommerceTrialPromoBannerView(trialEndsAt: Date().addingTimeInterval(3600 * 22)) {}
        .padding()
        .background(Color(.systemGroupedBackground))
}
