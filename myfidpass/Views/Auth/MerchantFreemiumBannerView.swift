//
//  MerchantFreemiumBannerView.swift
//  myfidpass
//
//  Bandeau mode découverte : accès à la configuration sans abonnement ; scan / campagnes / crédit points réservés à l’offre active.
//

import SwiftUI

struct MerchantFreemiumBannerView: View {
    var onSubscribe: () -> Void

    var body: some View {
        Button(action: onSubscribe) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.primary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mode découverte")
                        .font(.subheadline.weight(.semibold))
                    Text("Configurez tout ; scan, points et campagnes après abonnement.")
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
    }
}

#Preview {
    MerchantFreemiumBannerView(onSubscribe: {})
        .padding()
}
