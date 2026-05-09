//
//  AuthSignUpView.swift
//  myfidpass
//
//  Inscription : héros + Google ; saisie e-mail dans une sheet.
//

import Combine
import SwiftUI

struct AuthSignUpView: View {
    @EnvironmentObject private var authService: AuthService
    var onBack: () -> Void = {}

    @State private var showEmailSheet = false
    @State private var googleLoading = false
    @State private var googleAlert: String?
    @State private var heroCarouselIndex = 0
    @State private var heroAppeared = false
    @State private var contentAppeared = false

    private static let heroAssets = ["5", "6", "7", "8"]

    var body: some View {
        GeometryReader { geo in
            let fullW = geo.size.width
            let fullH = geo.size.height
            let heroHeight = fullH * 0.82
            let topSafe = geo.safeAreaInsets.top
            let bottomSafe = max(geo.safeAreaInsets.bottom, 12)

            ZStack(alignment: .bottom) {
                Color.white.ignoresSafeArea()

                TabView(selection: $heroCarouselIndex) {
                    ForEach(0..<Self.heroAssets.count, id: \.self) { i in
                        Image(Self.heroAssets[i])
                            .resizable()
                            .scaledToFill()
                            .frame(width: fullW, height: heroHeight, alignment: .top)
                            .clipped()
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: fullW, height: heroHeight, alignment: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
                .offset(y: -8)
                .scaleEffect(heroAppeared ? 1 : 1.02)
                .opacity(heroAppeared ? 1 : 0)
                .ignoresSafeArea(edges: .top)

                VStack(spacing: 12) {
                    signUpSelectedCommerceBanner
                    googleButton
                    emailPrimaryButton
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 28)
                .padding(.bottom, bottomSafe + 16)
                .background(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.75),
                            Color.white,
                        ],
                        startPoint: UnitPoint(x: 0.5, y: 0),
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
                .opacity(contentAppeared ? 1 : 0)
            }
            .overlay(alignment: .topLeading) {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .frame(width: 36, height: 36)
                }
                .buttonBorderShape(.circle)
                .controlSize(.regular)
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 18)
                .accessibilityLabel("Retour")
                .padding(EdgeInsets(top: max(topSafe, 44) + 8, leading: 16, bottom: 0, trailing: 0))
            }
            .frame(width: fullW, height: fullH)
        }
        .ignoresSafeArea(edges: [.top, .bottom])
        .preferredColorScheme(.light)
        .sheet(isPresented: $showEmailSheet) {
            AuthSignUpEmailSheet(isPresented: $showEmailSheet)
                .environmentObject(authService)
        }
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.88)) {
                heroAppeared = true
            }
            withAnimation(.spring(response: 0.46, dampingFraction: 0.86).delay(0.06)) {
                contentAppeared = true
            }
        }
        .onReceive(Timer.publish(every: 4.2, on: .main, in: .common).autoconnect()) { _ in
            guard heroAppeared else { return }
            withAnimation(.easeInOut(duration: 0.45)) {
                heroCarouselIndex = (heroCarouselIndex + 1) % Self.heroAssets.count
            }
        }
        .alert("Inscription Google", isPresented: .init(
            get: { googleAlert != nil },
            set: { if !$0 { googleAlert = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let googleAlert { Text(googleAlert) }
        }
    }

    /// Commerce choisi à l’étape précédente (un seul lieu à l’inscription ; d’autres commerces via l’app).
    @ViewBuilder
    private var signUpSelectedCommerceBanner: some View {
        if let title = SignUpPendingCommerceDisplay.primaryTitle() {
            VStack(spacing: 6) {
                Text("Votre commerce")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.045))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
            )
        }
    }

    private var emailPrimaryButton: some View {
        Button {
            showEmailSheet = true
        } label: {
            Text("Inscription avec l'e-mail")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(Color.black)
        }
        .buttonBorderShape(.capsule)
        .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
    }

    private var googleButton: some View {
        Button {
            googleLoading = true
            googleAlert = nil
            Task {
                defer { googleLoading = false }
                do {
                    try await authService.startGoogleOAuthFlow(intent: .signUp)
                } catch {
                    googleAlert = error.localizedDescription
                }
            }
        } label: {
            HStack(spacing: 12) {
                if googleLoading {
                    ProgressView().tint(.white).scaleEffect(0.92)
                } else {
                    Image("GoogleGLogo")
                        .resizable().scaledToFit()
                        .frame(width: 20, height: 20)
                }
                Text(googleLoading ? "Inscription…" : "Créer avec Google")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 18)
            .background(Color.black, in: Capsule())
            .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(googleLoading)
    }
}

// MARK: - Sheet

private enum AuthEmailSheetPresentation {
    /// Un peu plus haut que la connexion (bandeau commerce + placeholder mot de passe).
    static let detentHeight: CGFloat = 360
}

private struct AuthSignUpEmailSheet: View {
    @EnvironmentObject private var authService: AuthService
    @Binding var isPresented: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @FocusState private var focused: Field?
    private enum Field { case email, password }

    private var fieldChromeBackground: Color {
        Color(red: 236 / 255, green: 236 / 255, blue: 238 / 255)
    }

    private var placeholderGray: Color {
        Color(UIColor(white: 0.38, alpha: 1))
    }

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var isEmailValid: Bool {
        let e = normalizedEmail
        guard e.count >= 5, e.contains("@") else { return false }
        let parts = e.split(separator: "@")
        guard parts.count == 2, let domain = parts.last, domain.contains(".") else { return false }
        return true
    }

    private var canSubmit: Bool {
        !isLoading && isEmailValid && password.count >= 12
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 12) {
                if let commerceTitle = SignUpPendingCommerceDisplay.primaryTitle() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Commerce sélectionné")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.45))
                            .textCase(.uppercase)
                        Text(commerceTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.88))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                }
                TextField(
                    "",
                    text: $email,
                    prompt: Text("E-mail").foregroundStyle(placeholderGray)
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focused, equals: .email)
                .submitLabel(.next)
                .padding(14)
                .background(fieldChromeBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: email) { _, _ in
                    if errorMessage != nil { errorMessage = nil }
                }

                SecureField(
                    "",
                    text: $password,
                    prompt: Text("Mot de passe (12 caractères min.)").foregroundStyle(placeholderGray)
                )
                .textContentType(.newPassword)
                .focused($focused, equals: .password)
                .submitLabel(.go)
                .padding(14)
                .background(fieldChromeBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .onChange(of: password) { _, _ in
                    if errorMessage != nil { errorMessage = nil }
                }
                .onSubmit {
                    if canSubmit { Task { await submit() } }
                }

                if let msg = errorMessage, !msg.isEmpty {
                    Text(msg)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.Colors.error)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if isLoading {
                            ProgressView().tint(.black).scaleEffect(1.02)
                        } else {
                            Text("Créer mon compte")
                                .font(.system(size: 17, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .foregroundStyle((canSubmit || isLoading) ? Color.black : Color.black.opacity(0.4))
                }
                .buttonBorderShape(.capsule)
                .liquidGlassButtonAppearance(.adaptive, cornerRadius: 999)
                .disabled(!canSubmit || isLoading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .presentationDetents([.height(AuthEmailSheetPresentation.detentHeight)])
        .presentationDragIndicator(.hidden)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                focused = .email
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.register(
                email: normalizedEmail,
                password: password,
                name: nil,
                googlePlaceId: nil,
                establishmentName: nil
            )
            await MainActor.run { isPresented = false }
        } catch AuthError.emailAlreadyUsed {
            await MainActor.run {
                errorMessage = "Un compte existe déjà avec cet e-mail. Utilisez un autre e-mail."
            }
        } catch AuthError.apiMessage(let msg) {
            await MainActor.run { errorMessage = msg }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

private enum SignUpPendingCommerceDisplay {
    /// Titre court (nom sans répéter toute l’adresse si elle est après une virgule).
    static func primaryTitle() -> String? {
        let p = FirstLaunchOnboarding.readPendingEstablishment()
        if p.relax { return nil }
        let desc = p.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !desc.isEmpty else { return nil }
        let parts = desc.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        let title = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? desc
        return title.isEmpty ? nil : title
    }
}

#Preview {
    AuthSignUpView()
        .environmentObject(AuthService())
}
