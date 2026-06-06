//
//  MerchantProUnlockFlowModifier.swift
//  myfidpass
//

import SwiftUI

private struct MerchantProUnlockFlowModifier: ViewModifier {
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
                    onContinue: { presenter.continueToPaywall() },
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
