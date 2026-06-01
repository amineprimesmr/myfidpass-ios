//
//  AuthLaunchEntryView.swift
//  myfidpass
//
//  Welcome : vidéo en haut, boutons en bas.
//

import SwiftUI

struct AuthLaunchEntryView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                phoneLayout
            }
        }
        .background(AppTheme.Colors.background)
        .preferredColorScheme(.light)
    }

    // MARK: - iPhone

    private var phoneLayout: some View {
        VStack(spacing: 0) {
            AuthWelcomeImageView()
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            bottomActions
        }
    }

    // MARK: - iPad

    private var regularLayout: some View {
        HStack(spacing: 0) {
            AuthWelcomeImageView()
                .padding(.top, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack {
                Spacer(minLength: 0)
                bottomActions
                    .frame(maxWidth: 400)
                Spacer(minLength: 0)
            }
            .frame(width: 380)
            .background(AppTheme.Colors.background)
        }
    }

    // MARK: - Boutons

    private var bottomActions: some View {
        VStack(spacing: 24) {
            Button(action: onCreateAccount) {
                Text("COMMENCER")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: MyfidpassOnboardingConstants.primaryCTAHeight)
            }
            .buttonBorderShape(.roundedRectangle(radius: 50))
            .liquidGlassButtonAppearance(.adaptive, cornerRadius: 50)
            .contentShape(RoundedRectangle(cornerRadius: 50, style: .continuous))

            Button(action: onSignIn) {
                Text("Se connecter")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.78))
                    .underline(true, color: .black.opacity(0.35))
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, MyfidpassOnboardingConstants.primaryCTAHorizontalPaddingCompact)
        .padding(.top, 12)
        .padding(.bottom, MyfidpassOnboardingConstants.primaryCTABottomInset)
        .background(AppTheme.Colors.background)
    }
}

#Preview {
    AuthLaunchEntryView(onCreateAccount: {}, onSignIn: {})
        .environmentObject(AuthService())
}
