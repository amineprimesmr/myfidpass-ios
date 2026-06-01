//
//  MerchantOnboardingEmailStepView.swift
//
//  Étape e-mail onboarding — même fond / palette que la recherche d’établissement (thème clair Process).
//

import SwiftUI

enum MerchantOnboardingProcessFieldPalette {
    static let placeholder = AppTheme.Colors.textSecondary.opacity(0.65)
}

struct MerchantOnboardingEmailStepContent: View {
    @Binding var email: String
    var fieldPrompt: String = "Entrez votre e-mail"
    var helperText: String = "Nous l'utiliserons pour créer votre compte commerçant."
    var keyboardType: UIKeyboardType = .emailAddress
    var textContentType: UITextContentType? = .emailAddress
    var isChecking: Bool
    var errorMessage: String?

    @FocusState private var fieldFocused: Bool
    @State private var heroVisible = false
    @State private var fieldVisible = false

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            TextField(
                "",
                text: $email,
                prompt: Text(fieldPrompt)
                    .foregroundStyle(MerchantOnboardingProcessFieldPalette.placeholder)
            )
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .tint(AppTheme.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .textFieldStyle(.plain)
            .keyboardType(keyboardType)
            .textContentType(textContentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.continue)
            .focused($fieldFocused)
            .padding(.horizontal, 32)
            .opacity(fieldVisible ? 1 : 0)
            .offset(y: fieldVisible ? 0 : 16)

            Text(helperText)
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .opacity(heroVisible ? 1 : 0)
                .offset(y: heroVisible ? 0 : 10)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if isChecking {
                ProgressView()
                    .scaleEffect(0.9)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                heroVisible = true
            }
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84).delay(0.06)) {
                fieldVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                fieldFocused = true
            }
        }
    }
}

// MARK: - Layout partagé (onboarding + connexion)

struct ProcessEmailCaptureLayout<Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ViewBuilder var content: () -> Content

    private var topReserved: CGFloat {
        if horizontalSizeClass == .regular {
            return 56
        }
        return MyfidpassOnboardingConstants.titleAreaHeight
            + MyfidpassOnboardingConstants.titleToContentSpacing
            + MyfidpassOnboardingConstants.processStyleFieldExtraSpacing
    }

    private var horizontalGutter: CGFloat {
        horizontalSizeClass == .regular ? 40 : 16
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: topReserved)

            ScrollView(showsIndicators: false) {
                content()
                    .padding(.horizontal, horizontalGutter)
                    .padding(.bottom, 24)
            }
        }
    }
}

struct AuthSignInPasswordStepContent: View {
    @Binding var password: String
    let identifierLabel: String
    var passwordPrompt: String = "Mot de passe"
    var helperText: String = "Saisissez le mot de passe de votre compte MyFidpass."
    var isLoading: Bool
    var errorMessage: String?

    @FocusState private var fieldFocused: Bool
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            if !identifierLabel.isEmpty {
                VStack(spacing: 6) {
                    Text("COMPTE")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Text(identifierLabel)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
            }

            SecureField(
                "",
                text: $password,
                prompt: Text(passwordPrompt)
                    .foregroundStyle(MerchantOnboardingProcessFieldPalette.placeholder)
            )
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(AppTheme.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .textContentType(.password)
            .submitLabel(.go)
            .focused($fieldFocused)
            .padding(.horizontal, 32)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)

            Text(helperText)
                .font(AppTheme.Fonts.caption2())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .opacity(appeared ? 1 : 0)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.error)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }

            if isLoading {
                ProgressView()
                    .scaleEffect(0.9)
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.62, dampingFraction: 0.84)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                fieldFocused = true
            }
        }
    }
}

struct MerchantOnboardingExistingAccountSheet: View {
    let email: String
    var onRecover: () -> Void
    var onDismiss: () -> Void

    /// Surface unique du sheet (évite la bande grise sous le contenu / home indicator).
    private let sheetSurface = Color.white

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.black.opacity(0.12))
                .frame(width: 42, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.Colors.accent.opacity(0.14))
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.Colors.accent)
                    }
                Text("Vous avez déjà un compte")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            (
                Text("\(email) est déjà lié à un compte MyFidpass. ")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                + Text("Se connecter plutôt ?")
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            )
            .font(.system(size: 15, weight: .medium))
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onRecover) {
                Text("Se connecter")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.Colors.primary, in: Capsule())
            }
            .buttonStyle(.plain)

            Button("Utiliser un autre e-mail", action: onDismiss)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
        }
        .padding(.horizontal, 22)
        .safeAreaPadding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.light)
        .presentationDetents([.height(292)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
        .presentationBackground {
            sheetSurface.ignoresSafeArea()
        }
    }
}
