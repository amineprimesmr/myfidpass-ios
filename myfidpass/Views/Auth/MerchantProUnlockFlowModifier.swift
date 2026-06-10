//
//  MerchantProUnlockFlowModifier.swift
//  myfidpass
//

import SwiftUI

private struct MerchantProUnlockFlowModifier: ViewModifier {
    @EnvironmentObject private var authService: AuthService
    @ObservedObject private var presenter = MerchantProUnlockPresenter.shared

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { presenter.showsTeaser },
                set: { presented in
                    if !presented { presenter.dismissTeaser() }
                }
            )) {
                MerchantProUnlockTeaserSheet(
                    onContinue: {
                        presenter.dismissTeaser()
                        NotificationCenter.default.postOpenMerchantSubscriptionFromSession(
                            usedBusinesses: authService.usedBusinesses,
                            allowedBusinesses: authService.allowedBusinesses,
                            hasActiveSubscription: authService.hasEncashedMerchantSubscription
                        )
                    },
                    onLater: { presenter.dismissTeaser() }
                )
                .presentationDetents([.height(520), .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .interactiveDismissDisabled(false)
            }
    }
}

extension View {
    func merchantProUnlockFlow() -> some View {
        modifier(MerchantProUnlockFlowModifier())
    }
}
