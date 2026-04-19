//
//  WeeklyStatRow.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct WeeklyStatRow: View {
    let title: String
    let value: String
    let unit: String
    let progress: Double
    let delay: Double

    @State private var animatedValue: Double = 0
    @State private var barProgress: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Spacer()

                Text("\(String(format: "%.0f", animatedValue)) \(unit)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            // Barre de progression plus fine
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Fond de la barre
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    // Barre de progression animée
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.8))
                        .frame(width: geometry.size.width * barProgress, height: 4)
                        .animation(.easeInOut(duration: 1.2).delay(delay), value: barProgress)
                }
            }
            .frame(height: 4)
        }
        .onAppear {
            // Animer la valeur numérique
            withAnimation(.easeInOut(duration: 1.8).delay(delay)) {
                animatedValue = Double(value) ?? 0
            }

            // Animer la barre de progression
            withAnimation(.easeInOut(duration: 1.2).delay(delay)) {
                barProgress = progress
            }
}
}
}
