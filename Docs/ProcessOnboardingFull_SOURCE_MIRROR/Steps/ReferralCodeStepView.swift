//
//  ReferralCodeStepView.swift
//  Process
//
//  Page : Entrez le code de parrainage (facultatif)
//

import SwiftUI

struct ReferralCodeStepView: View {
    @StateObject private var hapticManager = HapticManager.shared
    @FocusState private var isTextFieldFocusedState: Bool

    let onComplete: () -> Void
    let onBack: (() -> Void)?

    @State private var referralCode: String = ""

    init(onComplete: @escaping () -> Void, onBack: (() -> Void)? = nil) {
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            // ✅ Le fond noir et la lueur animée sont gérés par OnboardingView

            VStack(spacing: 0) {
                // Espace pour le titre en overlay + espacement uniforme
                Spacer()
                    .frame(height: OnboardingConstants.titleAreaHeight)

                // Espacement réduit entre titre et contenu pour remonter le champ
                Spacer()
                    .frame(height: OnboardingConstants.titleToContentSpacing - 30)

                // Champ de texte libre avec texte saisi plus gros
                ZStack {
                    // TextField transparent pour la saisie
                    TextField("", text: $referralCode)
                        .font(.system(size: referralCode.isEmpty ? 22 : 36, weight: .medium))
                        .foregroundColor(.clear) // Texte transparent
                        .multilineTextAlignment(.center)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isTextFieldFocusedState)
                        .autocapitalization(.allCharacters)
                        .disableAutocorrection(true)
                        .onSubmit {
                            // Fermer le clavier seulement, ne pas passer à l'étape suivante
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }

                    // Placeholder (petit)
                    if referralCode.isEmpty {
                        Text("Code de parrainage")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    } else {
                        // Texte saisi (plus gros)
                        Text(referralCode)
                            .font(.system(size: 36, weight: .medium))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 20) // Espacement réduit pour monter le bouton

                // Bouton continuer/passer (texte change selon si code saisi ou non)
                Button(action: {
                    let trimmed = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Vibration pour le bouton
                    HapticManager.shared.impact(.medium)

                    // Fermer le clavier immédiatement
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)

                    // ✅ Passer à l'étape suivante IMMÉDIATEMENT
                    onComplete()

                    // Sauvegarder en arrière-plan SANS bloquer (Task détaché)
                    if !trimmed.isEmpty {
                        Task.detached(priority: .background) {
                            await submitReferralCode()
                        }
                    }
                }) {
                    Text(referralCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "PASSER" : "CONTINUER")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .glassStyle()
                .buttonBorderShape(.roundedRectangle(radius: 50))
                .padding(.horizontal, 40)
                .opacity(1.0) // Toujours visible car facultatif
                .animation(.easeInOut(duration: 0.2), value: referralCode.isEmpty)

                Spacer()
                    .frame(height: 140) // Équilibre entre visible et pas trop haut
            }

            // ✅ Titre en OVERLAY - Position ABSOLUE depuis le haut de l'écran
            VStack {
                OnboardingTitleView("Entrez le code de", "parrainage")
                    .padding(.top, OnboardingConstants.titleTopPadding)
                Spacer()
            }

            // ✅ Bouton retour en haut à gauche
            if let onBack = onBack {
                VStack {
                    HStack {
                        Button(action: {
                            hapticManager.impact(.light)
                            onBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 34, height: 34)
                        }
                        .glassStyle()
                        .buttonBorderShape(.circle)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Activer le clavier automatiquement après un court délai
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocusedState = true
            }
        }
    }

    // MARK: - Actions

    private func submitReferralCode() async {
        let trimmed = referralCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // TODO: Implémenter la logique de soumission du code de parrainage
        // Par exemple : appeler une API pour valider le code
        Logger.debug("Code de parrainage soumis: \(trimmed)", category: "Referral")
    }
}
