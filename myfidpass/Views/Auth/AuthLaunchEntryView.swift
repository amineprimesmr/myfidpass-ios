//
//  AuthLaunchEntryView.swift
//  myfidpass
//
//  Écran d'entrée auth : visuel plein écran + CTA distincts création / connexion.
//

import SwiftUI

struct AuthLaunchEntryView: View {
    let onCreateAccount: () -> Void
    let onSignIn: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var contentVisible = false

    var body: some View {
        GeometryReader { geo in
            let split = AuthResponsiveLayout.useSplitAuthPanel(
                width: geo.size.width,
                horizontalSizeClass: horizontalSizeClass
            )
            Group {
                if split {
                    splitLayout(size: geo.size)
                } else {
                    stackedFullBleedLayout(size: geo.size)
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                contentVisible = true
            }
        }
    }

    // MARK: - Split (iPad, largeur importante)

    private func splitLayout(size: CGSize) -> some View {
        let heroW = size.width * 0.56
        let panelW = size.width - heroW
        return HStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                heroBackgroundImage
                    .scaleEffect(contentVisible ? 1 : 1.02)
                    .opacity(contentVisible ? 1 : 0.82)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.28),
                        Color.white.opacity(0.75),
                    ],
                    startPoint: UnitPoint(x: 0.5, y: 0.55),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .frame(width: heroW, height: size.height)
            .clipped()

            ctasVStack(maxContentWidth: AuthResponsiveLayout.authFormMaxWidth(containerWidth: panelW))
                .frame(width: panelW, height: size.height)
                .frame(maxHeight: .infinity)
                .background(Color.white)
        }
        .ignoresSafeArea()
    }

    // MARK: - Compact (iPhone portrait)

    private func stackedFullBleedLayout(size: CGSize) -> some View {
        ZStack(alignment: .bottom) {
            heroBackgroundImage
                // Sur grands téléphones, léger zoom pour éviter visuel trop « petit » si l’asset contient un mockup.
                .scaleEffect(contentVisible ? 1.04 : 1.06)
                .opacity(contentVisible ? 1 : 0.82)

            LinearGradient(
                colors: [
                    Color.white.opacity(0),
                    Color.white.opacity(0.35),
                    Color.white.opacity(0.92),
                    Color.white,
                ],
                startPoint: UnitPoint(x: 0.5, y: 0.62),
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            ctasVStack(maxContentWidth: AuthResponsiveLayout.authFormMaxWidth(containerWidth: size.width))
                .padding(.horizontal, 16)
                .padding(.bottom, 52)
        }
        .ignoresSafeArea()
    }

    private var heroBackgroundImage: some View {
        Image("5")
            .resizable()
            .scaledToFill()
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
    }

    private func ctasVStack(maxContentWidth: CGFloat) -> some View {
        VStack(spacing: 12) {
            Button {
                onCreateAccount()
            } label: {
                Text("COMMENCER")
                    .font(.system(size: 22, weight: .black))
                    .minimumScaleFactor(0.82)
                    .lineLimit(1)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .contentShape(Rectangle())
            }
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 22)
            .animation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.06), value: contentVisible)

            Button {
                onSignIn()
            } label: {
                Text("Se connecter")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.78))
                    .underline(true, color: .black.opacity(0.35))
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.bottom, 2)
            .opacity(contentVisible ? 1 : 0)
            .offset(y: contentVisible ? 0 : 26)
            .animation(.spring(response: 0.46, dampingFraction: 0.88).delay(0.1), value: contentVisible)
        }
        .frame(maxWidth: maxContentWidth)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AuthLaunchEntryView(onCreateAccount: {}, onSignIn: {})
        .environmentObject(AuthService())
}
