//
//  iOS26StyleOnBoarding.swift
//  iOSStyleOnBoarding
//
//  Created by Balaji Venkatesh on 19/02/26.
//

import SwiftUI

struct iOS26StyleOnBoarding: View {
    var tint: Color = .blue
    var hideBezels: Bool = false
    /// true = fond blanc et texte sombre (charte graphique / DA)
    var isLightTheme: Bool = false
    var items: [Item]
    var onComplete: () -> ()
    /// View Properties
    @State private var currentIndex: Int = 0
    @State private var screenshotSize: CGSize = .zero

    private var backgroundColor: Color { isLightTheme ? .white : .black }
    private var textPrimaryColor: Color { isLightTheme ? Color(white: 0.06) : .white }
    private var textSecondaryColor: Color { isLightTheme ? Color(white: 0.35) : .white.opacity(0.8) }
    private var indicatorColor: Color { isLightTheme ? Color(white: 0.2) : .white }
    private var indicatorInactiveOpacity: Double { isLightTheme ? 0.35 : 0.4 }

    var body: some View {
        ZStack(alignment: .bottom) {
            backgroundColor
                .ignoresSafeArea()
            ScreenshotView()
                .compositingGroup()
                .scaleEffect(
                    items[currentIndex].zoomScale,
                    anchor: items[currentIndex].zoomAnchor
                )
                .padding(.top, 35)
                .padding(.horizontal, 30)
                .padding(.bottom, 220)
            
            VStack(spacing: 10) {
                TextContentView()
                IndicatorView()
                ContinueButton()
            }
            .padding(.top, 20)
            .padding(.horizontal, 15)
            .padding(.bottom, 28)
            .frame(height: 210)
            .background {
                VariableGlassBlur(15)
            }
            
            BackButton()
        }
        .preferredColorScheme(isLightTheme ? .light : .dark)
    }
    
    /// Screenshot View
    @ViewBuilder
    func ScreenshotView() -> some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)
        
        GeometryReader {
            let size = $0.size
            
            Rectangle()
                .fill(Color.black)
            
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        
                        Group {
                            if let screenshot = item.screenshot {
                                Image(uiImage: screenshot)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .onGeometryChange(for: CGSize.self) {
                                        $0.size
                                    } action: { newValue in
                                        guard index == 0 && screenshotSize == .zero else { return }
                                        screenshotSize = newValue
                                    }
                                    .clipShape(shape)
                            } else {
                                Rectangle()
                                    .fill(Color.black)
                            }
                        }
                        .frame(width: size.width, height: size.height)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollDisabled(true)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: .init(get: {
                return currentIndex
            }, set: { _ in }))
        }
        .clipShape(shape)
        .overlay {
            if screenshotSize != .zero && !hideBezels {
                /// Cadre iPhone (aligné sur iOSStyleOnBoarding référence)
                ZStack {
                    shape
                        .stroke(.white, lineWidth: 6)
                    shape
                        .stroke(.black, lineWidth: 4)
                    shape
                        .stroke(.black, lineWidth: 6)
                        .padding(4)
                }
                .padding(-7)
            }
        }
        .frame(
            maxWidth: screenshotSize.width == 0 ? nil : screenshotSize.width,
            maxHeight: screenshotSize.height == 0 ? nil : screenshotSize.height
        )
        .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /// Text Content View
    @ViewBuilder
    func TextContentView() -> some View {
        GeometryReader {
            let size = $0.size
            
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        let item = items[index]
                        let isActive = currentIndex == index
                        
                        VStack(spacing: 6) {
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .foregroundStyle(textPrimaryColor)
                            
                            Text(item.subtitle)
                                .font(.callout)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(textSecondaryColor)
                        }
                        .frame(width: size.width)
                        .compositingGroup()
                        /// Only The current Item is visible others are blurred out!
                        .blur(radius: isActive ? 0 : 30)
                        .opacity(isActive ? 1 : 0)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(true)
            .scrollTargetBehavior(.paging)
            .scrollClipDisabled()
            .scrollPosition(id: .init(get: {
                return currentIndex
            }, set: { _ in }))
        }
    }
    
    /// Indicator View
    @ViewBuilder
    func IndicatorView() -> some View {
        HStack(spacing: 6) {
            ForEach(items.indices, id: \.self) { index in
                let isActive: Bool = currentIndex == index
                
                Capsule()
                    .fill(indicatorColor.opacity(isActive ? 1 : indicatorInactiveOpacity))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
        .padding(.bottom, 5)
    }
    
    /// Bottom Continue Button
    @ViewBuilder
    func ContinueButton() -> some View {
        Button {
            if currentIndex == items.count - 1 {
                onComplete()
            }
            
            withAnimation(animation) {
                currentIndex = min(currentIndex + 1, items.count - 1)
            }
        } label: {
            Text(currentIndex == items.count - 1 ? "Commencer" : "Continuer")
                .fontWeight(.medium)
                .contentTransition(.numericText())
                .padding(.vertical, 6)
        }
        .tint(tint)
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
        .padding(.horizontal, 30)
    }
    
    /// Back Button
    @ViewBuilder
    func BackButton() -> some View {
        Button {
            withAnimation(animation) {
                currentIndex = max(currentIndex - 1, 0)
            }
        } label: {
            Image(systemName: "chevron.left")
                .font(.title3)
                .foregroundStyle(isLightTheme ? textPrimaryColor : .white)
                .frame(width: 20, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.leading, 15)
        .padding(.top, 5)
    }
    
    /// Variable Glass Effect Blur
    @ViewBuilder
    func VariableGlassBlur(_ radius: CGFloat) -> some View {
        let glassTint: Color = isLightTheme ? .white.opacity(0.6) : .black.opacity(0.5)
        Rectangle()
            .fill(glassTint)
            .glassEffect(.clear, in: .rect)
            .blur(radius: radius)
            .padding([.horizontal, .bottom], -radius * 2)
            .padding(.top, -radius / 2)
            /// Only Visible for scaled screenshots!
            .opacity(items[currentIndex].zoomScale > 1 ? 1 : 0)
            .ignoresSafeArea()
    }
    
    var deviceCornerRadius: CGFloat {
        if let imageSize = items.first?.screenshot?.size {
            let ratio = screenshotSize.height / imageSize.height
            let actualCornerRadius: CGFloat = 180
            return actualCornerRadius * ratio
        }
        
        return 0
    }
    
    struct Item: Identifiable, Hashable {
        var id: Int
        var title: String
        var subtitle: String
        var screenshot: UIImage?
        var zoomScale: CGFloat = 1
        var zoomAnchor: UnitPoint = .center
    }
    
    /// Customize it according to your needs!
    var animation: Animation {
        .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
    }
}

#Preview {
    iOS26StyleOnBoarding(tint: .blue, hideBezels: false, items: [
        .init(id: 0, title: "Preview", subtitle: "Subtitle", screenshot: nil)
    ], onComplete: {})
}
