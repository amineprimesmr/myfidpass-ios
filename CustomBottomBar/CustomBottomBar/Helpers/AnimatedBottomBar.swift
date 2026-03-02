//
//  AnimatedBottomBar.swift
//  CustomBottomBar
//
//  Created by Balaji Venkatesh on 06/11/25.
//

import SwiftUI

struct AnimatedBottomBar<LeadingAction: View, TrailingAction: View, MainAction: View>: View {
    var highlightWhenEmpty: Bool = true
    var hint: String
    var tint: Color = .green
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @ViewBuilder var leadingAction: () -> LeadingAction
    @ViewBuilder var trailingAction: () -> TrailingAction
    @ViewBuilder var mainAction: () -> MainAction
    /// View Properties
    @State private var isHighligting: Bool = false
    var body: some View {
        let mainLayout = isFocused ? AnyLayout(ZStackLayout(alignment: .bottomTrailing)) : AnyLayout(HStackLayout(alignment: .bottom, spacing: 10))
        let shape = RoundedRectangle(cornerRadius: isFocused ? 25 : 30)
        
        ZStack {
            mainLayout {
                let subLayout = isFocused ? AnyLayout(VStackLayout(alignment: .trailing, spacing: 20)) : AnyLayout(ZStackLayout(alignment: .trailing))
                
                subLayout {
                    TextField(hint, text: $text, axis: .vertical)
                        .lineLimit(isFocused ? 5 : 1)
                        .focused(_isFocused)
                        .mask {
                            Rectangle()
                                .padding(.trailing, isFocused ? 0 : 40)
                        }
                    
                    /// Trailing & Leading Action View
                    HStack(spacing: 10) {
                        /// Leading Actions
                        HStack(spacing: 10) {
                            ForEach(subviews: leadingAction()) { subview in
                                /// Each button max size is 35
                                subview
                                    .frame(width: 35, height: 35)
                                    .contentShape(.rect)
                            }
                        }
                        .compositingGroup()
                        /// Disabling interaction and hiding when not focused
                        .allowsHitTesting(isFocused)
                        .blur(radius: isFocused ? 0 : 6)
                        .opacity(isFocused ? 1 : 0)
                        
                        Spacer(minLength: 0)
                        
                        /// Trailing Action
                        /// Trailing Action contains of only one button!
                        trailingAction()
                            .frame(width: 35, height: 35)
                            .contentShape(.rect)
                    }
                }
                .frame(height: isFocused ? nil : 55)
                .padding(.leading, 15)
                .padding(.trailing, isFocused ? 15 : 10)
                .padding(.bottom, isFocused ? 10 : 0)
                .padding(.top, isFocused ? 20 : 0)
                .background {
                    ZStack {
                        HighlightingBackgroundView()
                        
                        shape
                            .fill(.bar)
                        /// Applying Shadows for more visiblity
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: -5)
                    }
                }
                
                /// Main Action Button
                /// Main Action is also a single button view with a matching size of 50
                mainAction()
                    .frame(width: 50, height: 50)
                    .clipShape(.circle)
                    .background {
                        Circle()
                            .fill(.bar)
                            /// Applying Shadows for more visiblity
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                            .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: -5)
                    }
                    .visualEffect { [isFocused] content, proxy in
                        content
                            .offset(x: isFocused ? (proxy.size.width + 30) : 0)
                    }
            }
        }
        .geometryGroup()
        .animation(.easeOut(duration: animationDuration), value: isFocused)
    }
    
    @ViewBuilder
    private func HighlightingBackgroundView() -> some View {
        ZStack {
            let shape = RoundedRectangle(cornerRadius: isFocused ? 25 : 30)
            
            if !isFocused && text.isEmpty && highlightWhenEmpty {
                shape
                    .stroke(
                        tint.gradient,
                        style: .init(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
                    .mask {
                        /// Increase the count of this to increase the gradient style masking effect on the highlighting effect!
                        let clearColors: [Color] = Array(repeating: .clear, count: 3)
                        
                        shape
                            .fill(AngularGradient(
                                colors: clearColors + [Color.white] + clearColors,
                                center: .center,
                                angle: .init(degrees: isHighligting ? 360 : 0)
                            ))
                    }
                    .padding(-1.5)
                    .blur(radius: 1.5)
                    .onAppear {
                        /// Infinite Looping Effect
                        withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                            isHighligting = true
                        }
                    }
                    .onDisappear {
                        /// Disabling the effect
                        isHighligting = false
                    }
                    .transition(.blurReplace)
            }
        }
    }
    
    var animationDuration: CGFloat {
        /// iOS 26 keyboard appears more faster than the older ones!
        if #available(iOS 26, *) {
            return 0.22
        } else {
            return 0.33
        }
    }
}

#Preview {
    ContentView()
}
