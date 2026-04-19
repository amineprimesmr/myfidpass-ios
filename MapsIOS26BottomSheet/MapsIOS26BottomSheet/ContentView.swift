//
//  ContentView.swift
//  MapsIOS26BottomSheet
//
//  Created by Balaji Venkatesh on 26/06/25.
//

import SwiftUI
import MapKit

/// Apple Park Coordinates
/// Apple Park Coordinates
extension MKCoordinateRegion {
    static let applePark = MKCoordinateRegion(center: .init(latitude: 37.3346, longitude: -122.0090), latitudinalMeters: 1000, longitudinalMeters: 1000)
}

struct ContentView: View {
    /// Bottom Sheet Properties
    @State private var showBottomSheet: Bool = true
    @State private var sheetDetent: PresentationDetent = .height(80)
    @State private var sheetHeight: CGFloat = 0
    @State private var animationDuration: CGFloat = 0
    @State private var toolbarOpacity: CGFloat = 1
    @State private var safeAreaBottomInset: CGFloat = 0
    var body: some View {
        Map(initialPosition: .region(.applePark))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Rectangle()
                    .foregroundStyle(.clear)
                    .frame(height: 80)
            }
            .sheet(isPresented: $showBottomSheet) {
                BottomSheetView(sheetDetent: $sheetDetent)
                    .presentationDetents([.height(80), .height(350), .large], selection: $sheetDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationCornerRadius(isiOS26 ? nil : 30)
                    .presentationBackground {
                        if !isiOS26 {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onGeometryChange(for: CGFloat.self) {
                        max(min($0.size.height, 400 + safeAreaBottomInset), 0)
                    } action: { oldValue, newValue in
                        /// Limiting the offset to 300, so that opacity effect will be visible
                        sheetHeight = min(newValue, 350 + safeAreaBottomInset)
                        
                        /// Calulating Opacity
                        let progress = max(min((newValue - (350 + safeAreaBottomInset)) / 50, 1), 0)
                        toolbarOpacity = 1 - progress
                        
                        /// Calculating Animation Duration
                        let diff = abs(newValue - oldValue)
                        let duration = max(min(diff / 100, maxAnimationDuration), 0)
                        animationDuration = duration
                    }
                    .ignoresSafeArea()
                    .interactiveDismissDisabled()
            }
            .overlay(alignment: .bottomTrailing) {
                Group {
                    if #available(iOS 26, *) {
                        BottomFloatinToolBar()
                            .glassEffect(.regular, in: .capsule)
                            .opacity(toolbarOpacity)
                            .offset(y: -sheetHeight)
                    } else {
                        BottomFloatinToolBar()
                            .background(.ultraThinMaterial, in: .capsule)
                            .opacity(toolbarOpacity)
                            .offset(y: -sheetHeight)
                    }
                }
                .animation(animation, value: sheetHeight)
                .animation(animation, value: toolbarOpacity)
                .padding(.trailing, 15)
                .offset(y: safeAreaBottomInset - 10)
            }
            .overlay(alignment: .topLeading) {
                Group {
                    if #available(iOS 26, *) {
                        HStack(spacing: 2) {
                            Image(systemName: "cloud.fill")
                            Text("28°")
                        }
                        .padding(8)
                        .glassEffect(in: .rect(cornerRadius: 12))
                    } else {
                        HStack(spacing: 2) {
                            Image(systemName: "cloud.fill")
                            Text("28°")
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: .rect(cornerRadius: 12))
                    }
                }
                .padding([.leading, .top], 15)
                .opacity(toolbarOpacity)
                .animation(animation, value: toolbarOpacity)
            }
            .onGeometryChange(for: CGFloat.self, of: {
                $0.safeAreaInsets.bottom
            }, action: { newValue in
                safeAreaBottomInset = newValue
            })
    }
    
    /// Bottom Floating View
    @ViewBuilder
    func BottomFloatinToolBar() -> some View {
        VStack(spacing: 35) {
            Button {
                
            } label: {
                Image(systemName: "car.fill")
            }
            
            Button {
                
            } label: {
                Image(systemName: "location")
            }
        }
        .font(.title3)
        .foregroundStyle(Color.primary)
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
    }
    
    var maxAnimationDuration: CGFloat {
        return isiOS26 ? 0.25 : 0.18
    }
    
    var animation: Animation {
        .interpolatingSpring(duration: animationDuration, bounce: 0, initialVelocity: 0)
    }
}

#Preview {
    ContentView()
}

extension View {
    var isiOS26: Bool {
        if #available(iOS 26, *) {
            return true
        }
        
        return false
    }
}
