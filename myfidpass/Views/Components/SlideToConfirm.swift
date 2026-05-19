//
//  SlideToConfirm.swift
//  myfidpass
//
//  Glisser pour confirmer — adapté depuis le sample « SlideControl » (Balaji Venkatesh).
//

import SwiftUI

/// Curseur horizontal « slide to confirm » (remplace un gros bouton de validation).
struct SlideToConfirm: View {
    var config: Config
    var onSwiped: () -> Void

    @State private var animateText: Bool = false
    @State private var offsetX: CGFloat = 0
    @State private var isCompleted: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let knobSize = size.height
            let maxLimit = max(0, size.width - knobSize)
            let progress: CGFloat = isCompleted ? 1 : (maxLimit > 0 ? (offsetX / maxLimit) : 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.gray.opacity(0.22))
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                    }

                Capsule()
                    .fill(config.tint.gradient)
                    .frame(width: knobSize + (size.width - knobSize) * progress, height: knobSize)

                leadingTextView(size: size, progress: progress, maxLimit: maxLimit)

                HStack(spacing: 0) {
                    knobView(size: size, progress: progress, maxLimit: maxLimit)
                        .zIndex(1)
                    shimmerTextView(size: size, progress: progress, maxLimit: maxLimit)
                }
            }
        }
        .frame(height: isCompleted ? 50 : config.height)
        .frame(maxWidth: .infinity)
        .allowsHitTesting(!isCompleted && !config.disabled)
        .opacity(config.disabled ? 0.45 : 1)
    }

    private func knobView(size: CGSize, progress: CGFloat, maxLimit: CGFloat) -> some View {
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
                    .onChanged { value in
                        guard !config.disabled else { return }
                        offsetX = min(max(value.translation.width, 0), maxLimit)
                    }
                    .onEnded { _ in
                        guard !config.disabled else {
                            withAnimation(.smooth) { offsetX = 0 }
                            return
                        }
                        if maxLimit <= 0 { return }
                        if offsetX >= maxLimit - 1.5 {
                            onSwiped()
                            animateText = false
                            withAnimation(.smooth) {
                                isCompleted = true
                            }
                        } else {
                            withAnimation(.smooth) {
                                offsetX = 0
                            }
                        }
                    }
            )
    }

    private func shimmerTextView(size: CGSize, progress: CGFloat, maxLimit: CGFloat) -> some View {
        Text(isCompleted ? config.confirmationText : config.idleText)
            .foregroundStyle(Color.secondary.opacity(0.75))
            .overlay {
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
            .padding(.trailing, size.height / 2)
            .mask {
                Rectangle()
                    .scale(x: maxLimit > 0 ? (1 - progress) : 1, anchor: .trailing)
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

    private func leadingTextView(size: CGSize, progress: CGFloat, maxLimit: CGFloat) -> some View {
        ZStack {
            Text(config.onSwipeText)
                .opacity(isCompleted ? 0 : 1)
                .blur(radius: isCompleted ? 10 : 0)

            Text(config.confirmationText)
                .opacity(!isCompleted ? 0 : 1)
                .blur(radius: !isCompleted ? 10 : 0)
        }
        .fontWeight(.semibold)
        .foregroundStyle(config.foregroundColor)
        .frame(maxWidth: .infinity)
        .padding(.trailing, (size.height * (isCompleted ? 0.6 : 1)) / 2)
        .mask {
            Rectangle()
                .scale(x: maxLimit > 0 ? progress : 0, anchor: .leading)
        }
    }

    struct Config {
        var idleText: String
        var onSwipeText: String
        var confirmationText: String
        var tint: Color
        /// Couleur du texte « plein » sous le fond teinté.
        var foregroundColor: Color
        var height: CGFloat = 56
        var knobPadding: CGFloat = 5
        var disabled: Bool = false
    }
}
