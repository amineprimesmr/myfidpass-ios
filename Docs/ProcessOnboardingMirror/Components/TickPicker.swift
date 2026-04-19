//
//  TickPicker.swift
//  Process
//
//  Picker horizontal à graduations (style TickPickerView).
//

import SwiftUI

struct TickConfig {
    var tickWidth: CGFloat = 3
    var tickHeight: CGFloat = 30
    var tickHPadding: CGFloat = 3
    var inActiveHeightProgress: CGFloat = 0.55
    var interactionHeight: CGFloat = 60
    var activeTint: Color = .yellow
    var inActiveTint: Color = .primary
    var alignment: Alignment = .bottom
    var animation: Animation = .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)

    enum Alignment: String, CaseIterable {
        case top = "Top"
        case bottom = "Bottom"
        case center = "Center"

        var value: SwiftUI.Alignment {
            switch self {
            case .top: return .top
            case .bottom: return .bottom
            case .center: return .center
            }
        }
    }
}

/// APIs de défilement utilisées (`ScrollPhase`, `onScrollGeometryChange`, `onScrollPhaseChange`) : iOS 18+.
@available(iOS 18.0, *)
struct TickPicker: View {
    var count: Int
    var config: TickConfig = .init()
    @Binding var selection: Int
    @State private var scrollIndex: Int = 0
    @State private var scrollPosition: Int?
    @State private var scrollPhase: ScrollPhase = .idle
    @State private var animationRange: ClosedRange<Int> = 0...0
    @State private var isInitialSetupDone: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(0...count, id: \.self) { index in
                        TickView(index)
                    }
                }
                .frame(height: config.tickHeight)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
            .scrollPosition(id: $scrollPosition, anchor: .center)
            .safeAreaPadding(.horizontal, (size.width - width) / 2)
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.x + $0.contentInsets.leading
            } action: { _, newValue in
                guard scrollPhase != .idle else { return }
                let index = max(min(Int((newValue / width).rounded()), count), 0)
                let previousScrollIndex = scrollIndex
                scrollIndex = index

                let isGreater = scrollIndex > previousScrollIndex
                let leadingBound = isGreater ? previousScrollIndex : scrollIndex
                let trailingBound = !isGreater ? previousScrollIndex : scrollIndex

                animationRange = leadingBound...trailingBound
            }
            .onScrollPhaseChange { _, newPhase in
                scrollPhase = newPhase
                animationRange = scrollIndex...scrollIndex

                if newPhase == .idle && scrollPosition != scrollIndex {
                    withAnimation(config.animation) {
                        scrollPosition = scrollIndex
                    }
                }
            }
        }
        .frame(height: config.interactionHeight)
        .task {
            guard !isInitialSetupDone else { return }
            updateScrollPosition(selection: selection)
            try? await Task.sleep(for: .seconds(0.05))
            isInitialSetupDone = true
        }
        .onChange(of: scrollIndex) { _, newValue in
            Task { @MainActor in
                selection = newValue
            }
        }
        .onChange(of: selection) { _, newValue in
            guard scrollIndex != newValue else { return }
            updateScrollPosition(selection: newValue)
        }
        .allowsHitTesting(isInitialSetupDone)
    }

    @ViewBuilder
    func TickView(_ index: Int) -> some View {
        let height = config.tickHeight
        let isInside = animationRange.contains(index)
        let fillColor = scrollIndex == index ? config.activeTint : config.inActiveTint.opacity(isInside ? 1 : 0.4)

        Rectangle()
            .fill(fillColor)
            .frame(
                width: config.tickWidth,
                height: height * (isInside ? 1 : config.inActiveHeightProgress)
            )
            .frame(width: width, height: height, alignment: config.alignment.value)
            .clipped()
            .animation(isInside || !isInitialSetupDone ? .none : config.animation, value: isInside)
    }

    func updateScrollPosition(selection: Int) {
        let safeSelection = max(min(selection, count), 0)
        scrollPosition = safeSelection
        scrollIndex = safeSelection
        animationRange = safeSelection...safeSelection
    }

    var width: CGFloat {
        config.tickWidth + (config.tickHPadding * 2)
    }
}
