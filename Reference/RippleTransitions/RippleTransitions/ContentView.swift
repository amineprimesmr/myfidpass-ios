//
//  ContentView.swift
//  RippleTransitions
//
//  Created by Balaji Venkatesh on 20/02/25.
//

import SwiftUI

struct ContentView: View {
    /// View Properties
    @State private var count: Int = 0
    @State private var rippleLocation: CGPoint = .zero
    @State private var shaderTrigger: Bool = false
    
    @State private var showOverlayView: Bool = false
    @State private var overlayRippleLocation: CGPoint = .zero
    var body: some View {
        NavigationStack {
            VStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Usage:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    
                    Text(".transition(.ripple(location))")
                        .monospaced()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(15)
                        .background(.gray.opacity(0.15), in: .rect(cornerRadius: 10))
                }
                
                GeometryReader {
                    let size = $0.size
                    
                    ForEach(0...1, id: \.self) { index in
                        if count == index {
                            ImageView(index, size: size)
                                .transition(.ripple(location: rippleLocation))
                        }
                    }
                }
                .frame(width: 350, height: 500)
                .rippleShaderEffect(location: rippleLocation, trigger: shaderTrigger, duration: 1)
                .coordinateSpace(.named("VIEW"))
                .onTapGesture(count: 1, coordinateSpace: .named("VIEW")) { location in
                    rippleLocation = location
                    withAnimation(.linear(duration: 1)) {
                        count = (count + 1) % 2
                    }
                    
                    shaderTrigger.toggle()
                }
                .padding(15)
                
                Spacer(minLength: 0)
            }
            .overlay(alignment: .bottomTrailing) {
                GeometryReader {
                    let frame = $0.frame(in: .global)
                    
                    Button {
                        overlayRippleLocation = .init(x: frame.midX, y: frame.midY)
                        
                        withAnimation(.linear(duration: 0.8)) {
                            showOverlayView = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(.indigo.gradient, in: .circle)
                            .contentShape(.rect)
                    }
                }
                .frame(width: 50, height: 50)
            }
            .padding(15)
            .navigationTitle("Ripple Transition")
        }
        .overlay {
            if showOverlayView {
                ZStack {
                    Rectangle()
                        .fill(.indigo.gradient)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.55)) {
                                showOverlayView = false
                            }
                        }
                    
                    Text("Tap anywhere to dismiss!")
                        .monospaced()
                        .foregroundStyle(.white)
                }
                .transition(.reverseRipple(location: overlayRippleLocation))
            }
        }
    }
    
    /// Image View
    private func ImageView(_ index: Int, size: CGSize) -> some View {
        Image("Pic \(index + 1)")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipShape(.rect(cornerRadius: 30))
    }
}

#Preview {
    ContentView()
}

struct RippleShaderConfig {
    var amplitude: Double = 22
    var frequency: Double = 22
    var decay: Double = 7
    /// Adjust speed as per your animation duration
    var speed: Double = 1200
}

extension View {
    func rippleShaderEffect(location: CGPoint, trigger: Bool, duration: CGFloat, config: RippleShaderConfig = .init()) -> some View {
        self
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: trigger) { content, value in
                let shader = ShaderLibrary.Ripple(
                    .float2(location),
                    .float(value),
                    .float(config.amplitude),
                    .float(config.frequency),
                    .float(config.decay),
                    .float(config.speed)
                )
                
                content
                    .layerEffect(shader, maxSampleOffset: .init(width: config.amplitude, height: config.amplitude))
                
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: duration)
            }
    }
}
