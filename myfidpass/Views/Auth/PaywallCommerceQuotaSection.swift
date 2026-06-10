//
//  PaywallCommerceQuotaSection.swift
//  myfidpass
//
//  Sélecteur minimal commerces (1–5) sur le paywall.
//

import SwiftUI

struct PaywallCommerceQuotaSection: View {
    let businesses: [BusinessDTO]
    let usedBusinesses: Int
    let allowedBusinesses: Int
    let hasActiveSubscription: Bool
    let addingAnotherCommerce: Bool
    let pendingCommerceName: String?
    @Binding var selectedTargetSlots: Int

    private var paidSlotsBaseline: Int {
        min(5, max(1, allowedBusinesses))
    }

    private var minSelectableSlots: Int {
        if !hasActiveSubscription { return 1 }
        if addingAnotherCommerce || usedBusinesses >= paidSlotsBaseline {
            return min(5, max(paidSlotsBaseline + 1, usedBusinesses + 1))
        }
        return paidSlotsBaseline
    }

    private var maxSelectableSlots: Int { 5 }

    var body: some View {
        HStack(spacing: 18) {
            stepperButton(
                symbol: "minus",
                enabled: selectedTargetSlots > minSelectableSlots,
                accessibilityLabel: "Retirer un commerce"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedTargetSlots = max(minSelectableSlots, selectedTargetSlots - 1)
            }

            Text("\(selectedTargetSlots)")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.11))
                .frame(minWidth: 36)
                .accessibilityLabel("\(selectedTargetSlots) commerces")

            stepperButton(
                symbol: "plus",
                enabled: selectedTargetSlots < maxSelectableSlots,
                accessibilityLabel: "Ajouter un commerce"
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                selectedTargetSlots = min(maxSelectableSlots, selectedTargetSlots + 1)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .onAppear { clampSelectedSlots() }
        .onChange(of: paidSlotsBaseline) { _, _ in clampSelectedSlots() }
        .onChange(of: usedBusinesses) { _, _ in clampSelectedSlots() }
    }

    @ViewBuilder
    private func stepperButton(
        symbol: String,
        enabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(red: 0.08, green: 0.09, blue: 0.11).opacity(enabled ? 0.88 : 0.28))
                .frame(width: 52, height: 52)
        }
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 26)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.55)
        .accessibilityLabel(accessibilityLabel)
    }

    private func clampSelectedSlots() {
        let minSlots = minSelectableSlots
        if selectedTargetSlots < minSlots {
            selectedTargetSlots = minSlots
        }
        selectedTargetSlots = min(5, max(1, selectedTargetSlots))
    }
}
