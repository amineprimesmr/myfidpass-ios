//
//  CustomCarousel.swift
//  iOS26LSCarousel
//
//  Created by Balaji Venkatesh on 04/09/25.
//  Copié à l'identique dans myfidpass pour la galerie de designs.
//

import SwiftUI

/// Sample Model (iOS26LSCarousel)
struct Wallpaper: Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var image: String
}

struct CustomCarousel: View {
    var wallpapers: [Wallpaper]
    var onSelect: (Wallpaper) -> ()
    /// View Properties
    @State private var offsetX: CGFloat = 0
    @State private var selectedWallpaper: String?
    @State private var reflectionScrollPosition: ScrollPosition = .init()
    var body: some View {
        GeometryReader {
            let size = $0.size
            /// You can customize it as per your needs!
            let cardWidth: CGFloat = 273
            let cardHeight = min(max((size.height - 180), 0), 700)
            let horizontalPadding = (size.width - cardWidth) / 2
            
            ZStack {
                Rectangle()
                    .fill(backgroundColor)
                    .ignoresSafeArea()
                
                if size != .zero {
                    VStack(spacing: 15) {
                        LabelView(size: size, cardWidth: cardWidth)
                        
                        /// Custom Snap Carousel Using ScrollView
                        ScrollView(.horizontal) {
                            ReusableWallpaperStackView(cardWidth: cardWidth, cardHeight: cardHeight)
                                .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                        .scrollPosition(id: $selectedWallpaper, anchor: .center)
                        /// Making it to start and end at the center
                        .safeAreaPadding(.horizontal, horizontalPadding)
                        .frame(height: cardHeight)
                        .onScrollGeometryChange(for: CGFloat.self) {
                            $0.contentOffset.x + $0.contentInsets.leading
                        } action: { oldValue, newValue in
                            offsetX = newValue
                            reflectionScrollPosition.scrollTo(x: newValue)
                        }
                        
                        BottomBar(size: size, cardWidth: cardWidth, cardHeight: cardHeight)
                    }
                }
            }
        }
        .onAppear {
            guard selectedWallpaper == nil else { return }
            selectedWallpaper = wallpapers.first?.id
        }
        .onChange(of: selectedWallpaper) { oldValue, newValue in
            if let newValue, let wallpaper = wallpapers.first(where: { $0.id == newValue }) {
                onSelect(wallpaper)
            }
        }
    }
    
    /// Reusable Wallpaper StackView
    @ViewBuilder
    func ReusableWallpaperStackView(cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        LazyHStack(spacing: 15) {
            ForEach(wallpapers) { wallpaper in
                Image(wallpaper.image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(.rect(cornerRadius: 40))
            }
        }
    }
    
    /// Sliding Label View!
    @ViewBuilder
    func LabelView(size: CGSize, cardWidth: CGFloat) -> some View {
        /// 15: Spacing in HStack
        let progress = offsetX / (cardWidth + 15)
        let slideOffset = progress * size.width
        
        HStack(spacing: 0) {
            ForEach(wallpapers) { wallpaper in
                Text(wallpaper.title)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(width: size.width)
            }
        }
        .offset(x: -slideOffset)
        .frame(width: size.width, height: 50, alignment: .leading)
        .foregroundStyle(.white)
    }
    
    /// Bottom Bar with Light Reflection Effect
    @ViewBuilder
    func BottomBar(size: CGSize, cardWidth: CGFloat, cardHeight: CGFloat) -> some View {
        ZStack {
            let horizontalPadding = (size.width - cardWidth) / 2
            
            let bottombarLayout = HStack(spacing: 10) {
                Capsule()
                    .fill(backgroundColor)
                    .frame(width: 220, height: 55)
                
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 55, height: 55)
            }
            
            ScrollView(.horizontal) {
                ReusableWallpaperStackView(cardWidth: cardWidth, cardHeight: cardHeight)
            }
            .safeAreaPadding(.horizontal, horizontalPadding)
            .scrollPosition($reflectionScrollPosition)
            .scrollIndicators(.hidden)
            .frame(width: size.width, height: size.height, alignment: .leading)
            /// Smoothing out with blur
            .compositingGroup()
            .blur(radius: 10)
            .frame(height: 60, alignment: .bottom)
            .offset(y: 130)
            .mask {
                bottombarLayout
                    /// Optional Gradient Mask!
                    .mask {
                        LinearGradient(colors: [
                            .white,
                            .white.opacity(0.5),
                            .clear,
                            .clear
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    /// Customize it as per your needs!
                    .offset(x: 33, y: -0.6)
            }
            .overlay {
                bottombarLayout
                    .offset(x: 33)
            }
            .allowsHitTesting(false)
            
            HStack(spacing: 10) {
                Button {
                    print("Customize")
                } label: {
                    Text("Customize")
                        .fontWeight(.medium)
                        .frame(width: 220, height: 55)
                        .buttonBackground()
                }
                
                Button {
                    print("Add")
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(width: 55, height: 55)
                        .buttonBackground()
                }
            }
            .foregroundStyle(.white)
            /// Making the Customize button to become the center
            /// 55 + 10 = 65 / 2 => 32.5!
            .offset(x: 33)
        }
        .frame(height: 60)
        .padding(.top, 10)
    }
    
    var backgroundColor: Color {
        return .black
    }
}

/// Custom Background View
fileprivate extension View {
    @ViewBuilder
    func buttonBackground() -> some View {
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
    CustomCarousel(wallpapers: [
        .init(title: "iOS 26", image: "1"),
        .init(title: "The Lake", image: "2"),
    ], onSelect: { _ in })
}
