//
//  CommerceStatsPaywallGate.swift
//  myfidpass
//
//  Voile paywall sans `.blur` (coûteux pendant le scroll vertical).
//

import SwiftUI

extension View {
    /// Masque le contenu Pro derrière un voile léger + bouton déverrouillage (pas de flou dynamique).
    func commerceStatsPaywallGated(
        locked: Bool,
        glassOverlayMode: Bool,
        accessibilityUnlockLabel: String,
        onUnlock: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
                .opacity(locked ? 0.38 : 1)
                .allowsHitTesting(!locked)

            if locked {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(glassOverlayMode ? 0.74 : 0.82))
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
