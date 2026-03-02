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
                subtitle: "L’app des commerçants pour fidéliser vos clients avec des cartes dans le Wallet iPhone.",
                screenshot: UIImage(named: "Screen1")
            ),
            .init(
                id: 1,
                title: "Cartes dans le Wallet",
                subtitle: "Créez une carte fidélité (tampons ou points), personnalisez le design.\nVos clients l’ajoutent en un tap sur leur iPhone.",
                screenshot: UIImage(named: "Screen2")
            ),
            .init(
                id: 2,
                title: "Scannez et suivez",
                subtitle: "Scannez le QR de la carte à chaque passage, ajoutez des tampons ou des points.\nConsultez l’activité et la liste des membres.",
                screenshot: UIImage(named: "Screen4"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: 1.1)
            ),
            .init(
                id: 3,
                title: "Notifications ciblées",
                subtitle: "Envoyez des offres et actualités à tous vos membres ou à des catégories (ex. fidèles, inactifs).",
                screenshot: UIImage(named: "Screen3"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: -0.3)
            ),
            .init(
                id: 4,
                title: "Prêt à commencer",
                subtitle: "Connectez-vous ou créez votre compte commerçant sur myfidpass.fr pour activer votre carte.",
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
