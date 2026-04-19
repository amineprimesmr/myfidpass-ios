//
//  BodyScanSilhouetteGuideView.swift
//  Process
//
//  Vue de guidage avec silhouette et instructions
//

import SwiftUI

struct BodyScanSilhouetteGuideView: View {
    let instructionText: String
    let showSilhouette: Bool
    let isBodyDetected: Bool

    var body: some View {
        VStack(spacing: 24) {
            // Instructions
            Text(instructionText)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 40)

            Spacer()

            // Silhouette guide (affichée dans la vue caméra)
            if showSilhouette {
                Text("Aligne-toi avec la silhouette")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isBodyDetected ? .green : .white.opacity(0.7))
                    .padding(.bottom, 60)
                    .transition(.opacity)
            }
        }
    }
}
