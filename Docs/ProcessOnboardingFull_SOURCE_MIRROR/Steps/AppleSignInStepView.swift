//
//  AppleSignInStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct AppleSignInStepView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var profileService: UnifiedProfileService
    @StateObject private var hapticManager = HapticManager.shared

    @State private var isLoading = false

    var onComplete: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Fond noir
                Color.black
                    .ignoresSafeArea(.all)

                VStack(spacing: 0) {
                    Spacer()

                    // ✅ Image framer au centre (encore plus haute)
                    Image("framer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            width: min(geometry.size.width * 0.85, 400),
                            height: min(geometry.size.width * 0.85, 400)
                        )
                        .padding(.top, 20)

                    // ✅ Texte par-dessus l'image, encore plus haut
                    Text("Construisons maintenant ton expérience personnalisée.")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 0)
                        .padding(.horizontal, 40)

                    Spacer()

                    // Bouton Créer mon programme
                    Button(action: {
                        Task {
                            await signInWithApple()
                        }
                    }) {
                        HStack(spacing: 12) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                // ✅ Icône paillette avant le texte
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))

                                Text("Créer mon programme")
                                    .font(.system(size: 20, weight: .black))

                                // ✅ Icône paillette après le texte
                                Image(systemName: "sparkles")
                                    .font(.system(size: 20, weight: .semibold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .glassStyle()
                    .buttonBorderShape(.roundedRectangle(radius: 50))
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                    .disabled(isLoading)
                }
            }
        }
    }

    @MainActor
    private func signInWithApple() async {
        hapticManager.impact(.heavy)
        isLoading = true

        // Démarrer l'onboarding si nécessaire
        if !authManager.isInOnboarding {
            authManager.startOnboarding()
        }

        // ✅ CORRECTION: Utiliser await au lieu de continuation pour éviter les race conditions
        do {
            // Attendre que l'authentification soit complète
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                AppleSignInManager.shared.startSignInWithAppleFlow { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }

            // ✅ CRITIQUE: Attendre que l'utilisateur soit vraiment authentifié
            var attempts = 0
            while Auth.auth().currentUser == nil && attempts < 20 {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                attempts += 1
            }

            guard Auth.auth().currentUser != nil else {
                Logger.error("Utilisateur non authentifié après Apple Sign In", category: "General")
                isLoading = false
                return
            }

            hapticManager.notification(.success)

            // ✅ CRITIQUE: Créer le profil utilisateur maintenant qu'on est connecté
            await createUnifiedUserProfileIfNeeded()

            // ✅ CRITIQUE: Attendre un peu pour s'assurer que tout est synchronisé
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            self.isLoading = false

            // ✅ CRITIQUE: Passer à l'étape suivante (paiement) - APPEL DIRECT SANS DELAY
            if let onComplete = self.onComplete {
                onComplete()
            } else {
                Logger.error("onComplete callback non défini dans AppleSignInStepView", category: "General")
            }

        } catch {
            hapticManager.notification(.error)
            Logger.error("Erreur Apple Sign In: \(error)", category: "General")
            self.isLoading = false
        }
    }

    /// Créer le profil utilisateur si nécessaire
    @MainActor
    private func createUnifiedUserProfileIfNeeded() async {
        guard let userId = Auth.auth().currentUser?.uid else {
            Logger.error("Aucun utilisateur connecté pour créer le profil", category: "General")
            return
        }

        // Vérifier si le profil existe déjà
        if profileService.currentProfile != nil {
            Logger.info("Profil utilisateur déjà existant", category: "General")
            return
        }

        Logger.debug("Création du profil utilisateur pour l'onboarding...", category: "General")

        do {
            // Créer un profil temporaire pour l'onboarding
            let tempProfile = UnifiedUserProfile(
                userId: userId,
                firstName: "Utilisateur"
            )
            try await profileService.saveProfile(tempProfile)
            Logger.debug("Profil utilisateur créé pour l'onboarding", category: "General")
        } catch {
            Logger.error("Erreur création profil utilisateur: \(error)", category: "General")
        }
}
}
