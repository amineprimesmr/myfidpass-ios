//
//  AuthLegalFooterView.swift
//  myfidpass
//
//  Liens CGU et confidentialité (Guideline 3.1.2 — accessibles depuis l’onboarding auth).
//

import SwiftUI

struct AuthLegalFooterView: View {
    @State private var safariURL: URL?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Button("Politique de confidentialité") {
                    safariURL = LegalURLs.privacyPolicy
                }
                Text("·")
                    .foregroundStyle(Color.black.opacity(0.35))
                Button("Conditions d’utilisation (EULA)") {
                    safariURL = LegalURLs.termsOfUse
                }
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.5))
            .tint(Color.black.opacity(0.62))
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                InAppSafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
