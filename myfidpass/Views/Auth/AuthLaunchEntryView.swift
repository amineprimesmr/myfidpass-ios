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
    @State private var contentVisible = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Image("5")
                .resizable()
                .scaledToFill()
                .scaleEffect(contentVisible ? 1 : 1.02)
                .opacity(contentVisible ? 1 : 0.82)
                .ignoresSafeArea()

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
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 12) {
                Button {
                    onCreateAccount()
                } label: {
                    Text("COMMENCER")
                        .font(.system(size: 22, weight: .heavy))
                        .minimumScaleFactor(0.82)
                        .lineLimit(1)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .contentShape(Rectangle())
                }
                .buttonBorderShape(.roundedRectangle(radius: 27))
                .controlSize(.large)
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 27)
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
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 52)
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                contentVisible = true
            }
        }
    }
}

#Preview {
    AuthLaunchEntryView(onCreateAccount: {}, onSignIn: {})
        .environmentObject(AuthService())
}
