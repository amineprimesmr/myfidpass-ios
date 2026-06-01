//
//  AuthWelcomeVideoView.swift
//  myfidpass
//
//  Illustration welcome (Assets: welcome.imageset).
//

import SwiftUI

struct AuthWelcomeImageView: View {
    var body: some View {
        ZStack(alignment: .top) {
            AppTheme.Colors.background

            Image("welcome")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [
                        AppTheme.Colors.background.opacity(0),
                        AppTheme.Colors.background,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 44)
            }
            .allowsHitTesting(false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .allowsHitTesting(false)
    }
}
