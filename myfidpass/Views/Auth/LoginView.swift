//
//  LoginView.swift
//  myfidpass
//
//  Connexion / inscription par e-mail : flux minimal en deux étapes (e-mail → mot de passe),
//  détection automatique connexion / inscription via l’API.
//

import SwiftUI
import UIKit

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var lockedEmail: String? = nil
    var onChangeEmail: (() -> Void)? = nil
    var presentationAsSheet: Bool = false
    var onOpenEstablishment: (() -> Void)? = nil
    /// Feuille : `true` quand un champ est focalisé (clavier) — pour agrandir le sheet.
    var onSheetNeedsTallLayout: ((Bool) -> Void)? = nil

    private enum Step {
        case email
        case password
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var accountExists: Bool?
    @State private var isLoading = false
    @State private var isCheckingEmail = false
    @State private var errorMessage: String?

    @FocusState private var focusedField: Field?
    private enum Field {
        case email
        case password
    }

    init(
        lockedEmail: String? = nil,
        onChangeEmail: (() -> Void)? = nil,
        presentationAsSheet: Bool = false,
        onOpenEstablishment: (() -> Void)? = nil,
        onSheetNeedsTallLayout: ((Bool) -> Void)? = nil
    ) {
        self.lockedEmail = lockedEmail
        self.onChangeEmail = onChangeEmail
        self.presentationAsSheet = presentationAsSheet
        self.onOpenEstablishment = onOpenEstablishment
        self.onSheetNeedsTallLayout = onSheetNeedsTallLayout
    }

    /// E-mail (inscription / connexion classique) ou identifiant employé MyFidpass (sans @, défini par le commerçant).
    private var normalizedIdentifier: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isEmailValid: Bool {
        let e = normalizedIdentifier
        guard e.count >= 5, e.contains("@") else { return false }
        let parts = e.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return true
    }

    /// Identifiant employé : 3–32 caractères, a-z, 0-9, _ et - (même règles que l’API).
    private var isStaffIdentifierValid: Bool {
        let s = normalizedIdentifier
        guard !s.contains("@"), s.count >= 3, s.count <= 32 else { return false }
        return s.range(of: "^[a-z0-9][a-z0-9_-]{1,30}[a-z0-9]$", options: .regularExpression) != nil
    }

    private var isFirstStepValid: Bool {
        if normalizedIdentifier.contains("@") { return isEmailValid }
        return isStaffIdentifierValid
    }

    private var hasOnboardingEstablishmentForRegister: Bool {
        let p = FirstLaunchOnboarding.readPendingEstablishment()
        if p.relax { return true }
        return FirstLaunchOnboarding.hasCompletePendingEstablishmentForRegistration()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch step {
                    case .email:
                        emailStep
                    case .password:
                        passwordStep
                    }
                }
                .animation(.easeInOut(duration: 0.28), value: step)

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.Colors.error)
                        .padding(.top, 20)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !presentationAsSheet {
                    LegalDocumentLinksView()
                        .padding(.top, 8)
                    SocialSignInSection(intent: .signIn)
                        .padding(.top, 20)
                }

                if !presentationAsSheet {
                    Spacer(minLength: 32)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, presentationAsSheet ? 24 : 22)
            .padding(.bottom, presentationAsSheet ? 12 : 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if presentationAsSheet {
                sheetBottomActionBar
            }
        }
        .onAppear {
            if let locked = lockedEmail {
                email = locked
            }
            if presentationAsSheet {
                onSheetNeedsTallLayout?(false)
                scheduleSheetEmailFocusIfNeeded()
            }
        }
        .onChange(of: step) { _, new in
            if new == .password {
                focusedField = .password
            } else {
                focusedField = .email
            }
        }
        .toolbar {
            if !presentationAsSheet {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Retour") {
                        authService.showWelcome()
                    }
                }
            }
        }
        .sheetHideNavigationBar(presentationAsSheet)
        .onChange(of: focusedField) { _, new in
            guard presentationAsSheet else { return }
            onSheetNeedsTallLayout?(new != nil)
        }
    }

    /// Boutons principaux collés à la zone sûre (au-dessus du clavier) — évite le vide énorme du `ScrollView` + `Spacer`.
    @ViewBuilder
    private var sheetBottomActionBar: some View {
        VStack(spacing: 0) {
            switch step {
            case .email:
                primaryButton(
                    title: isCheckingEmail ? "Vérification…" : "Continuer",
                    enabled: isFirstStepValid && !isCheckingEmail && !isLoading,
                    loading: isCheckingEmail
                ) {
                    Task { await continueAfterEmail() }
                }
                .accessibilityLabel("Continuer avec cet e-mail")
            case .password:
                primaryButton(
                    title: primaryPasswordActionTitle,
                    enabled: canSubmitPassword,
                    loading: isLoading
                ) {
                    Task { await submitPasswordStep() }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(AppTheme.Colors.background)
    }

    private func scheduleSheetEmailFocusIfNeeded() {
        guard step == .email, lockedEmail == nil else { return }
        let delay: TimeInterval = 0.42
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            focusedField = .email
        }
    }

    // MARK: - Étape e-mail

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("Connexion")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text("Saisissez votre e-mail (compte commerçant) ou l’identifiant employé fourni par votre commerçant. Nous détecterons si le compte existe déjà.")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("E-mail ou identifiant employé")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if lockedEmail != nil {
                    Text(email)
                        .font(.system(size: 17))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                } else {
                    TextField("", text: $email, prompt: Text("ex. vous@email.fr ou cafe_marie").foregroundStyle(placeholderGray))
                        .textContentType(.username)
                        .keyboardType(.asciiCapable)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .tint(AppTheme.Colors.textPrimary)
                        .focused($focusedField, equals: .email)
                        .padding(16)
                        .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .onChange(of: email) { _, new in
                            if errorMessage != nil { errorMessage = nil }
                        }
                }

                if lockedEmail != nil, let onChangeEmail {
                    Button(action: onChangeEmail) {
                        Text("Modifier l’adresse e-mail")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .padding(.top, 8)

            if !presentationAsSheet {
                primaryButton(
                    title: isCheckingEmail ? "Vérification…" : "Continuer",
                    enabled: isFirstStepValid && !isCheckingEmail && !isLoading,
                    loading: isCheckingEmail
                ) {
                    Task { await continueAfterEmail() }
                }
                .padding(.top, 8)
                .accessibilityLabel("Continuer avec cet e-mail")
            }
        }
    }

    // MARK: - Étape mot de passe

    private var passwordStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(passwordTitle)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            Text(passwordSubtitle)
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(normalizedIdentifier)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Button("Modifier") {
                        goBackToEmail()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Mot de passe")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                SecureField(
                    "",
                    text: $password,
                    prompt: Text(accountExists == true ? "Votre mot de passe" : "Au moins 12 caractères")
                        .foregroundStyle(placeholderGray)
                )
                    .textContentType(accountExists == true ? .password : .newPassword)
                    .focused($focusedField, equals: .password)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .tint(AppTheme.Colors.textPrimary)
                    .padding(16)
                    .background(Color(UIColor.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .onChange(of: password) { _, _ in
                        if errorMessage != nil { errorMessage = nil }
                    }
            }

            if accountExists == false {
                if presentationAsSheet, !hasOnboardingEstablishmentForRegister, let openEst = onOpenEstablishment {
                    Button {
                        openEst()
                    } label: {
                        Text("Choisir mon établissement")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(Color.black.opacity(0.88), lineWidth: 1.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if accountExists == false {
                Text("Au moins 12 caractères pour sécuriser votre compte.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if !presentationAsSheet {
                primaryButton(
                    title: primaryPasswordActionTitle,
                    enabled: canSubmitPassword,
                    loading: isLoading
                ) {
                    Task { await submitPasswordStep() }
                }
                .padding(.top, 4)
            }
        }
    }

    private var passwordTitle: String {
        if accountExists == true { return "Se connecter" }
        return "Créer un compte"
    }

    private var passwordSubtitle: String {
        if accountExists == true {
            return "Entrez le mot de passe associé à votre compte."
        }
        return "Choisissez un mot de passe pour finaliser votre inscription commerçant."
    }

    private var primaryPasswordActionTitle: String {
        if accountExists == true { return "Se connecter" }
        return "Créer mon compte"
    }

    private var canSubmitPassword: Bool {
        guard !isLoading, !password.isEmpty else { return false }
        if !normalizedIdentifier.contains("@") { return true }
        if accountExists == true { return true }
        if password.count < 12 { return false }
        if !hasOnboardingEstablishmentForRegister { return false }
        return true
    }

    // MARK: - Bouton principal

    private func primaryButton(title: String, enabled: Bool, loading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if loading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.05)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(enabled && !loading ? 1 : 0.35))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
        .accessibilityLabel(title)
    }

    // MARK: - Actions

    private func continueAfterEmail() async {
        errorMessage = nil
        isCheckingEmail = true
        do {
            let exists = try await authService.checkAccountExists(identifier: normalizedIdentifier)
            await MainActor.run {
                if !normalizedIdentifier.contains("@"), !exists {
                    errorMessage = "Aucun compte avec cet identifiant. Demandez à votre commerçant de créer un accès employé (MyFidpass → Équipe)."
                    isCheckingEmail = false
                    return
                }
                accountExists = exists
                step = .password
                password = ""
                isCheckingEmail = false
                focusedField = .password
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isCheckingEmail = false
            }
        }
    }

    private func goBackToEmail() {
        withAnimation {
            step = .email
            password = ""
            accountExists = nil
            errorMessage = nil
        }
        focusedField = .email
    }

    private func submitPasswordStep() async {
        guard let exists = accountExists else { return }
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            if !normalizedIdentifier.contains("@") {
                try await authService.login(email: normalizedIdentifier, password: password)
            } else if exists {
                try await authService.login(email: normalizedIdentifier, password: password)
            } else {
                try await authService.register(
                    email: normalizedIdentifier,
                    password: password,
                    name: nil,
                    googlePlaceId: nil,
                    establishmentName: nil
                )
            }
        } catch AuthError.invalidCredentials {
            await MainActor.run {
                errorMessage = "E-mail ou mot de passe incorrect."
            }
        } catch AuthError.emailAlreadyUsed {
            await MainActor.run {
                errorMessage = "Un compte existe déjà avec cet e-mail. Revenez en arrière et connectez-vous."
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Placeholder e-mail : gris foncé (pas bleu système).
    private var placeholderGray: Color {
        Color(UIColor(white: 0.38, alpha: 1))
    }
}

#Preview {
    NavigationStack {
        LoginView()
            .environmentObject(AuthService())
    }
}
