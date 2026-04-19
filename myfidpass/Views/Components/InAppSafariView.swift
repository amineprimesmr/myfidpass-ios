//
//  InAppSafariView.swift
//  myfidpass
//
//  Safari View Controller embarqué (Guideline 4 — pas de Safari externe pour le contenu web lié au compte / légal).
//

import SafariServices
import SwiftUI

/// Feuille modale `SFSafariViewController` (URL + barre d’adresse pour la confiance utilisateur).
struct InAppSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let vc = SFSafariViewController(url: url)
        vc.dismissButtonStyle = .close
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
