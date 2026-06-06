//
//  MerchantScanSheetStyle.swift
//  myfidpass
//
//  Chrome partagé des écrans scan caisse plein écran (tampon, récompense).
//

import SwiftUI
import UIKit

enum MerchantScanSheetTheme {
    static let slideHeight: CGFloat = 72
}

struct MerchantScanSheetTopChrome {
    var primary: Color { .white }
    var secondary: Color { Color.white.opacity(0.55) }
    var glassStroke: Color { Color.white.opacity(0.22) }
}

enum MerchantScanSheetCopy {
    static func memberFirstName(from fullName: String) -> String {
        let raw = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Client" }
        return raw.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? raw
    }
}

func merchantScanHeaderTopInset(from geo: GeometryProxy) -> CGFloat {
    let g = geo.safeAreaInsets.top
    if g >= 12 { return g }
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let win = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
        return max(g, win.safeAreaInsets.top)
    }
    return max(g, 47)
}

func merchantScanSanitizeDimension(_ x: CGFloat) -> CGFloat {
    guard x.isFinite, x > 0 else { return 1 }
    return x
}

func merchantScanDarkRadialBackground(width: CGFloat, height: CGFloat) -> some View {
    let dim = max(width, height)
    let endR = dim * 1.02
    let startR = dim * 0.06
    return ZStack {
        Color(red: 0.005, green: 0.007, blue: 0.012)
        RadialGradient(
            colors: [
                Color(red: 0.09, green: 0.095, blue: 0.13),
                Color(red: 0.055, green: 0.058, blue: 0.078),
                Color(red: 0.032, green: 0.035, blue: 0.048),
                Color(red: 0.018, green: 0.02, blue: 0.032),
                Color(red: 0.01, green: 0.012, blue: 0.022),
                Color(red: 0.004, green: 0.006, blue: 0.014)
            ],
            center: UnitPoint(x: 0.5, y: 0.08),
            startRadius: startR,
            endRadius: endR
        )
        RadialGradient(
            colors: [
                Color(red: 0.16, green: 0.168, blue: 0.215),
                Color(red: 0.07, green: 0.075, blue: 0.095),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.035),
            startRadius: 4,
            endRadius: dim * 0.52
        )
        .blendMode(.plusLighter)
        .opacity(0.32)
    }
}

extension View {
    func merchantScanFullScreenChrome() -> some View {
        preferredColorScheme(.dark)
    }
}

/// En-tête écran scan : prénom, sous-titre, retour.
struct MerchantScanSheetHeaderBar: View {
    let title: String
    let subtitle: String
    let onDismiss: () -> Void
    var chrome: MerchantScanSheetTopChrome = MerchantScanSheetTopChrome()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dismissButton

            VStack(spacing: 5) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(chrome.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(subtitle)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundStyle(chrome.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)

            Color.clear
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var dismissButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(chrome.primary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass(.regular))
            .buttonBorderShape(.circle)
            .accessibilityLabel("Retour")
        } else {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(chrome.primary)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Circle()
                                    .strokeBorder(chrome.glassStroke, lineWidth: 1)
                            }
                    }
            }
            .accessibilityLabel("Retour")
        }
    }
}

/// Bloc récompense doré (tampon ou validation récompense).
struct MerchantScanRewardHero: View {
    let leadLine: String
    let rewardLabel: String
    var emphasizeLead: Bool = false
    var chrome: MerchantScanSheetTopChrome = MerchantScanSheetTopChrome()

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Text(leadLine)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(emphasizeLead ? chrome.primary.opacity(0.95) : chrome.secondary)
                .multilineTextAlignment(.center)
            Text(rewardLabel)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1, green: 0.96, blue: 0.78),
                            Color(red: 0.98, green: 0.82, blue: 0.38)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.72)
                .lineLimit(3)
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.white.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }
}
