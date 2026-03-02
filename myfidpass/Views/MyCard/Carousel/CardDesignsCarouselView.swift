//
//  CardDesignsCarouselView.swift
//  myfidpass
//
//  Galerie de designs en carousel (style iOS26LSCarousel) : même layout que CustomCarousel, données CardDesignPreset.
//

import SwiftUI

struct CardDesignsCarouselView: View {
    var presets: [CardDesignPreset]
    var onApplyDesign: ((CardDesignPreset) -> Void)?
    var onDismiss: (() -> Void)?

    @State private var offsetX: CGFloat = 0
    @State private var selectedPresetId: String?
    @State private var reflectionScrollPosition: ScrollPosition = .init()

    private let cardWidth: CGFloat = 340
    private let spacing: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let cardHeight = min(max((size.height - 140), 0), 900)
            let horizontalPadding = (size.width - cardWidth) / 2

            ZStack {
                Rectangle()
                    .fill(backgroundColor)
                    .ignoresSafeArea()

                if size != .zero {
                    VStack(spacing: 15) {
                        LabelView(size: size)
                        ScrollView(.horizontal) {
                            LazyHStack(spacing: spacing) {
                                ForEach(presets) { preset in
                                    cardView(preset: preset, cardHeight: cardHeight)
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: $selectedPresetId, anchor: .center)
                        .safeAreaPadding(.horizontal, horizontalPadding)
                        .frame(height: cardHeight)
                        .onScrollGeometryChange(for: CGFloat.self) {
                            $0.contentOffset.x + $0.contentInsets.leading
                        } action: { _, newValue in
                            offsetX = newValue
                            reflectionScrollPosition.scrollTo(x: newValue)
                        }

                        BottomBar(size: size, cardHeight: cardHeight)
                    }
                }
            }
        }
        .onAppear {
            if selectedPresetId == nil {
                selectedPresetId = presets.first?.id
            }
        }
    }

    @ViewBuilder
    private func cardView(preset: CardDesignPreset, cardHeight: CGFloat) -> some View {
        Group {
            if preset.displayFormat == .stampGrid {
                StampGridStyleCardPreview(
                    displayName: preset.displayName,
                    requiredStamps: preset.requiredStamps,
                    stampsCount: Int32(min(3, preset.requiredStamps)),
                    memberName: "Prévisualisation",
                    filledColorHex: preset.accentHex
                )
            } else {
                WalletCardPreview(
                    displayName: preset.displayName,
                    requiredStamps: preset.requiredStamps,
                    stampsCount: Int32(min(3, preset.requiredStamps)),
                    primaryColorHex: preset.primaryHex,
                    accentColorHex: preset.accentHex,
                    logoURL: nil,
                    stampEmoji: preset.stampEmoji,
                    compact: false
                )
            }
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(.rect(cornerRadius: 40))
    }

    @ViewBuilder
    private func LabelView(size: CGSize) -> some View {
        let progress = spacing > 0 ? offsetX / (cardWidth + spacing) : 0
        let slideOffset = progress * size.width
        HStack(spacing: 0) {
            ForEach(presets) { preset in
                Text(preset.displayName)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(width: size.width)
            }
        }
        .offset(x: -slideOffset)
        .frame(width: size.width, height: 50, alignment: .leading)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func BottomBar(size: CGSize, cardHeight: CGFloat) -> some View {
        let horizontalPadding = (size.width - cardWidth) / 2
        let bottombarLayout = HStack(spacing: 10) {
            Capsule()
                .fill(backgroundColor)
                .frame(width: 220, height: 55)
            Circle()
                .fill(backgroundColor)
                .frame(width: 55, height: 55)
        }

        ZStack {
            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) {
                    ForEach(presets) { preset in
                        cardView(preset: preset, cardHeight: cardHeight)
                    }
                }
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .scrollPosition($reflectionScrollPosition)
            .scrollIndicators(.hidden)
            .frame(width: size.width, height: size.height, alignment: .leading)
            .compositingGroup()
            .blur(radius: 10)
            .frame(height: 60, alignment: .bottom)
            .offset(y: 130)
            .mask {
                bottombarLayout
                    .mask {
                        LinearGradient(colors: [
                            .white,
                            .white.opacity(0.5),
                            .clear,
                            .clear
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .offset(x: 33, y: -0.6)
            }
            .overlay {
                bottombarLayout
                    .offset(x: 33)
            }
            .allowsHitTesting(false)

            HStack(spacing: 10) {
                if let onApply = onApplyDesign, let id = selectedPresetId, let preset = presets.first(where: { $0.id == id }) {
                    Button {
                        onApply(preset)
                        onDismiss?()
                    } label: {
                        Text("Appliquer")
                            .fontWeight(.medium)
                            .frame(width: 220, height: 55)
                            .carouselButtonBackground()
                    }
                }
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(width: 55, height: 55)
                        .carouselButtonBackground()
                }
            }
            .foregroundStyle(.white)
            .offset(x: 33)
        }
        .frame(height: 60)
        .padding(.top, 10)
    }

    private var backgroundColor: Color { .black }
}

private extension View {
    @ViewBuilder
    func carouselButtonBackground() -> some View {
        self
            .background {
                ZStack {
                    Capsule()
                        .fill(.white.opacity(0.05))
                    Capsule()
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
            }
    }
}

#Preview {
    CardDesignsCarouselView(presets: Array(CardDesignPresets.all.prefix(4)), onApplyDesign: nil, onDismiss: nil)
}
