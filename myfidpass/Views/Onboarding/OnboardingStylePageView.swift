//
//  OnboardingStylePageView.swift
//  myfidpass
//
//  Contenu identique à iOSStyleOnBoarding/ContentView — accessible depuis Ma Carte.
//

import SwiftUI
import UIKit

struct OnboardingStylePageView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        iOS26StyleOnBoarding(tint: .blue, hideBezels: false, items: [
            .init(
                id: 0,
                title: "Welcome to iOS 26",
                subtitle: "Introducing a new design with\nLiquid Glass.",
                screenshot: UIImage(named: "Screen1")
            ),
            .init(
                id: 1,
                title: "New Context Menu's",
                subtitle: "Access menu options with\ncontrols that fluidly morph.",
                screenshot: UIImage(named: "Screen2")
            ),
            .init(
                id: 2,
                title: "Floating Tab Bar",
                subtitle: "Tab bar that floats and responds\nto your hand's motion.",
                screenshot: UIImage(named: "Screen4"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: 1.1)
            ),
            .init(
                id: 3,
                title: "All New Photo's App",
                subtitle: "Focus on what matters with\nLiquid Glass Controls.",
                screenshot: UIImage(named: "Screen3"),
                zoomScale: 1.3,
                zoomAnchor: .init(x: 0.5, y: -0.3)
            ),
            .init(
                id: 4,
                title: "Personalized Home Screen",
                subtitle: "Personalize iPhone with new\nlooks for app icons.",
                screenshot: UIImage(named: "Screen5")
            )
        ]) {
            dismiss()
        }
    }
}

#Preview {
    OnboardingStylePageView()
}
