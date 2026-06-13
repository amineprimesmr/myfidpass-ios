//
//  FlyerProPaywallGate.swift
//  myfidpass
//
//  Voile Pro sur le hub flyer de jeu.
//

import SwiftUI

extension View {
    func flyerProPaywallGated(
        locked: Bool,
        onUnlock: @escaping () -> Void
    ) -> some View {
        ZStack {
            self
                .compositingGroup()
                .blur(radius: locked ? 8 : 0, opaque: false)
                .opacity(locked ? 0.38 : 1)
                .allowsHitTesting(!locked)

            if locked {
                Color.black.opacity(0.42)
                    .allowsHitTesting(false)

                MerchantProUnlockTeaserButton(
                    unlockTitle: MerchantSubscriptionPricingCopy.flyerProUnlockCta
                ) {
                    onUnlock()
                }
                .padding(.horizontal, 24)
                .accessibilityLabel(MerchantSubscriptionPricingCopy.flyerProUnlockCta)
                .accessibilityAddTraits(.isButton)
            }
        }
    }
}
