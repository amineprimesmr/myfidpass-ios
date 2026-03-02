//
//  CustomMenuView.swift
//  iMessageAnimation
//
//  Created by Balaji Venkatesh on 23/05/25.
//

import SwiftUI

/// Act's as a Wrapper to show menu view on top of the wrapped view
struct CustomMenuView<Content: View>: View {
    @Binding var config: MenuConfig
    @ViewBuilder var content: Content
    @MenuActionBuilder var actions: [MenuAction]
    /// View Properties
    @State private var animateContent: Bool = false
    @State private var animateLabels: Bool = false
    /// For Resetting Scroll Position, once the menu closed!
    @State private var activeActionID: String?
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                /// Blurred Overlay
                Rectangle()
                    .fill(.bar)
                    .ignoresSafeArea()
                    .opacity(animateContent ? 1 : 0)
                    .allowsHitTesting(false)
            }
            .overlay {
                if animateContent {
                    /// Instead of using withAnimation completion callback, I'm using onDisappear modifier to know when the animation get's completed!
                    Rectangle()
                        .foregroundStyle(.clear)
                        /// Disabling user interaction until menu view gets closed completely!
                        .contentShape(.rect)
                        .onDisappear {
                            config.hideSouceView = false
                            activeActionID = actions.first?.id
                        }
                }
            }
            .overlay {
                GeometryReader {
                    MenuScrollView($0)
                    
                    if config.hideSouceView {
                        config.sourceView
                            .scaleEffect(animateContent ? 15 : 1, anchor: .bottom)
                            .offset(x: config.sourceLocation.minX, y: config.sourceLocation.minY)
                            .opacity(animateContent ? 0.25 : 1)
                            .blur(radius: animateContent ? 130 : 0)
                            .ignoresSafeArea()
                            .allowsHitTesting(false)
                    }
                }
                .opacity(config.hideSouceView ? 1 : 0)
            }
            .onChange(of: config.showMenu) { oldValue, newValue in
                if newValue {
                    config.hideSouceView = true
                }
                
                /// Change the animation, as per your needs!
                withAnimation(.smooth(duration: 0.45, extraBounce: 0)) {
                    animateContent = newValue
                }
                
                withAnimation(.easeInOut(duration: newValue ? 0.35 : 0.15)) {
                    animateLabels = newValue
                }
            }
    }
    
    /// Menu Scroll View
    @ViewBuilder
    func MenuScrollView(_ proxy: GeometryProxy) -> some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(actions) {
                    MenuActionView($0)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 25)
            .frame(maxWidth: .infinity, alignment: .leading)
            /// For background tap to dismiss the menu view
            .background {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(width: proxy.size.width, height: proxy.size.height + proxy.safeAreaInsets.top + proxy.safeAreaInsets.bottom)
                    .contentShape(.rect)
                    .onTapGesture {
                        guard config.showMenu else { return }
                        config.showMenu = false
                    }
                    /// Sticking to the top!
                    .visualEffect { content, proxy in
                        content
                            .offset(
                                x: -proxy.frame(in: .global).minX,
                                y: -proxy.frame(in: .global).minY
                            )
                    }
            }
        }
        .safeAreaPadding(.vertical, 20)
        /// Making it to start at center
        .safeAreaPadding(.top, (proxy.size.height - 70) / 2)
        .scrollPosition(id: $activeActionID, anchor: .top)
        .scrollIndicators(.hidden)
        .allowsHitTesting(config.showMenu)
    }
    
    /// Menu Action View
    @ViewBuilder
    func MenuActionView(_ action: MenuAction) -> some View {
        let sourceLocation = config.sourceLocation
        
        HStack(spacing: 20) {
            Image(systemName: action.symbolImage)
                .font(.title3)
                .frame(width: 40, height: 40)
                .background {
                    Circle()
                        .fill(.background)
                        .shadow(radius: 1.5)
                }
                .scaleEffect(animateContent ? 1 : 0.6)
                .opacity(animateContent ? 1 : 0)
                .blur(radius: animateContent ? 0 : 4)
            
            Text(action.text)
                .font(.system(size: 19))
                .fontWeight(.medium)
                .lineLimit(1)
                .opacity(animateLabels ? 1 : 0)
                .blur(radius: animateLabels ? 0 : 4)
        }
        .visualEffect({ [animateContent] content, proxy in
            content
                /// Making all the action to be placed at the source button location
                .offset(
                    x: animateContent ? 0 : sourceLocation.minX - proxy.frame(in: .global).minX,
                    y: animateContent ? 0 : sourceLocation.minY - proxy.frame(in: .global).minY
                )
        })
        .frame(height: 70)
        .contentShape(.rect)
        .onTapGesture {
            action.action()
        }
    }
}

/// Customized Source Button
struct MenuSourceButton<Content: View>: View {
    @Binding var config: MenuConfig
    @ViewBuilder var content: Content
    /// For more user customization!
    var onTap: () -> ()
    var body: some View {
        content
            .contentShape(.rect)
            .onTapGesture {
                onTap()
                config.sourceView = .init(content)
                config.showMenu.toggle()
            }
            /// Saving Source Location
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                config.sourceLocation = newValue
            }
            /// Hiding Source View when hideSouceView is Enabled
            .opacity(config.hideSouceView ? 0.01 : 1)
    }
}

#Preview {
    ContentView()
}

/// Menu Config
struct MenuConfig {
    var symbolImage: String
    var sourceLocation: CGRect = .zero
    var showMenu: Bool = false
    /// Storing Source View (Label) for scaling Effect!
    var sourceView: AnyView = .init(EmptyView())
    /// Use this property to disable any view getting interacted when the menu view is opened or not closed completely!
    var hideSouceView: Bool = false
}

/// Menu Action & Action Builder
struct MenuAction: Identifiable {
    private(set) var id: String = UUID().uuidString
    var symbolImage: String
    var text: String
    var action: () -> () = {  }
}

@resultBuilder
struct MenuActionBuilder {
    static func buildBlock(_ components: MenuAction...) -> [MenuAction] {
        components.compactMap({ $0 })
    }
}
