//
//  PaywallBevelDesign.swift
//  myfidpass
//
//  Composants visuels paywall style Bevel (fond clair, features défilantes, cartes forfait).
//

import SwiftUI

// MARK: - Modèle feature

struct PaywallFeatureItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let symbolColors: [Color]
    /// Image asset catalogue (ex. `AppleWalletAppIcon`, `GoogleGLogo`) — prioritaire sur `symbol`.
    let assetName: String?
    /// Coins arrondis pour les assets (ex. icône Apple Wallet).
    let assetCornerRadius: CGFloat?

    init(
        id: String,
        title: String,
        subtitle: String,
        symbol: String,
        symbolColors: [Color],
        assetName: String? = nil,
        assetCornerRadius: CGFloat? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.symbolColors = symbolColors
        self.assetName = assetName
        self.assetCornerRadius = assetCornerRadius
    }
}

// MARK: - Fond blanc + dégradé pastel (Bevel)

struct PaywallBevelBackdrop: View {
    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.99, blue: 1.0)
            RadialGradient(
                colors: [
                    Color(red: 0.90, green: 0.95, blue: 1.0).opacity(0.42),
                    Color(red: 0.96, green: 0.98, blue: 1.0).opacity(0.22),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.45, y: 0.38),
                startRadius: 20,
                endRadius: 420
            )
            RadialGradient(
                colors: [
                    Color(red: 0.94, green: 0.96, blue: 0.99).opacity(0.28),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.88, y: 0.42),
                startRadius: 8,
                endRadius: 280
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Ligne feature

struct PaywallBevelFeatureRow: View {
    let item: PaywallFeatureItem

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Group {
                if let assetName = item.assetName, !assetName.isEmpty {
                    Image(assetName)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(
                            width: (item.assetCornerRadius ?? 0) > 0 ? 32 : 28,
                            height: (item.assetCornerRadius ?? 0) > 0 ? 32 : 28
                        )
                        .clipShape(
                            RoundedRectangle(
                                cornerRadius: item.assetCornerRadius ?? 0,
                                style: .continuous
                            )
                        )
                } else {
                    Image(systemName: item.symbol)
                        .font(.system(size: 24, weight: .semibold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(item.symbolColors.first ?? .blue, item.symbolColors.last ?? .cyan)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.11))
                    .multilineTextAlignment(.leading)
                Text(item.subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.50))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
    }
}

struct PaywallBevelAlsoIncludesDivider: View {
    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
            Text("inclut également")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color(red: 0.55, green: 0.57, blue: 0.60))
                .textCase(.lowercase)
                .fixedSize()
            Rectangle()
                .fill(Color.black.opacity(0.08))
                .frame(height: 1)
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Défilement vertical (auto + manuel, boucle fluide sans saut)

struct PaywallBevelAutoScrollingFeatures: View {
    let primary: [PaywallFeatureItem]
    let alsoIncluded: [PaywallFeatureItem]

    private let pixelsPerSecond: CGFloat = 16

    @State private var measuredBlockHeight: CGFloat = 0
    /// Position de référence figée au début d’un drag ou après relâchement.
    @State private var baseOffset: CGFloat = 0
    @State private var autoAnchor = Date()
    @State private var isUserDragging = false
    @State private var dragTranslation: CGFloat = 0

    private var loopBlockHeight: CGFloat {
        max(measuredBlockHeight, 1)
    }

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isUserDragging)) { timeline in
                let block = loopBlockHeight
                let autoDelta: CGFloat = {
                    guard !isUserDragging else { return 0 }
                    let elapsed = timeline.date.timeIntervalSince(autoAnchor)
                    return -CGFloat(elapsed) * pixelsPerSecond
                }()
                let raw = baseOffset + autoDelta + (isUserDragging ? dragTranslation : 0)
                let displayOffset = loopOffset(raw, block: block)

                VStack(spacing: 0) {
                    featureStack
                    featureStack
                    featureStack
                }
                .offset(y: displayOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .contentShape(Rectangle())
            .simultaneousGesture(manualScrollGesture)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.06),
                        .init(color: .black, location: 0.96),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var manualScrollGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                let block = loopBlockHeight
                if !isUserDragging {
                    let elapsed = Date().timeIntervalSince(autoAnchor)
                    baseOffset = loopOffset(baseOffset - CGFloat(elapsed) * pixelsPerSecond, block: block)
                    autoAnchor = Date()
                    isUserDragging = true
                }
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let block = loopBlockHeight
                baseOffset = loopOffset(baseOffset + value.translation.height, block: block)
                dragTranslation = 0
                autoAnchor = Date()
                isUserDragging = false
            }
    }

    /// Ramène l’offset dans ]-block, 0] pour une boucle visuellement continue.
    private func loopOffset(_ raw: CGFloat, block: CGFloat) -> CGFloat {
        guard block > 0 else { return raw }
        var value = raw.truncatingRemainder(dividingBy: block)
        if value > 0 { value -= block }
        return value
    }

    @ViewBuilder
    private var featureStack: some View {
        VStack(spacing: 0) {
            ForEach(primary) { PaywallBevelFeatureRow(item: $0) }
            if !alsoIncluded.isEmpty {
                PaywallBevelAlsoIncludesDivider()
                ForEach(alsoIncluded) { PaywallBevelFeatureRow(item: $0) }
            }
        }
        .padding(.horizontal, 22)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: PaywallFeatureBlockHeightKey.self, value: proxy.size.height)
            }
        }
        .onPreferenceChange(PaywallFeatureBlockHeightKey.self) { height in
            guard height > 0, abs(height - measuredBlockHeight) > 0.5 else { return }
            measuredBlockHeight = height
        }
    }
}

private struct PaywallFeatureBlockHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Carte forfait

struct PaywallBevelPlanCard: View {
    let title: String
    let priceLine: String
    let isSelected: Bool
    let savingsBadge: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.11))
                        Spacer(minLength: 0)
                        ZStack {
                            Circle()
                                .strokeBorder(
                                    isSelected ? Color.clear : Color.black.opacity(0.18),
                                    lineWidth: 1.5
                                )
                                .frame(width: 22, height: 22)
                            if isSelected {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    Text(priceLine)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(red: 0.45, green: 0.47, blue: 0.50))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(isSelected ? 0.10 : 0.05), radius: isSelected ? 14 : 8, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.black : Color.black.opacity(0.10),
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                if let savingsBadge, isSelected {
                    Text(savingsBadge)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black))
                        .offset(y: -11)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bouton Continuer

struct PaywallBevelContinueButton: View {
    let title: String
    let isLoading: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(isEnabled ? 1 : 0.35))
                    .shadow(
                        color: Color(red: 0.55, green: 0.78, blue: 0.95).opacity(isEnabled ? 0.45 : 0),
                        radius: 18,
                        y: 10
                    )
            )
        }
        .buttonStyle(PaywallBevelPressStyle())
        .disabled(!isEnabled || isLoading)
    }
}

private struct PaywallBevelPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

// MARK: - Features MyFidpass

enum PaywallBevelFeatureCatalog {
    static let primary: [PaywallFeatureItem] = [
        PaywallFeatureItem(
            id: "wallet",
            title: "Carte Apple & Google Wallet",
            subtitle: "Distribuez une carte fidélité sur iPhone et Android.",
            symbol: "wallet.pass.fill",
            symbolColors: [Color(red: 0.98, green: 0.45, blue: 0.38), Color(red: 1.0, green: 0.72, blue: 0.55)],
            assetName: "AppleWalletAppIcon",
            assetCornerRadius: 8
        ),
        PaywallFeatureItem(
            id: "notifs",
            title: "Notifications push illimitées",
            subtitle: "Relancez vos clients au bon moment, sans limite.",
            symbol: "bell.badge.fill",
            symbolColors: [Color(red: 0.98, green: 0.34, blue: 0.42), Color(red: 1.0, green: 0.62, blue: 0.58)]
        ),
        PaywallFeatureItem(
            id: "stats",
            title: "Statistiques détaillées",
            subtitle: "Suivez l’activité et la croissance de votre commerce.",
            symbol: "chart.xyaxis.line",
            symbolColors: [Color(red: 0.28, green: 0.62, blue: 0.98), Color(red: 0.52, green: 0.82, blue: 1.0)]
        ),
        PaywallFeatureItem(
            id: "clients",
            title: "Base clients centralisée",
            subtitle: "Retrouvez l’historique et les préférences de chaque membre.",
            symbol: "person.3.fill",
            symbolColors: [Color(red: 0.42, green: 0.48, blue: 0.98), Color(red: 0.68, green: 0.72, blue: 1.0)]
        ),
        PaywallFeatureItem(
            id: "google-reviews",
            title: "Avis Google boosté",
            subtitle: "Encouragez les avis Google Business après chaque visite.",
            symbol: "star.bubble.fill",
            symbolColors: [Color(red: 0.95, green: 0.55, blue: 0.18), Color(red: 0.28, green: 0.78, blue: 0.62)],
            assetName: "GoogleGLogo"
        ),
        PaywallFeatureItem(
            id: "x-engagement",
            title: "Engagement X boosté",
            subtitle: "Récompensez un follow sur votre compte X.",
            symbol: "xmark",
            symbolColors: [Color.black, Color.black],
            assetName: "SocialX",
            assetCornerRadius: 8
        ),
        PaywallFeatureItem(
            id: "rewards",
            title: "Récompenses illimitées",
            subtitle: "Fidélisez sans plafond sur vos offres.",
            symbol: "gift.fill",
            symbolColors: [Color(red: 0.95, green: 0.55, blue: 0.18), Color(red: 1.0, green: 0.78, blue: 0.42)]
        ),
    ]

    static let alsoIncluded: [PaywallFeatureItem] = []
}

