//
//  MerchantSubscribePillView.swift
//  myfidpass
//
//  Pastille flottante au-dessus du tab bar : CTA abonnement (1 € premier mois via App Store).
//

import SwiftUI

struct MerchantSubscribePillView: View {
    var onSubscribe: () -> Void

    private var ctaLabel: String { MerchantSubscriptionPricingCopy.subscribeFloatingPillCta }

    var body: some View {
        Button(action: onSubscribe) {
            HStack {
                Spacer(minLength: 0)
                HStack(spacing: 9) {
                    SubscribePillBlinkingGreenDot()
                    Text(ctaLabel)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 14)
                .frame(maxWidth: 340)
                .background(Capsule().fill(Color.black))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(PressableSubscribePillStyle())
        .accessibilityLabel("\(ctaLabel). Touchez pour choisir l’abonnement.")
    }
}

/// Pastille verte clignotante — animation isolée (pas de reflow du parent).
private struct SubscribePillBlinkingGreenDot: View {
    @State private var isLit = false

    var body: some View {
        Circle()
            .fill(Color(red: 0.22, green: 0.86, blue: 0.42))
            .frame(width: 9, height: 9)
            .opacity(isLit ? 1 : 0.42)
            .overlay {
                Circle()
                    .stroke(Color(red: 0.22, green: 0.86, blue: 0.42).opacity(isLit ? 0.55 : 0.12), lineWidth: 2)
                    .scaleEffect(isLit ? 1.35 : 0.85)
            }
            .frame(width: 9, height: 9)
            .animation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true), value: isLit)
            .onAppear { isLit = true }
            .accessibilityHidden(true)
    }
}

private struct PressableSubscribePillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

#Preview {
    MerchantSubscribePillView(onSubscribe: {})
        .padding()
        .background(Color(.systemGroupedBackground))
}
