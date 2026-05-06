//
//  FlyerPreviewDepthChrome.swift
//  myfidpass
//
//  Cadre aperçu flyer : léger bord, reflet discret, ombre simple.
//

import SwiftUI

enum FlyerPreviewChromeVariant {
    case hub
    case commerceCard
    case fullscreen
}

struct FlyerPreviewDepthChrome: ViewModifier {
    var cornerRadius: CGFloat
    var variant: FlyerPreviewChromeVariant
    var plateColor: Color

    @Environment(\.colorScheme) private var colorScheme

    private var isDarkContext: Bool {
        switch variant {
        case .hub, .fullscreen: return true
        case .commerceCard: return colorScheme == .dark
        }
    }

    private var rimGradient: LinearGradient {
        if isDarkContext {
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.22),
                    Color.white.opacity(0.05),
                    Color.black.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                Color.white.opacity(0.36),
                Color.white.opacity(0.08),
                Color.black.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var sheenOpacity: Double { isDarkContext ? 0.1 : 0.08 }

    private var ambientShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        switch variant {
        case .hub:
            return (Color.black.opacity(0.38), 24, 12)
        case .commerceCard:
            return (Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), 22, 10)
        case .fullscreen:
            return (Color.black.opacity(0.48), 28, 14)
        }
    }

    private var contactShadow: (color: Color, radius: CGFloat, y: CGFloat) {
        (Color.black.opacity(0.18), 5, 3)
    }

    func body(content: Content) -> some View {
        let amb = ambientShadow
        let ct = contactShadow
        return content
            .background(plateColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(sheenOpacity),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: UnitPoint(x: 0.5, y: 0.42)
                        )
                    )
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(rimGradient, lineWidth: 1)
            }
            .compositingGroup()
            .shadow(color: amb.color, radius: amb.radius, y: amb.y)
            .shadow(color: ct.color, radius: ct.radius, y: ct.y)
    }
}

extension View {
    func flyerPreviewDepthChrome(
        cornerRadius: CGFloat,
        variant: FlyerPreviewChromeVariant,
        plateColor: Color = Color(white: 0.1)
    ) -> some View {
        modifier(
            FlyerPreviewDepthChrome(
                cornerRadius: cornerRadius,
                variant: variant,
                plateColor: plateColor
            )
        )
    }
}
