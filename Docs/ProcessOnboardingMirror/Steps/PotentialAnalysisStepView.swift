//
//  PotentialAnalysisStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth

struct PotentialAnalysisStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @State private var userFirstName = "Utilisateur"

    var body: some View {
        VStack(spacing: 50) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(userFirstName), ton corps exploite 38% de son potentiel.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                Text("On va te faire passer à +80%.")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)
        }
        .onAppear {
            loadUserFirstName()
        }
        .onChange(of: profileService.currentProfile?.firstName) { newValue in
            if let newFirstName = newValue, !newFirstName.isEmpty {
                userFirstName = newFirstName
            }
        }
    }

    private func loadUserFirstName() {
        if let user = Auth.auth().currentUser {
            // 1. Priorité 1: Récupérer depuis le profil utilisateur (le plus fiable)
            if let profile = profileService.currentProfile,
               !profile.firstName.isEmpty {
                userFirstName = profile.firstName
            }
            // 2. Priorité 2: Récupérer depuis displayName de Firebase Auth
            else if let displayName = user.displayName, !displayName.isEmpty {
                userFirstName = displayName
            }
            // 3. Fallback: Utiliser un nom générique au lieu de l'email
            else {
                userFirstName = "Utilisateur"
            }
}
}
}
