//
//  SlideToConfirm.swift
//  myfidpass
//
//  Intégré depuis le projet SlideControl (Balaji Venkatesh) — glisser pour confirmer.
//

import SwiftUI
import UIKit

struct SlideToConfirm: View {
    var config: Config
    var onSwiped: () -> Void
    /// View Properties
    @State private var animateText: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var isCompleted: Bool = false
    var body: some View {
        GeometryReader { geometry in
            let raw = geometry.size
            let safeW = raw.width.isFinite && raw.width > 0 ? raw.width : 1
            let safeH = raw.height.isFinite && raw.height > 0 ? raw.height : 1
            let size = CGSize(width: safeW, height: safeH)
            let knobSize = size.height
            let maxLimit = max(0, size.width - knobSize)
            let progress: CGFloat = isCompleted ? 1 : (maxLimit > 0 ? offsetX / maxLimit : 0)

            ZStack(alignment: .leading) {
                /// Fond 100 % opaque (`tertiarySystemFill`) — pas d’ombre interne (API `.shadow(.inner)` non portable).
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )

                /// Tint Capsule
                let extraCapsuleWidth = max(0, (size.width - knobSize) * progress)

                Capsule()
                    .fill(config.tint.gradient)
                    .frame(width: max(knobSize, knobSize + extraCapsuleWidth), height: knobSize)

                LeadingTextView(size, progress: progress)

                HStack(spacing: 0) {
                    KnobView(size, progress: progress, maxLimit: maxLimit)
                        .zIndex(1)

                    ShimmerTextView(size, progress: progress)
                }
            }
        }
        /// Pleine largeur dans la feuille « Ajouter des points » (le projet d’origine limitait à 300 pt).
        .frame(height: max(1, isCompleted ? 50 : config.height))
        .frame(maxWidth: .infinity)
        /// Disabling User Interaction When swipe confirmed
        .allowsHitTesting(!isCompleted)
    }

    /// Knob View
    func KnobView(_ size: CGSize, progress: CGFloat, maxLimit: CGFloat) -> some View {
        Circle()
            .fill(.background)
            .padding(config.knobPadding)
            .frame(width: size.height, height: size.height)
            .overlay {
                ZStack {
                    Image(systemName: "chevron.right")
                        .opacity(1 - progress)
                        .blur(radius: progress * 10)

                    Image(systemName: "checkmark")
                        .opacity(progress)
                        .blur(radius: (1 - progress) * 10)
                }
                .font(.title3.bold())
            }
            .contentShape(.circle)
            .scaleEffect(isCompleted ? 0.6 : 1, anchor: .center)
            .offset(x: isCompleted ? maxLimit : offsetX)
            .gesture(
                DragGesture()
                    .onChanged({ value in
                        offsetX = min(max(value.translation.width, 0), maxLimit)
                    }).onEnded({ value in
                        let threshold = min(max(config.completionProgressThreshold, 0.22), 0.98)
                        let minX = maxLimit * threshold
                        /// Petit coup de pouce si le geste finit vite vers la droite (flick).
                        let flickBoost: CGFloat = {
                            let v = value.predictedEndTranslation.width
                            guard v > 120, maxLimit > 0 else { return 0 }
                            return min(maxLimit * 0.12, v * 0.08)
                        }()
                        let effective = min(offsetX + flickBoost, maxLimit)
                        let reached = maxLimit <= 0 ? false : effective >= minX - 0.5
                        if reached {
                            onSwiped()
                            /// Stopping Shimmer Effect
                            animateText = false

                            withAnimation(.smooth) {
                                isCompleted = true
                            }
                        } else {
                            withAnimation(.smooth) {
                                offsetX = 0
                            }
                        }
                    })
            )
    }

    /// Shimmer Text View
    func ShimmerTextView(_ size: CGSize, progress: CGFloat) -> some View {
        Text(isCompleted ? config.confirmationText : config.idleText)
            .foregroundStyle(.gray.opacity(0.6))
            .overlay {
                /// Shimmer Effect
                Rectangle()
                    .frame(height: 15)
                    .rotationEffect(.init(degrees: 90))
                    .visualEffect { [animateText] content, proxy in
                        content
                            .offset(x: -proxy.size.width / 1.8)
                            .offset(x: animateText ? proxy.size.width * 1.2 : 0)
                    }
                    .mask(alignment: .leading) {
                        Text(isCompleted ? config.confirmationText : config.idleText)
                    }
                    .blendMode(.softLight)
            }
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            /// To Make it Center
            /// Eliminating knob's radius
            .padding(.trailing, size.height / 2)
            .mask {
                Rectangle()
                    .scale(x: 1 - progress, anchor: .trailing)
            }
            .frame(height: size.height)
            .task {
                guard !isCompleted && !animateText else { return }

                try? await Task.sleep(for: .seconds(0))
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    animateText = true
                }
            }
    }

    /// OnSwipe/Confirmation Text View
    func LeadingTextView(_ size: CGSize, progress: CGFloat) -> some View {
        ZStack {
            Text(config.onSwipeText)
                .opacity(isCompleted ? 0 : 1)
                .blur(radius: isCompleted ? 10 : 0)

            Text(config.confirmationText)
                .opacity(!isCompleted ? 0 : 1)
                .blur(radius: !isCompleted ? 10 : 0)
        }
        .fontWeight(.semibold)
        .foregroundStyle(config.foregorundColor)
        .frame(maxWidth: .infinity)
        /// To make it Center
        /// Since when completed the knob becomes smaller by scale modifier!
        .padding(.trailing, (size.height * (isCompleted ? 0.6 : 1)) / 2)
        .mask {
            Rectangle()
                .scale(x: progress, anchor: .leading)
        }
    }

    struct Config {
        var idleText: String
        var onSwipeText: String
        var confirmationText: String
        var tint: Color
        var foregorundColor: Color
        var height: CGFloat = 65
        /// Add Other Customization Properties as per your needs!
        var knobPadding: CGFloat = 5
        /// Part du trajet (0…1) à parcourir pour valider au relâchement (défaut ≈ ancien comportement « presque bout du rail »).
        var completionProgressThreshold: CGFloat = 0.96
    }
}

#if DEBUG
#Preview {
    SlideToConfirm(
        config: .init(
            idleText: "Glisser pour payer",
            onSwipeText: "Confirmation",
            confirmationText: "Réussi !",
            tint: .green,
            foregorundColor: .white
        )
    ) {}
    .padding()
}
#endif
