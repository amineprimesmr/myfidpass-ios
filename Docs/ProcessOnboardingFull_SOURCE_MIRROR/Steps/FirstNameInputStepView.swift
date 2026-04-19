//
//  FirstNameInputStepView.swift
//  Process
//
//  Created by ENNASRI Amine on 22/09/2025.
//

import SwiftUI
import FirebaseAuth

struct FirstNameInputStepView: View {
    @EnvironmentObject var profileService: UnifiedProfileService
    @Binding var firstName: String
    @State private var isTextFieldFocused = false
    @FocusState private var isTextFieldFocusedState: Bool

    // Callback pour passer à la page suivante
    var onComplete: (() -> Void)?

    // Callback pour notifier la validation
    var onValidationChanged: ((Bool) -> Void)?

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement entre titre et contenu
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing + 60)

                // Champ de texte libre avec texte saisi plus gros
                ZStack {
                    // TextField transparent pour la saisie
                    TextField("", text: $firstName)
                        .font(.system(size: firstName.isEmpty ? 22 : 36, weight: .medium))
                        .foregroundColor(.clear) // Texte transparent
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocusedState)
                        .onSubmit {
                            let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { return }

                            // Vibration pour la validation du texte
                            HapticManager.shared.impact(.medium)

                            // Fermer le clavier immédiatement
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                            // ✅ Passer à l'étape suivante IMMÉDIATEMENT (comme les autres pages)
                            onComplete?()

                            // Sauvegarder en arrière-plan SANS bloquer (Task détaché)
                            Task.detached(priority: .background) {
                                await saveFirstNameAndContinue()
                            }
                        }

                    // Placeholder (petit)
                    if firstName.isEmpty {
                        Text("Comment devons-nous t'appeler ?")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    } else {
                        // Texte saisi (plus gros)
                        Text(firstName)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                        }
                }
                .padding(.horizontal, 40)

                    // ✅ Le bouton CONTINUER est maintenant géré globalement par OnboardingView
                    Spacer()
            }

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            loadExistingFirstName()
            // Activer le clavier automatiquement après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocusedState = true
            }
        }
        .onChange(of: isTextFieldFocusedState) { newValue in
            isTextFieldFocused = newValue
        }
        .onChange(of: firstName) { newValue in
            // Valider automatiquement quand le prénom est saisi
            let isValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            onValidationChanged?(isValid)
        }
    }

    private func loadExistingFirstName() {
        // Essayer de récupérer le prénom depuis le profil utilisateur
        // ✅ CRITIQUE: Ne pas charger "Utilisateur" qui est une valeur par défaut
        if let profile = profileService.currentProfile,
           !profile.firstName.isEmpty,
           profile.firstName != "Utilisateur" {
            firstName = profile.firstName
            Logger.debug("Prénom existant chargé depuis le profil: \(firstName)", category: "General")
        } else {
            // Essayer de récupérer depuis Firebase Auth
            if let user = Auth.auth().currentUser,
               let displayName = user.displayName,
               !displayName.isEmpty,
               displayName != "Utilisateur" {
                firstName = displayName
                Logger.debug("Prénom chargé depuis displayName: \(firstName)", category: "General")
            } else {
                // Pas de prénom trouvé - l'utilisateur devra le saisir
                // ✅ CRITIQUE: Toujours vider le champ pour forcer la saisie
                firstName = ""
                Logger.warning("Aucun prénom trouvé - L'utilisateur devra le saisir", category: "General")
            }
        }
    }

    private func saveFirstNameAndContinue() async {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFirstName.isEmpty else { return }

        // ✅ Générer un username SIMPLE et RAPIDE (sans appels Firestore bloquants)
        // On génère un username basique et on le vérifiera plus tard si nécessaire
        let baseUsername = trimmedFirstName.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        let username = baseUsername.isEmpty ? "user\(UUID().uuidString.prefix(8).lowercased())" : baseUsername

        do {
                // ✅ SIMPLIFIÉ: Vérifier l'authentification sans attendre (non-bloquant)
                guard let finalUserId = Auth.auth().currentUser?.uid else {
                    // Si pas authentifié, stocker temporairement pour sauvegarde différée
                    Logger.debug("Authentification en cours, prénom sera sauvegardé plus tard", category: "General")
                    UserDefaults.standard.set(trimmedFirstName, forKey: "pending_firstname_to_save")
                    UserDefaults.standard.set(username, forKey: "pending_username_to_save")
                    return
                }

                // ✅ NOUVEAU: Vérifier s'il y a un prénom en attente à sauvegarder
                let pendingFirstName = UserDefaults.standard.string(forKey: "pending_firstname_to_save") ?? trimmedFirstName
                let pendingUsername = UserDefaults.standard.string(forKey: "pending_username_to_save") ?? username
                if UserDefaults.standard.string(forKey: "pending_firstname_to_save") != nil {
                    UserDefaults.standard.removeObject(forKey: "pending_firstname_to_save")
                    UserDefaults.standard.removeObject(forKey: "pending_username_to_save")
                    Logger.debug("Sauvegarde du prénom en attente: \(pendingFirstName)", category: "General")
                }

                var profile: UnifiedUserProfile

                if var existingProfile = profileService.currentProfile {
                    // Profil existe - mettre à jour
                    profile = existingProfile
                    profile.firstName = pendingFirstName
                    profile.username = pendingUsername
                } else {
                    // ✅ CRITIQUE: Créer un nouveau profil avec le prénom
                    Logger.debug("Création d'un nouveau profil pour sauvegarder le prénom", category: "General")
                    profile = UnifiedUserProfile(
                        userId: finalUserId,
                        firstName: pendingFirstName,
                        username: pendingUsername
                    )
                }

                try await profileService.saveProfile(profile)
                Logger.success("✅ Prénom sauvegardé avec succès: \(pendingFirstName)", category: "General")
                Logger.debug("Username généré: \(pendingUsername)", category: "General")

                // ✅ CRITIQUE: Recharger le profil pour s'assurer que currentProfile est à jour
                await profileService.loadProfile()
                Logger.debug("Profil rechargé après sauvegarde du prénom", category: "General")

                // Mettre à jour le displayName de Firebase Auth aussi
                if let user = Auth.auth().currentUser {
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = pendingFirstName
                    try? await changeRequest.commitChanges()
                    Logger.debug("DisplayName mis à jour: \(pendingFirstName)", category: "General")
                }

                // Ne pas passer automatiquement - l'utilisateur doit cliquer sur CONTINUER
                // onComplete?() sera appelé quand l'utilisateur clique sur le bouton
        } catch {
            Logger.error("Erreur sauvegarde prénom: \(error)", category: "General")
        }
}
}
