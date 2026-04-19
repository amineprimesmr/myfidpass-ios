//
//  LegalDocumentLinksView.swift
//  myfidpass
//
//  Liens CGU + confidentialité — SFSafariViewController (Guideline 4, transparence compte).
//

import SwiftUI

struct LegalDocumentLinksView: View {
    @State private var safariURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Informations légales")
                .font(AppTheme.Fonts.caption())
                .fontWeight(.semibold)
                .foregroundStyle(AppTheme.Colors.textSecondary)

            HStack(spacing: 16) {
                Button("Conditions d’utilisation") {
                    safariURL = LegalURLs.termsOfUse
                }
                Button("Confidentialité") {
                    safariURL = LegalURLs.privacyPolicy
                }
            }
            .font(AppTheme.Fonts.caption())
            .foregroundStyle(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
