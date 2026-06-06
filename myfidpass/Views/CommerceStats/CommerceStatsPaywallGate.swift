//
//  CommerceStatsPaywallGate.swift
//  myfidpass
//
//  Voile paywall avec flou léger (compositingGroup pour limiter le coût repaint).
//

import SwiftUI

extension View {
    /// Masque le contenu Pro derrière un flou + voile + bouton déverrouillage.
    func commerceStatsPaywallGated(
        locked: Bool,
        glassOverlayMode: Bool,
        accessibilityUnlockLabel: String,
        onUnlock: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
                .compositingGroup()
                .blur(radius: locked ? 7 : 0, opaque: false)
                .opacity(locked ? 0.42 : 1)
                .allowsHitTesting(!locked)

            if locked {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(glassOverlayMode ? 0.58 : 0.68))
                    .allowsHitTesting(false)

                MerchantProUnlockTeaserButton(preferDarkGlassTint: glassOverlayMode) {
                    onUnlock()
                }
                .accessibilityLabel(accessibilityUnlockLabel)
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
