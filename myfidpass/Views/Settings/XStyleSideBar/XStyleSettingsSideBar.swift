//
//  XStyleSettingsSideBar.swift
//  myfidpass
//
//  Panneau latéral style X — profil commerçant + navigation.
//

import SwiftUI

struct XStyleSettingsSideBar: View {
    @EnvironmentObject private var authService: AuthService

    @Binding var isExpanded: Bool
    @Binding var path: NavigationPath

    var notificationIconURL: String?
    var hasNotificationIcon: Bool = false
    var onOpenFlyer: () -> Void
    var onOpenFootballGame: () -> Void
    var onOpenLiveGame: () -> Void

    @State private var showsFlyerCreationAttention = false

    private static let businessAvatarSize: CGFloat = 60

    private var displayName: String {
        if let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines),
           let biz = authService.businesses.first(where: { $0.slug == slug }) {
            let org = biz.organizationName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !org.isEmpty { return org }
            let n = biz.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { return n }
            return biz.slug
        }
        let email = (AuthStorage.userEmail ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !email.isEmpty { return email.components(separatedBy: "@").first ?? email }
        return "Mon commerce"
    }

    private var commerceCountLabel: String {
        "\(authService.businesses.count)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            profileAvatar
                .padding(.bottom, 10)

            Text(displayName)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(2)

            HStack(spacing: 2) {
                Text(commerceCountLabel)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                Text(authService.businesses.count == 1 ? "commerce" : "commerces")
                    .foregroundStyle(.white.opacity(0.62))
            }
            .font(.callout)
            .fontWeight(.medium)
            .padding(.top, 5)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 30) {
                    sideMenuButton(
                        icon: "doc.richtext",
                        title: "Flyer de jeu",
                        showsAttentionDot: showsFlyerCreationAttention,
                        dismissMenuOnTap: false
                    ) {
                        onOpenFlyer()
                    }

                    sideMenuButton(icon: "soccerball", title: "Jeu de foot", dismissMenuOnTap: false) {
                        onOpenFootballGame()
                    }

                    sideMenuButton(icon: "play.circle", title: "Jeu en direct", showsTrailingArrow: true, dismissMenuOnTap: false) {
                        onOpenLiveGame()
                    }

                    sideMenuButton(icon: "gearshape", title: "Paramètres") {
                        path.appendAnimated(SettingsSideRoute.settings)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 20)
            }
            .mask {
                Rectangle()
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                Divider()
                    .background(.white.opacity(0.22))
                    .padding(.horizontal, -15)
            }
            .padding(.top, 15)
            .scrollClipDisabled()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding([.horizontal, .top], 15)
        .background(Color.black)
        .onAppear { refreshFlyerCreationAttention() }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassMerchantSetupProgressUpdated)) { _ in
            refreshFlyerCreationAttention()
        }
        .onReceive(NotificationCenter.default.publisher(for: .myfidpassCardPreviewDisplayDidChange)) { _ in
            refreshFlyerCreationAttention()
        }
    }

    private func refreshFlyerCreationAttention() {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !slug.isEmpty else {
            showsFlyerCreationAttention = false
            return
        }
        CommerceFlyerStore.shared.hydrateFromDiskIfNeeded(slug: slug)
        showsFlyerCreationAttention = PostCardFlyerPromoEligibility.showsCreationAttentionBadge(for: slug)
    }

    @ViewBuilder
    private var profileAvatar: some View {
        sidebarBusinessAvatar(size: Self.businessAvatarSize)
    }

    @ViewBuilder
    private func sidebarBusinessAvatar(size: CGFloat) -> some View {
        let appIconShape = RoundedRectangle(cornerRadius: max(10, size * 0.28), style: .continuous)
        let icon = notificationIconURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if hasNotificationIcon, !icon.isEmpty {
            BusinessLogoView(
                logoURL: icon,
                logoAssetContext: .campaignNotificationIcon,
                size: size,
                cornerRadius: max(10, size * 0.28)
            )
            .clipShape(appIconShape)
        } else {
            sidebarBusinessAvatarFallback(size: size)
        }
    }

    private func sidebarBusinessAvatarFallback(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(10, size * 0.28), style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.16, blue: 0.45), Color(red: 0.41, green: 0.12, blue: 0.55)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: "storefront.fill")
                    .font(.system(size: max(13, size * 0.34), weight: .semibold))
                    .foregroundStyle(.white.opacity(0.95))
            }
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func sideMenuButton(
        icon: String,
        title: String,
        showsAttentionDot: Bool = false,
        showsTrailingArrow: Bool = false,
        dismissMenuOnTap: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if dismissMenuOnTap {
                isExpanded = false
            }
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.title3)
                    .frame(width: 30)
                    .symbolVariant(.fill)

                HStack(spacing: 8) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    if showsAttentionDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)
                    }
                }

                if showsTrailingArrow {
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.bold))
                }
            }
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            showsAttentionDot ? "\(title), à créer" : title
        )
    }
}
