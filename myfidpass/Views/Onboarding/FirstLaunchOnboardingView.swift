//
//  FirstLaunchOnboardingView.swift
//  myfidpass
//
//  Onboarding style iOS affiché au tout premier lancement de l’app, avant la page de connexion.
//

import SwiftUI
import UIKit

/// Clé UserDefaults : une fois à true, l’onboarding premier lancement n’est plus affiché.
enum FirstLaunchOnboarding {
    static let key = "myfidpass.hasCompletedFirstLaunchOnboarding"

    static var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

struct FirstLaunchOnboardingView: View {
    var onComplete: () -> Void

    private let tint = Color(hex: "2563EB")
    private var items: [iOS26StyleOnBoarding.Item] {
        [
            .init(
                id: 0,
                title: "Bienvenue sur MyFidpass",
                subtitle: "Votre outil pour gérer vos cartes de fidélité et fidéliser vos clients.",
                screenshot: UIImage(named: "Screen1")
            ),
            .init(
                id: 1,
                title: "Cartes de fidélité",
                subtitle: "Créez et personnalisez vos cartes.\nAjoutez-les au Wallet en un tap.",
                screenshot: UIImage(named: "Screen2")
            ),
            .init(
                id: 2,
                title: "Tableau de bord",
                subtitle: "Scannez les cartes, suivez les points\net envoyez des notifications.",
                screenshot: UIImage(named: "Screen4"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: 1.1)
            ),
            .init(
                id: 3,
                title: "Notifications ciblées",
                subtitle: "Envoyez des offres à tous vos membres\nou à des catégories précises.",
                screenshot: UIImage(named: "Screen3"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: -0.3)
            ),
            .init(
                id: 4,
                title: "C’est parti",
                subtitle: "Connectez-vous ou créez un compte\nsur myfidpass.fr pour commencer.",
                screenshot: UIImage(named: "Screen5")
            )
        ]
    }

    var body: some View {
        iOS26StyleOnBoarding(tint: tint, hideBezels: false, isLightTheme: true, items: items) {
            FirstLaunchOnboarding.hasCompleted = true
            onComplete()
        }
        .ignoresSafeArea()
    }
}

#Preview {
    FirstLaunchOnboardingView(onComplete: {})
}
