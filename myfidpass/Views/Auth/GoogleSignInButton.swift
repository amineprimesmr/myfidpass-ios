//
//  GoogleSignInButton.swift
//  myfidpass
//
//  Bouton « Continuer avec Google » : logo officiel, contraste, états pression / chargement (UX).
//

import SwiftUI

// Couleurs proches des guidelines Google Sign-In (bordure #747775, texte #1F1F1F sur fond clair).
private enum GoogleSignInStyleTokens {
    static let borderLight = Color(red: 0.455, green: 0.467, blue: 0.482)
    static let borderDark = Color.white.opacity(0.22)
    static let labelLight = Color(red: 0.12, green: 0.12, blue: 0.12)
    static let labelDark = Color.primary
    static let minHeight: CGFloat = 52
    static let logoSize: CGFloat = 22
}

/// Style de pression : léger scale + opacité (feedback tactile géré par le système sur le bouton).
private struct GoogleSignInButtonVisualStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GoogleSignInButton: View {
    var isLoading: Bool
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var fillColor: Color {
        Color(uiColor: UIColor { tc in
            switch tc.userInterfaceStyle {
            case .dark:
                return UIColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1)
            default:
                return UIColor.systemBackground
            }
        })
    }

    private var borderColor: Color {
        colorScheme == .dark ? GoogleSignInStyleTokens.borderDark : GoogleSignInStyleTokens.borderLight
    }

    private var labelColor: Color {
        colorScheme == .dark ? GoogleSignInStyleTokens.labelDark : GoogleSignInStyleTokens.labelLight
    }

    private var titleFont: Font {
        .system(size: 16, weight: .medium, design: .default)
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .tint(labelColor)
                        .scaleEffect(0.95)
                    Text("Connexion en cours…")
                        .font(titleFont)
                        .foregroundStyle(labelColor)
                } else {
                    Image("GoogleGLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: GoogleSignInStyleTokens.logoSize, height: GoogleSignInStyleTokens.logoSize)
                        .accessibilityHidden(true)
                    Text("Continuer avec Google")
                        .font(titleFont)
                        .foregroundStyle(labelColor)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: GoogleSignInStyleTokens.minHeight)
            .padding(.horizontal, 18)
            .background(fillColor, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: colorScheme == .dark ? 1 : 1.25)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06),
                radius: colorScheme == .dark ? 6 : 4,
                x: 0,
                y: colorScheme == .dark ? 2 : 1
            )
        }
        .buttonStyle(GoogleSignInButtonVisualStyle())
        .disabled(isLoading)
        .accessibilityLabel(isLoading ? "Connexion Google en cours" : "Continuer avec Google")
        .accessibilityHint("Ouvre une fenêtre sécurisée pour vous connecter avec votre compte Google.")
    }
}
