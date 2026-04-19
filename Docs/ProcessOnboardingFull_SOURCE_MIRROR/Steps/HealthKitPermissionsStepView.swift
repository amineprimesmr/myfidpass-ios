//
//  HealthKitPermissionsStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth
import HealthKit

struct HealthKitPermissionsStepView: View {
    @EnvironmentObject var healthManager: HealthManager
    @EnvironmentObject var permissionsManager: PermissionsManager
    @EnvironmentObject var profileService: UnifiedProfileService

    @State private var isRequestingHealthKit = false
    @State private var showContent = false
    @State private var imageScale: CGFloat = 0.8
    @State private var pulseScale: CGFloat = 1.0

    // Paramètres reçus de la vue parente
    let healthKitGranted: Bool
    let checkPermissions: () -> Void
    let firstName: String // ✅ CRITIQUE : Passer firstName depuis le ViewModel

    // ✅ Récupérer le prénom avec fallback intelligent
    private var userFirstName: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != "Utilisateur" {
            return trimmed
        }
        // Fallback: essayer depuis le profil
        if let profileFirstName = profileService.currentProfile?.firstName,
           !profileFirstName.isEmpty,
           profileFirstName != "Utilisateur" {
            return profileFirstName
        }
        return "toi"
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    // ✅ Image sync en gros, en haut et au milieu avec animation - TAILLE ADAPTÉE POUR iPad
                    Image("sync")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: LayoutConstants.isIPad
                                ? min(geometry.size.width * 0.4, 350) // ✅ Plus petite proportion sur iPad
                                : min(geometry.size.width * 0.6, 280),
                            height: LayoutConstants.isIPad
                                ? min(geometry.size.width * 0.4, 350) // ✅ Plus petite proportion sur iPad
                                : min(geometry.size.width * 0.6, 280)
                        )
                        .scaleEffect(imageScale * pulseScale)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : -20)
                        .padding(.top, LayoutConstants.isIPad ? 80 : 60) // ✅ Plus d'espace sur iPad

                    // ✅ Texte "Autorise l'accès à Apple Santé" en plus gros et centré sous l'image
                    Text("Autorise l'accès à Apple Santé")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 40)
                        .padding(.top, 30)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)

                    Spacer()

                    // ✅ Texte avec cadenas en bas, juste au-dessus du bouton
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))

                        Text("Tes données de santé restent privées, elles ne sont ni stockées ni partagées et servent uniquement à améliorer ton expérience.")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 120) // ✅ Positionné juste au-dessus du bouton (bouton a padding bottom 50 + hauteur 50 = 100, donc 120 pour espacement)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 20)
                }
            }
        }
        .onAppear {
            checkPermissions()

            // ✅ Animation fluide d'apparition
            withAnimation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.1)) {
                showContent = true
                imageScale = 1.0
            }

            // ✅ Animation de pulsation pour l'image sync (après l'apparition)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }

            // ✅ Demander les permissions de localisation et mouvement au chargement de la page
            Task {
                // Demander la permission de localisation
                await permissionsManager.requestLocationPermission()

                // Demander la permission de mouvement
                await MainActor.run {
                    permissionsManager.requestMotionPermission()
                }
}
}
}
}
