//
//  DataAnimationRow.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct DataAnimationRow: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let delay: Double
    let isVisible: Bool

    @State private var animatedValue: Double = 0
    @State private var barProgress: Double = 0

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)

                Spacer()

                Text("\(String(format: "%.0f", animatedValue)) \(unit)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
            }

            // Barre de progression
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond de la barre
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 8)

                    // Barre de progression animée
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: geometry.size.width * barProgress, height: 8)
                        .animation(.easeInOut(duration: 1.0).delay(delay), value: barProgress)
                }
            }
            .frame(height: 8)
        }
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(.easeInOut(duration: 0.5).delay(delay), value: isVisible)
        .onAppear {
            if isVisible {
                // Animer la valeur numérique
                withAnimation(.easeInOut(duration: 1.5).delay(delay)) {
                    animatedValue = Double(value) ?? 0
                }

                // Animer la barre de progression
                withAnimation(.easeInOut(duration: 1.0).delay(delay)) {
                    barProgress = progress
                }
}
}
}
}
