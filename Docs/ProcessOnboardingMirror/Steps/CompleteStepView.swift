//
//  CompleteStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI

struct CompleteStepView: View {

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("CONFIGURATION")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("TERMINÉE")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                Text("Ton profil est maintenant configuré. Tu peux maintenant utiliser l'application.")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            VStack(spacing: 12) {
                Text("✓ Compte Apple créé")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text("✓ Permissions HealthKit accordées")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))

                Text("✓ Données de santé synchronisées")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
}
}
}
