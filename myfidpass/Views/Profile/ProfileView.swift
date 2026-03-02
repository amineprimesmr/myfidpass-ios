//
//  ProfileView.swift
//  myfidpass
//
//  Profil du commerçant : établissement (nom, logo, adresse), coordonnées, notifications.
//

import SwiftUI
import CoreData
import UIKit
import PhotosUI

struct ProfileView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var organizationName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var address: String = ""
    @State private var logoURL: String = ""
    @State private var logoPhotoItem: PhotosPickerItem?
    @State private var showLogoutConfirmation = false
    @State private var isSaving = false
    @State private var savedMessage: String?
    @State private var notificationMessage: String = ""
    @State private var isSendingNotification = false
    @State private var notifyResultMessage: String?
    @State private var notifyResultSuccess: Bool = false

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    heroSection
                    establishmentSection
                    notificationsSection
                    locationCardSection
                    walletSection
                    logoutSection
                }
                .padding(AppTheme.Spacing.md)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { loadProfile() }
            .refreshable {
                await syncService.syncIfNeeded()
                loadProfile()
            }
            .overlay {
                if syncService.isSyncing && organizationName.isEmpty {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(AppTheme.Colors.primary)
                }
            }
            .confirmationDialog("Déconnexion", isPresented: $showLogoutConfirmation) {
                Button("Se déconnecter", role: .destructive) {
                    authService.logout()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Voulez-vous vous déconnecter de votre compte ?")
            }
        }
    }

    // MARK: - Hero : commerce en gros (logo + nom + email compte)

    private var heroSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            BusinessLogoView(logoURL: logoURL.isEmpty ? nil : logoURL, size: 96, cornerRadius: 24)
                .shadow(color: AppTheme.Colors.shadow, radius: 12, x: 0, y: 4)

            VStack(spacing: AppTheme.Spacing.xs) {
                Text(organizationName.isEmpty ? "Mon établissement" : organizationName)
                    .font(AppTheme.Fonts.title())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if let accountEmail = authService.currentUserEmail {
                    Text(accountEmail)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Text("Votre espace commerçant")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
        .padding(.horizontal, AppTheme.Spacing.lg)
        .background(
            LinearGradient(
                colors: [
                    AppTheme.Colors.cardBackground,
                    AppTheme.Colors.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Mon établissement (nom, logo optionnel, adresse avec recherche, tél, email)

    private var establishmentSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Image(systemName: "storefront.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Mon établissement")
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Nom de votre établissement")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("Ex. Café de la Gare", text: $organizationName)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Logo de l’établissement")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                HStack(spacing: AppTheme.Spacing.md) {
                    BusinessLogoView(logoURL: logoURL.isEmpty ? nil : logoURL, size: 56, cornerRadius: 12)
                    PhotosPicker(
                        selection: $logoPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Changer le logo", systemImage: "photo.badge.plus")
                            .font(AppTheme.Fonts.subheadline())
                    }
                    .onChange(of: logoPhotoItem) { _, new in
                        guard new != nil else { return }
                        Task { await loadLogoFromPicker(new) }
                    }
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Adresse du commerce")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                AddressSearchField(text: $address, placeholder: "Rechercher une adresse ou un établissement…")
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Téléphone")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("06 12 34 56 78", text: $phone)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .keyboardType(.phonePad)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Email de contact")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                TextField("contact@exemple.fr", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }

            if let msg = savedMessage {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                    Text(msg)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }

            Button {
                Task { await saveProfile() }
            } label: {
                HStack {
                    if isSaving {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Enregistrer")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppTheme.Spacing.md)
                .font(AppTheme.Fonts.headline())
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
            .disabled(isSaving)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Notifications")
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Sur cet appareil")
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Alertes commerçant : nouveaux membres, scans, etc.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                HStack {
                    Image(systemName: NotificationsService.shared.isAuthorized ? "checkmark.circle.fill" : "bell.slash.fill")
                        .foregroundStyle(NotificationsService.shared.isAuthorized ? AppTheme.Colors.success : AppTheme.Colors.textSecondary)
                    Text(NotificationsService.shared.isAuthorized ? "Activées" : "Désactivées")
                        .font(AppTheme.Fonts.body())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    Spacer()
                    Button("Réglages iOS") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .font(AppTheme.Fonts.caption())
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
            }

            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("Notifier vos clients")
                    .font(AppTheme.Fonts.headline())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text("Message envoyé à tous les clients ayant votre carte dans l’Apple Wallet (écran de verrouillage).")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                ZStack(alignment: .topLeading) {
                    if notificationMessage.isEmpty {
                        Text("Ex. Nouvelle offre ce week-end !")
                            .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }
                    TextEditor(text: $notificationMessage)
                        .padding(AppTheme.Spacing.sm)
                        .frame(minHeight: 80, maxHeight: 120)
                        .scrollContentBackground(.hidden)
                        .font(AppTheme.Fonts.body())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
                if let msg = notifyResultMessage {
                    Text(msg)
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(notifyResultSuccess ? AppTheme.Colors.success : AppTheme.Colors.error)
                }
                Button {
                    sendNotificationToClients()
                } label: {
                    HStack {
                        if isSendingNotification {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "paperplane.fill")
                            Text("Envoyer la notification")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
                .disabled(notificationMessage.trimmingCharacters(in: .whitespaces).isEmpty || isSendingNotification)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Localisation (adresse + carte)

    private var locationCardSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Localisation du commerce")
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Text("Utilisée dans le pass Wallet (Relevant locations). Quand un client est proche de votre commerce, son iPhone peut afficher votre carte sur l’écran de verrouillage.")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
            if !address.trimmingCharacters(in: .whitespaces).isEmpty {
                HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.primary)
                    Text(address)
                        .font(AppTheme.Fonts.body())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                }
                Button {
                    openAddressInMaps(address)
                } label: {
                    Label("Voir sur la carte", systemImage: "map.fill")
                        .font(AppTheme.Fonts.callout())
                }
                .padding(.top, 4)
            } else {
                Text("Renseignez l’adresse ci-dessus et enregistrez.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Carte Wallet & clients

    private var walletSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                Image(systemName: "wallet.pass.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                Text("Carte Wallet & clients")
                    .font(AppTheme.Fonts.title3())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            Text("Personnalisez le design (nom, couleurs, logo, tampons) dans l’onglet **Ma Carte**. Le design s’applique à tous les clients.")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.xl))
        .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
    }

    // MARK: - Déconnexion

    private var logoutSection: some View {
        Button {
            showLogoutConfirmation = true
        } label: {
            Label("Se déconnecter", systemImage: "rectangle.portrait.and.arrow.right")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.error)
                .frame(maxWidth: .infinity)
                .padding(AppTheme.Spacing.md)
        }
        .buttonStyle(.bordered)
        .tint(AppTheme.Colors.error)
        .padding(.top, AppTheme.Spacing.sm)
    }

    // MARK: - Actions

    private func openAddressInMaps(_ address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func loadProfile() {
        let business = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        organizationName = template?.displayName ?? business.name ?? "Mon établissement"
        email = business.email ?? ""
        phone = business.phone ?? ""
        address = business.address ?? ""
        logoURL = template?.logoURL ?? business.logoURL ?? ""
    }

    private func saveProfile() async {
        isSaving = true
        savedMessage = nil
        _ = dataService.createOrGetCurrentBusiness()
        let template = dataService.currentCardTemplate()
        let nameFinal = organizationName.trimmingCharacters(in: .whitespaces)
        let finalName = nameFinal.isEmpty ? "Mon établissement" : nameFinal

        dataService.updateBusiness(
            name: finalName,
            email: email.isEmpty ? nil : email,
            phone: phone.isEmpty ? nil : phone,
            address: address.isEmpty ? nil : address,
            logoURL: logoURL.isEmpty ? nil : logoURL
        )
        if let t = template {
            t.displayName = finalName
            if !logoURL.isEmpty { t.logoURL = logoURL }
            t.updatedAt = Date()
            try? viewContext.save()
        }

        if let slug = AuthStorage.currentBusinessSlug, let t = template {
            let bgHex = t.primaryColorHex ?? "2563EB"
            let fgHex = t.accentColorHex ?? "F59E0B"
            let requiredStamps = Int(t.requiredStamps)
            var logoBase64: String? = nil
            var logoUrl: String? = nil
            let trimmedLogo = logoURL.trimmingCharacters(in: .whitespaces)
            if !trimmedLogo.isEmpty {
                if trimmedLogo.lowercased().hasPrefix("http://") || trimmedLogo.lowercased().hasPrefix("https://") {
                    let url = URL(string: trimmedLogo)
                    if let url, url.host() != APIConfig.baseURL.host() || !url.path.contains("/logo") {
                        logoUrl = trimmedLogo
                    }
                } else if trimmedLogo.contains("CardLogos") || trimmedLogo.hasPrefix("/") {
                    logoBase64 = CardLogoStorage.compressedBase64FromFile(path: trimmedLogo)
                }
            }
            // Si vide : on n'envoie pas (nil) pour ne pas effacer le logo côté serveur
            do {
                _ = try await APIClient.shared.request(APIEndpoint.updateCardSettings(
                    slug: slug,
                    organizationName: finalName,
                    backgroundColor: bgHex,
                    foregroundColor: fgHex,
                    requiredStamps: requiredStamps,
                    logoBase64: logoBase64,
                    logoUrl: logoUrl,
                    locationAddress: address.isEmpty ? nil : address.trimmingCharacters(in: .whitespaces),
                    stampEmoji: t.stampEmoji.flatMap { $0.isEmpty ? nil : $0 },
                    cardBackgroundBase64: nil,
                    programType: nil,
                    pointsPerEuro: nil,
                    pointsPerVisit: nil,
                    pointsMinAmountEur: nil,
                    pointsRewardTiers: nil,
                    stampRewardLabel: nil,
                    expiryMonths: nil,
                    sector: nil
                )) as EmptyResponse
                // Après envoi réussi du logo : utiliser l’URL API pour affichage persistant (plus de dépendance au chemin local).
                if logoBase64 != nil {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let apiLogoURL = "\(base)/api/businesses/\(slug)/logo"
                    t.logoURL = apiLogoURL
                    let b = dataService.createOrGetCurrentBusiness()
                    b.logoURL = apiLogoURL
                    try? viewContext.save()
                    logoURL = apiLogoURL
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoUploadAtKey)
                }
            } catch {
                // Enregistré en local
            }
        }

        await MainActor.run {
            isSaving = false
            savedMessage = "Enregistré"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                savedMessage = nil
            }
        }
    }

    private func loadLogoFromPicker(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let path = CardLogoStorage.saveImage(image)
        await MainActor.run {
            logoURL = path ?? ""
            logoPhotoItem = nil
            if let p = path {
                dataService.updateBusiness(name: nil, email: nil, phone: nil, address: nil, logoURL: p)
                if let t = dataService.currentCardTemplate() {
                    t.logoURL = p
                    t.updatedAt = Date()
                    try? viewContext.save()
                }
            }
        }
    }

    private func sendNotificationToClients() {
        let msg = notificationMessage.trimmingCharacters(in: .whitespaces)
        guard !msg.isEmpty else { return }
        guard let slug = AuthStorage.currentBusinessSlug else {
            notifyResultSuccess = false
            notifyResultMessage = "Aucun commerce. Rechargez l’app."
            return
        }
        isSendingNotification = true
        notifyResultMessage = nil
        Task {
            do {
                _ = try await APIClient.shared.request(APIEndpoint.notifyClients(slug: slug, message: msg, categoryIds: nil)) as EmptyResponse
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultSuccess = true
                    notifyResultMessage = "Notification envoyée."
                    notificationMessage = ""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        notifyResultMessage = nil
                    }
                }
            } catch {
                await MainActor.run {
                    isSendingNotification = false
                    notifyResultSuccess = false
                    notifyResultMessage = (error as? APIError)?.errorDescription ?? "Erreur lors de l’envoi."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        notifyResultMessage = nil
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(AuthService())
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
}
