//
//  CustomMenuView.swift
//  myfidpass
//
//  Menu style iMessage (réutilisé depuis iMessageAnimation). S'affiche au tap sur l'icône cloche « message pour tous les membres ».
//

import SwiftUI

/// Durées et courbes d'animation pour un rendu fluide type iMessage.
private enum MenuAnimation {
    static let openDuration: Double = 0.38
    static let closeDuration: Double = 0.2
    static let labelsDelay: Double = 0.06
    static let itemStagger: Double = 0.022
}

/// Wrapper pour afficher le menu en overlay au-dessus du contenu.
struct CustomMenuView<Content: View>: View {
    @Binding var config: MenuConfig
    var actions: [MenuAction]
    @ViewBuilder var content: Content
    @State private var animateContent: Bool = false
    @State private var animateLabels: Bool = false
    @State private var activeActionID: String?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { overlayBackground }
            .overlay { overlayBlockingLayer }
            .overlay { overlayMenu }
            .onChange(of: config.showMenu) { _, newValue in
                if newValue {
                    config.hideSouceView = true
                } else {
                    let closeDur = MenuAnimation.closeDuration
                    DispatchQueue.main.asyncAfter(deadline: .now() + closeDur) {
                        config.hideSouceView = false
                        activeActionID = actions.first?.id
                    }
                }
                let duration = newValue ? MenuAnimation.openDuration : MenuAnimation.closeDuration
                withAnimation(.easeOut(duration: duration)) {
                    animateContent = newValue
                }
                withAnimation(.easeOut(duration: newValue ? 0.28 : 0.1).delay(newValue ? MenuAnimation.labelsDelay : 0)) {
                    animateLabels = newValue
                }
            }
    }

    /// Fond semi-transparent (bar) qui apparaît en fondu.
    private var overlayBackground: some View {
        Rectangle()
            .fill(.bar)
            .ignoresSafeArea()
            .opacity(animateContent ? 1 : 0)
            .animation(.easeOut(duration: animateContent ? MenuAnimation.openDuration : MenuAnimation.closeDuration), value: animateContent)
            .allowsHitTesting(false)
    }

    /// Zone sous le menu (état géré par délai à la fermeture, plus de onDisappear).
    @ViewBuilder
    private var overlayBlockingLayer: some View {
        if animateContent {
            Color.clear
                .contentShape(.rect)
                .ignoresSafeArea()
        }
    }

    /// Menu + copie animée du bouton source.
    private var overlayMenu: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                MenuScrollView(proxy)

                if config.hideSouceView {
                    config.sourceView
                        .scaleEffect(animateContent ? 15 : 1, anchor: .bottom)
                        .offset(x: config.sourceLocation.minX, y: config.sourceLocation.minY)
                        .opacity(animateContent ? 0.22 : 1)
                        .blur(radius: animateContent ? 120 : 0)
                        .animation(.easeOut(duration: animateContent ? MenuAnimation.openDuration : MenuAnimation.closeDuration), value: animateContent)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(animateContent ? 1 : 0)
        .animation(.easeOut(duration: MenuAnimation.closeDuration), value: animateContent)
        .allowsHitTesting(config.showMenu)
        .geometryGroup()
    }

    @ViewBuilder
    func MenuScrollView(_ proxy: GeometryProxy) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                    MenuActionView(action: action, index: index, animateContent: animateContent, animateLabels: animateLabels, sourceLocation: config.sourceLocation)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                    .contentShape(.rect)
                    .onTapGesture {
                        guard config.showMenu else { return }
                        config.showMenu = false
                    }
                    .visualEffect { content, geometry in
                        content
                            .offset(
                                x: -geometry.frame(in: .global).minX,
                                y: -geometry.frame(in: .global).minY
                            )
                    }
            }
        }
        .safeAreaPadding(.vertical, 20)
        .safeAreaPadding(.top, max(0, (proxy.size.height - 70) / 2))
        .scrollPosition(id: $activeActionID, anchor: .top)
        .scrollIndicators(.hidden)
        .allowsHitTesting(config.showMenu)
    }
}

/// Une ligne du menu (icône + texte), avec animation décalée par index.
struct MenuActionView: View {
    let action: MenuAction
    let index: Int
    let animateContent: Bool
    let animateLabels: Bool
    let sourceLocation: CGRect

    var body: some View {
        let itemDelay = Double(index) * MenuAnimation.itemStagger
        let openDuration = MenuAnimation.openDuration
        let closeDuration = MenuAnimation.closeDuration

        HStack(spacing: 20) {
            Image(systemName: action.symbolImage)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.background)
                        .shadow(radius: 1.5)
                }
                .scaleEffect(animateContent ? 1 : 0.5)
                .opacity(animateContent ? 1 : 0)
                .blur(radius: animateContent ? 0 : 6)
                .animation(.easeOut(duration: animateContent ? openDuration : closeDuration).delay(animateContent ? itemDelay : 0), value: animateContent)

            Text(action.text)
                .font(.system(size: 19))
                .fontWeight(.medium)
                .lineLimit(1)
                .opacity(animateLabels ? 1 : 0)
                .blur(radius: animateLabels ? 0 : 4)
                .animation(.easeOut(duration: animateLabels ? 0.28 : 0.12).delay(animateLabels ? itemDelay + MenuAnimation.labelsDelay : 0), value: animateLabels)
        }
        .visualEffect { [animateContent] content, geometry in
            content
                .offset(
                    x: animateContent ? 0 : sourceLocation.minX - geometry.frame(in: .global).minX,
                    y: animateContent ? 0 : sourceLocation.minY - geometry.frame(in: .global).minY
                )
        }
        .animation(.easeOut(duration: animateContent ? openDuration : closeDuration).delay(animateContent ? itemDelay : 0), value: animateContent)
        .frame(height: 70)
        .contentShape(.rect)
        .onTapGesture {
            action.action()
        }
    }
}

/// Bouton source qui ouvre le menu (animation depuis sa position).
struct MenuSourceButton<Content: View>: View {
    @Binding var config: MenuConfig
    @ViewBuilder var content: Content
    var onTap: () -> Void

    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture {
                onTap()
                config.sourceView = AnyView(content)
                config.showMenu.toggle()
            }
            .onGeometryChange(for: CGRect.self) { view in
                view.frame(in: .global)
            } action: { newValue in
                config.sourceLocation = newValue
            }
            .opacity(config.hideSouceView ? 0.01 : 1)
            .animation(.easeOut(duration: 0.2), value: config.hideSouceView)
    }
}

struct MenuConfig {
    var symbolImage: String
    var sourceLocation: CGRect = .zero
    var showMenu: Bool = false
    var sourceView: AnyView = .init(EmptyView())
    var hideSouceView: Bool = false
}

struct MenuAction: Identifiable {
    private(set) var id: String
    var symbolImage: String
    var text: String
    var action: () -> Void = {}

    init(id: String = UUID().uuidString, symbolImage: String, text: String, action: @escaping () -> Void = {}) {
        self.id = id
        self.symbolImage = symbolImage
        self.text = text
        self.action = action
    }
}

@resultBuilder
struct MenuActionBuilder {
    static func buildBlock(_ components: MenuAction...) -> [MenuAction] {
        Array(components)
    }
    static func buildBlock(_ components: [MenuAction]...) -> [MenuAction] {
        components.flatMap { $0 }
    }
    static func buildArray(_ components: [MenuAction]) -> [MenuAction] {
        components
    }
}
