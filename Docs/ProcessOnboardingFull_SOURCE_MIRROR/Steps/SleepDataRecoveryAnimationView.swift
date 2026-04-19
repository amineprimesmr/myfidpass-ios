//
//  SleepDataRecoveryAnimationView.swift
//  Process
//
//  Vue de chargement avec barre de progression automatique
//

import SwiftUI

struct SleepDataRecoveryAnimationView: View {
    var onComplete: () -> Void

    @State private var progress: Double = 0.0
    @State private var displayedPercentage: Int = 0
    @State private var isComplete = false

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Fond noir
                Color.black
                    .ignoresSafeArea(.all)

                // ✅ Animation de lueur en dégradé qui tourne autour de l'écran
                RotatingGlowAnimation(progress: progress)

                VStack(spacing: 40) {
                    Spacer()

                    // Titre
                    VStack(spacing: 16) {
                        Text("Récupération")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)

                        Text("des données")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                    }

                    // Barre de progression
                    VStack(spacing: 20) {
                        // Barre de progression
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Fond de la barre
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 12)

                                // Barre de progression avec gradient
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(hex: "a7c4f2"),
                                                Color.blue,
                                                Color.purple
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * progress, height: 12)
                                    .shadow(color: Color(hex: "a7c4f2").opacity(0.5), radius: 8, x: 0, y: 0)
                            }
                        }
                        .frame(height: 12)
                        .padding(.horizontal, 40)

                        // Pourcentage avec animation de défilement
                        Text("\(displayedPercentage)%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }

                    Spacer()
                }
            }
        }
        .onAppear {
            startProgress()
        }
    }

    private func startProgress() {
        // Animation irrégulière sur 10 secondes avec défilement des nombres
        // Étapes irrégulières pour un effet plus réaliste
        // 0% → 12% (1.2s) - Démarrage rapide
        // 12% → 28% (1.8s) - Ralentissement
        // 28% → 45% (1.5s) - Accélération
        // 45% → 67% (2.0s) - Ralentissement
        // 67% → 85% (1.5s) - Accélération
        // 85% → 100% (2.0s) - Finalisation lente

        let stages: [(target: Double, duration: Double, startTime: Double)] = [
            (0.12, 1.2, 0.0),    // 0% → 12%
            (0.28, 1.8, 1.2),     // 12% → 28%
            (0.45, 1.5, 3.0),     // 28% → 45%
            (0.67, 2.0, 4.5),     // 45% → 67%
            (0.85, 1.5, 6.5),     // 67% → 85%
            (1.0, 2.0, 8.0)       // 85% → 100%
        ]

        // Animer chaque étape
        for (index, stage) in stages.enumerated() {
            let startProgress = index > 0 ? stages[index - 1].target : 0.0
            let progressDiff = stage.target - startProgress
            let steps = max(Int(stage.duration * 25), 15) // 25 updates/seconde pour fluidité
            let stepDuration = stage.duration / Double(steps)
            let progressIncrement = progressDiff / Double(steps)

            DispatchQueue.main.asyncAfter(deadline: .now() + stage.startTime) {
                // Animation de la barre de progression
                withAnimation(.easeInOut(duration: stage.duration)) {
                    progress = stage.target
        }

                // Animation du défilement des nombres (comme les scores)
                for step in 0...steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + (stepDuration * Double(step))) {
                        let currentProgressValue = startProgress + (progressIncrement * Double(step))
                        let newPercentage = min(Int(currentProgressValue * 100), 100)

                        // Mettre à jour le pourcentage affiché avec défilement fluide
                        if newPercentage > displayedPercentage {
                            displayedPercentage = newPercentage
                        }

                        // Dernière étape : s'assurer qu'on arrive à 100%
                        if index == stages.count - 1 && step == steps {
                            displayedPercentage = 100
                            progress = 1.0

                            // Attendre un peu avant de passer à la page suivante
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isComplete = true
            onComplete()
                            }
}
}
}
}
}
}
}
