//
//  MerchantProUnlockTeaserSheet.swift
//  myfidpass
//
//  Teaser Pro (1 €) avant le paywall — remplace l’alerte / bannière rouge abonnement.
//

import SwiftUI

struct MerchantProUnlockTeaserSheet: View {
    var onContinue: () -> Void
    var onLater: () -> Void

    @State private var heroPulse = false
    @State private var featuresVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.primary.opacity(0.18))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 18)

            hero

            VStack(spacing: 8) {
                Text("Débloquez toutes les fonctionnalités")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(MerchantSubscriptionPricingCopy.paywallPricingIntroLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)

                Text("Scan caisse, points, campagnes et automatisations — sans limite.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 22)
            .padding(.top, 6)

            featureList
                .padding(.horizontal, 22)
                .padding(.top, 20)
                .opacity(featuresVisible ? 1 : 0)
                .offset(y: featuresVisible ? 0 : 12)

            Spacer(minLength: 16)

            VStack(spacing: 10) {
                Button(action: onContinue) {
                    Text(MerchantSubscriptionPricingCopy.paywallContinueCta)
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AppTheme.Colors.primary)

                Button(action: onLater) {
                    Text("Plus tard")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Text(MerchantSubscriptionPricingCopy.paywallNoCommitmentHighlight)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                heroPulse = true
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(0.12)) {
                featuresVisible = true
            }
        }
    }

    private var hero: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.Colors.primary.opacity(heroPulse ? 0.35 : 0.18),
                            AppTheme.Colors.primary.opacity(0.02),
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: heroPulse ? 72 : 56
                    )
                )
                .frame(width: 120, height: 120)

            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.Colors.primary, AppTheme.Colors.primary.opacity(0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse.byLayer, options: .repeating)
        }
        .frame(height: 130)
        .accessibilityHidden(true)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("qrcode.viewfinder", "Scan & passage en caisse")
            featureRow("bell.badge.fill", "Campagnes et notifications")
            featureRow("chart.line.uptrend.xyaxis", "Statistiques détaillées")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.primary)
                .frame(width: 28)
            Text(title)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 0)
            Image(systemName: "checkmark.circle.fill")
                .font(.body)
                .foregroundStyle(AppTheme.Colors.primary.opacity(0.85))
        }
    }
}

#Preview {
    MerchantProUnlockTeaserSheet(onContinue: {}, onLater: {})
}
