//
//  CommerceTopBarView.swift
//  myfidpass
//
//  Barre noire Commerce (avatar / nom / QR / réglages) — partagée entre l’onglet Commerce et le paywall bloquant.
//

import SwiftUI

struct CommerceTopBarView: View {
    var organizationDisplayName: String
    var settings: BusinessSettingsResponse?
    var onQR: () -> Void
    var onSettings: () -> Void

    private var notificationIconURL: String? {
        let t = settings?.notificationIconUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !t.isEmpty else { return nil }
        guard let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines), !slug.isEmpty else { return nil }
        let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let enc = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        return "\(base)/api/businesses/\(enc)/notification-icon"
    }

    private var storeInitials: String {
        let source = organizationDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty { return "Mb" }
        let words = source.split(separator: " ").prefix(2)
        let letters = words.compactMap { $0.first }.map(String.init).joined()
        return letters.isEmpty ? "Mb" : letters
    }

    @ViewBuilder
    private var leadingAvatar: some View {
        if let url = notificationIconURL {
            BusinessLogoView(
                logoURL: url,
                logoAssetContext: .campaignNotificationIcon,
                size: 34,
                cornerRadius: 10
            )
            .id(settings?.notificationIconUpdatedAt ?? "notification-icon")
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.green.opacity(0.9))
                .frame(width: 34, height: 34)
                .overlay {
                    Text(storeInitials)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.9))
                }
        }
    }

    var body: some View {
        let title = organizationDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        HStack(spacing: 12) {
            leadingAvatar
            Text(title.isEmpty ? "Ma boutique" : title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer(minLength: 6)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onQR()
            } label: {
                Image(systemName: "qrcode")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
            .accessibilityLabel("Afficher le QR code de la page fidélité")
            Button {
                onSettings()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(.white)
            }
            .modifier(TopBarLiquidGlassButtonModifier())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background {
            Color.black
                .ignoresSafeArea(edges: .top)
        }
    }
}
