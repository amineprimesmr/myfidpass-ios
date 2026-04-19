//
//  BodySilhouetteGuideView.swift
//
//  Vue avec silhouette guide réaliste (pas ovale) pour chaque pose
//

import SwiftUI

enum BodyPose: String {
    case front = "front"      // Face avant
    case side = "side"        // Profil
    case back = "back"        // Dos
}

struct BodySilhouetteGuideView: View {
    let pose: BodyPose
    let isBodyDetected: Bool
    let isPoseOptimal: Bool
    let instructionText: String

    private var assetName: String {
        switch pose {
        case .front: return "bodySilhouetteFront"
        case .side: return "bodySilhouetteSide"
        case .back: return "bodySilhouetteBack"
        }
    }

    private var silhouetteColor: Color {
        isPoseOptimal ? .green : (isBodyDetected ? .blue : .white.opacity(0.7))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Masque sombre autour (moins opaque pour plus de visibilité)
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Zone de scan (silhouette SVG réaliste - PLUS GRANDE et PLUS VISIBLE)
                ZStack {
                    // ✅ Contour lumineux pour rendre la silhouette très visible
                    Image(assetName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(silhouetteColor.opacity(0.3))
                        .scaledToFit()
                        .frame(
                            width: geometry.size.width * 0.87,
                            height: geometry.size.height * 0.87
                        )
                        .blur(radius: 8)

                    // ✅ Silhouette principale (bien visible)
                    Image(assetName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(silhouetteColor)
                        .scaledToFit()
                        .frame(
                            width: geometry.size.width * 0.85,  // ✅ Grande et visible
                            height: geometry.size.height * 0.85
                        )
                        .shadow(color: silhouetteColor.opacity(0.8), radius: 15, x: 0, y: 0)

                    // ✅ Contour pour plus de visibilité
                    Image(assetName)
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.white.opacity(0.2))
                        .scaledToFit()
                        .frame(
                            width: geometry.size.width * 0.86,
                            height: geometry.size.height * 0.86
                        )
                        .blendMode(.overlay)
                }
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height / 2
                )
            }
            .compositingGroup()
        }
    }
}
