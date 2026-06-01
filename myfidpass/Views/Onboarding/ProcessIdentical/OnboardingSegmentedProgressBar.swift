//
//  OnboardingSegmentedProgressBar.swift
//  myfidpass
//
//  Barre segmentée (style Tuyo) — une barre par étape, remplissage animé.
//

import SwiftUI

enum OnboardingSegmentedProgressStyle {
    case lightBackground
    case darkBackground
}

struct OnboardingSegmentedProgressBar: View {
    let filledSegments: Int
    let totalSegments: Int
    var style: OnboardingSegmentedProgressStyle = .darkBackground

    @State private var animatedFill: Int = 0

    private var clampedTotal: Int { max(1, totalSegments) }
    private var clampedFilled: Int { min(max(0, filledSegments), clampedTotal) }

    private var filledColor: Color {
        switch style {
        case .lightBackground: return AppTheme.Colors.primary
        case .darkBackground: return .white
        }
    }

    private var unfilledColor: Color {
        switch style {
        case .lightBackground: return Color.black.opacity(0.1)
        case .darkBackground: return Color.white.opacity(0.18)
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<clampedTotal, id: \.self) { index in
                Capsule(style: .continuous)
                    .fill(index < animatedFill ? filledColor : unfilledColor)
                    .frame(height: 4)
                    .shadow(
                        color: index < animatedFill ? filledColor.opacity(0.22) : .clear,
                        radius: 2,
                        y: 0
                    )
            }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.82), value: animatedFill)
        .onAppear {
            animatedFill = clampedFilled
        }
        .onChange(of: clampedFilled) { _, newValue in
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                animatedFill = newValue
            }
        }
    }
}
