//
//  CustomAlertDrawer.swift
//  myfidpass
//
//  Intégré depuis le projet AlertDrawer (Balaji Venkatesh) — tiroir d’alerte morph depuis le bouton source.
//

import SwiftUI

// MARK: - Type-erased Shape (requis par DrawerConfig)

struct AnyShape: Shape, @unchecked Sendable {
    private let pathBuilder: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        pathBuilder = { rect in shape.path(in: rect) }
    }

    func path(in rect: CGRect) -> Path {
        pathBuilder(rect)
    }
}

// MARK: - Drawer Config

struct DrawerConfig {
    var tint: Color
    var foreground: Color
    var clipShape: AnyShape
    var animation: Animation
    fileprivate(set) var isPresented: Bool = false
    fileprivate(set) var hideSourceButton: Bool = false
    fileprivate(set) var sourceRect: CGRect = .zero

    init(
        tint: Color = .red,
        foreground: Color = .white,
        clipShape: AnyShape = AnyShape(Capsule()),
        animation: Animation = .snappy(duration: 0.35, extraBounce: 0)
    ) {
        self.tint = tint
        self.foreground = foreground
        self.clipShape = clipShape
        self.animation = animation
    }
}

// MARK: - Drawer Source Button

struct DrawerButton: View {
    var title: String
    @Binding var config: DrawerConfig

    var body: some View {
        Button {
            config.hideSourceButton = true
            withAnimation(config.animation) {
                config.isPresented = true
            }
        } label: {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(config.foreground)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(config.tint, in: config.clipShape)
        }
        .buttonStyle(ScaledButtonStyle())
        .opacity(config.hideSourceButton ? 0 : 1)
        .allowsHitTesting(!config.hideSourceButton)
        .onGeometryChange(for: CGRect.self) {
            $0.frame(in: .global)
        } action: { newValue in
            config.sourceRect = newValue
        }
    }
}

// MARK: - Overlay

extension View {
    @ViewBuilder
    func alertDrawer<Content: View>(
        config: Binding<DrawerConfig>,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimaryClick: @escaping () -> Bool,
        onSecondaryClick: @escaping () -> Bool,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                GeometryReader { geometry in
                    let isPresented = config.wrappedValue.isPresented

                    ZStack {
                        if isPresented {
                            Rectangle()
                                .fill(.black.opacity(0.5))
                                .transition(.opacity)
                                .onTapGesture {
                                    guard config.wrappedValue.isPresented else { return }

                                    withAnimation(config.wrappedValue.animation, completionCriteria: .logicallyComplete) {
                                        config.wrappedValue.isPresented = false
                                    } completion: {
                                        config.wrappedValue.hideSourceButton = false
                                    }
                                }
                        }

                        if config.wrappedValue.hideSourceButton {
                            AlertDrawerContent(
                                proxy: geometry,
                                primaryTitle: primaryTitle,
                                secondaryTitle: secondaryTitle,
                                onPrimaryClick: onPrimaryClick,
                                onSecondaryClick: onSecondaryClick,
                                config: config,
                                contentBuilder: content
                            )
                            .transition(.identity)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                    .ignoresSafeArea()
                }
            }
    }
}

private struct AlertDrawerContent<Content: View>: View {
    var proxy: GeometryProxy
    var primaryTitle: String
    var secondaryTitle: String
    var onPrimaryClick: () -> Bool
    var onSecondaryClick: () -> Bool
    @Binding var config: DrawerConfig
    private let contentBuilder: () -> Content

    init(
        proxy: GeometryProxy,
        primaryTitle: String,
        secondaryTitle: String,
        onPrimaryClick: @escaping () -> Bool,
        onSecondaryClick: @escaping () -> Bool,
        config: Binding<DrawerConfig>,
        @ViewBuilder contentBuilder: @escaping () -> Content
    ) {
        self.proxy = proxy
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.onPrimaryClick = onPrimaryClick
        self.onSecondaryClick = onSecondaryClick
        self._config = config
        self.contentBuilder = contentBuilder
    }

    private var actionBarHeight: CGFloat {
        max(config.sourceRect.height, 48)
    }

    var body: some View {
        let isPresented = config.isPresented
        let sourceRect = config.sourceRect
        let maxY = proxy.frame(in: .global).maxY
        let bottomPadding: CGFloat = 10

        VStack(spacing: 15) {
            contentBuilder()
                .overlay(alignment: .topTrailing) {
                    Button(action: dismissDrawer) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.primary, .gray.opacity(0.15))
                    }
                }
                .compositingGroup()
                .opacity(isPresented ? 1 : 0)

            HStack(spacing: 10) {
                GeometryReader { geometry in
                    Button {
                        if onSecondaryClick() {
                            dismissDrawer()
                        }
                    } label: {
                        Text(secondaryTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.ultraThinMaterial, in: config.clipShape)
                    }
                    .offset(fixedLocation(geometry))
                    .opacity(isPresented ? 1 : 0)
                }
                .frame(height: actionBarHeight)

                GeometryReader { geometry in
                    Button {
                        if onPrimaryClick() {
                            dismissDrawer()
                        }
                    } label: {
                        Text(primaryTitle)
                            .fontWeight(.semibold)
                            .foregroundStyle(config.foreground)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(config.tint, in: config.clipShape)
                    }
                    .frame(
                        width: isPresented ? nil : max(sourceRect.width, 1),
                        height: isPresented ? nil : max(sourceRect.height, 1)
                    )
                    .offset(fixedLocation(geometry))
                }
                .frame(height: actionBarHeight)
                .zIndex(1)
            }
            .buttonStyle(ScaledButtonStyle())
            .padding(.top, 10)
        }
        .padding([.horizontal, .top], 20)
        .padding(.bottom, 15)
        .frame(
            width: isPresented ? nil : max(sourceRect.width, 1),
            height: isPresented ? nil : max(sourceRect.height, 1),
            alignment: .top
        )
        .background(.background)
        .clipShape(.rect(cornerRadius: max(sourceRect.height, 1) / 2))
        .shadow(color: .black.opacity(isPresented ? 0.1 : 0), radius: 5, x: 5, y: 5)
        .shadow(color: .black.opacity(isPresented ? 0.1 : 0), radius: 5, x: -5, y: -5)
        .padding(.horizontal, isPresented ? 20 : 0)
        .visualEffect { content, proxy in
            content
                .offset(
                    x: isPresented ? 0 : sourceRect.minX,
                    y: (isPresented ? maxY - bottomPadding : sourceRect.maxY) - proxy.size.height
                )
        }
        .allowsHitTesting(config.isPresented)
    }

    private func dismissDrawer() {
        withAnimation(config.animation, completionCriteria: .logicallyComplete) {
            config.isPresented = false
        } completion: {
            config.hideSourceButton = false
        }
    }

    private func fixedLocation(_ proxy: GeometryProxy) -> CGSize {
        let isPresented = config.isPresented
        let sourceRect = config.sourceRect

        return CGSize(
            width: isPresented ? 0 : (sourceRect.minX - proxy.frame(in: .global).minX),
            height: isPresented ? 0 : (sourceRect.minY - proxy.frame(in: .global).minY)
        )
    }
}

private struct ScaledButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.linear(duration: 0.1), value: configuration.isPressed)
    }
}
