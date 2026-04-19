//
//  MerchantFreemiumBannerView.swift
//  myfidpass
//
//  Bandeau mode découverte : accès à la configuration sans abonnement ; scan / campagnes / crédit points réservés à l’offre active.
//

import SwiftUI

struct MerchantFreemiumBannerView: View {
    var onSubscribe: () -> Void
    /// Resynchronise avec Stripe + `/me` si l’abonnement est payé mais pas encore reflété.
    var onPaidRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onSubscribe) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mode découverte")
                            .font(.subheadline.weight(.semibold))
                        Text("Après les 24 h d’essai gratuit (accès complet), scan, points et campagnes nécessitent un abonnement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mode découverte. Souscrire pour utiliser scan, points et campagnes.")

            Button(action: onPaidRefresh) {
                Text("J’ai déjà payé — actualiser")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AppTheme.Colors.primary)
            .accessibilityLabel("Actualiser l’abonnement après un paiement déjà effectué")
        }
    }
}

#Preview {
    MerchantFreemiumBannerView(onSubscribe: {}, onPaidRefresh: {})
        .padding()
}
