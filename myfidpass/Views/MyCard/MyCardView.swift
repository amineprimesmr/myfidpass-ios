//
//  MyCardView.swift
//  myfidpass
//
//  Aperçu en direct et personnalisation de la carte wallet. UX centrée sur le rendu temps réel.
//

import SwiftUI
import CoreData
import PassKit
import PhotosUI
import UIKit

enum CardPreviewFormat: String, CaseIterable {
    case wallet
    case creditCard
    case stampGrid
    /// Design dédié avec grille de tampons visible (Café des Arts).
    case cafeDesArts
}

struct MyCardView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var displayName: String = ""
    @State private var requiredStamps: Int = 10
    @State private var primaryHex: String = "2563EB"
    @State private var accentHex: String = "F59E0B"
    @State private var logoURL: String = ""
    @State private var stampEmoji: String = ""
    @State private var logoPhotoItem: PhotosPickerItem?
    /// Aperçu simulé : nombre de tampons affichés sur la carte (0 à requiredStamps).
    @State private var previewStampsCount: Int = 0
    @State private var savedFeedback = false
    /// Données du pass pour afficher la feuille « Ajouter à l’Apple Wallet ».
    /// Mode édition inline : la carte reste visible, les champs apparaissent en dessous (pas de sheet).
    @State private var isEditingCard = false
    @State private var isSaving = false
    @State private var walletPassData: Data?
    @State private var walletLoading = false
    @State private var walletErrorMessage: String?
    @State private var saveLogoError: String?
    @State private var showOnboardingStyle = false
    @State private var showDesignsGallery = false

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    /// Marge basse pour que le contenu reste visible au-dessus de la barre d’onglets.
    private let bottomScrollPadding: CGFloat = 100

    /// Design dédié « Café des Arts » (grille tampons visible) quand le nom correspond.
    private var isCafeDesArts: Bool {
        let name = displayName.trimmingCharacters(in: .whitespaces)
        return name.localizedCaseInsensitiveContains("Café des Arts") || name == "Cafe des Arts"
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: AppTheme.Spacing.lg) {
                    previewSection
                    if isEditingCard {
                        editFormSection
                    } else {
                        actionsSection
                    }
                }
                .padding(.bottom, bottomScrollPadding)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(AppTheme.Colors.background)
            .navigationTitle("Ma Carte")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            showOnboardingStyle = true
                        } label: {
                            Label("Onboarding", systemImage: "rectangle.stack.fill")
                        }
                        .foregroundStyle(AppTheme.Colors.primary)
                        Button {
                            showDesignsGallery = true
                        } label: {
                            Label("Designs", systemImage: "paintbrush.pointed.fill")
                        }
                        .foregroundStyle(AppTheme.Colors.primary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showOnboardingStyle) {
                OnboardingStylePageView()
            }
            .fullScreenCover(isPresented: $showDesignsGallery) {
                NavigationStack {
                    CardDesignsGalleryView(
                        onApplyDesign: { preset in
                            applyDesignFromGallery(preset)
                            showDesignsGallery = false
                        },
                        onDismiss: { showDesignsGallery = false }
                    )
                }
            }
            .onAppear { loadCurrentTemplate() }
            .onChange(of: requiredStamps) { _, new in
                if previewStampsCount > new { previewStampsCount = new }
            }
            .animation(.easeInOut(duration: 0.25), value: isEditingCard)
            .overlay {
                if walletPassData != nil {
                    AddToWalletPresenter(passData: walletPassData) {
                        walletPassData = nil
                    }
                    .frame(width: 1, height: 1)
                }
            }
            .alert("Apple Wallet", isPresented: .constant(walletErrorMessage != nil)) {
                Button("OK") { walletErrorMessage = nil }
            } message: {
                if let msg = walletErrorMessage { Text(msg) }
            }
            .alert("Logo non synchronisé", isPresented: .constant(saveLogoError != nil)) {
                Button("OK") { saveLogoError = nil }
            } message: {
                if let msg = saveLogoError { Text(msg) }
            }
        }
    }

    // MARK: - Aperçu carte (Wallet uniquement)

    private let previewMaxHeight: CGFloat = 320

    private var previewSection: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Text("Aperçu comme dans le Wallet")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.6)

            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(AppTheme.Colors.shadow)
                    .blur(radius: 18)
                    .offset(y: 6)
                    .opacity(0.4)

                Group {
                    if isCafeDesArts {
                        CafeDesArtsCardPreview(
                            displayName: displayName.isEmpty ? "Café des Arts" : displayName,
                            requiredStamps: Int32(requiredStamps),
                            stampsCount: Int32(previewStampsCount),
                            primaryColorHex: primaryHex,
                            accentColorHex: accentHex,
                            logoURL: logoURL.isEmpty ? nil : logoURL,
                            stampEmoji: stampEmoji.isEmpty ? nil : stampEmoji,
                            compact: false
                        )
                    } else {
                        WalletCardPreview(
                            displayName: displayName.isEmpty ? "Ma Carte Fidélité" : displayName,
                            requiredStamps: Int32(requiredStamps),
                            stampsCount: Int32(previewStampsCount),
                            primaryColorHex: primaryHex,
                            accentColorHex: accentHex,
                            logoURL: logoURL.isEmpty ? nil : logoURL,
                            stampEmoji: stampEmoji.isEmpty ? nil : stampEmoji,
                            compact: false
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.lg)
                .frame(maxHeight: previewMaxHeight)
            }
            .id("\(primaryHex)-\(accentHex)-\(displayName)-\(requiredStamps)-\(previewStampsCount)")
            .padding(.vertical, AppTheme.Spacing.sm)

            Text("Simuler les tampons : \(previewStampsCount)/\(requiredStamps)")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)

            Slider(
                value: Binding(
                    get: { Double(previewStampsCount) },
                    set: { previewStampsCount = Int($0.rounded()) }
                ),
                in: 0...Double(max(1, requiredStamps))
            )
            .tint(AppTheme.Colors.primary)
            .padding(.horizontal, AppTheme.Spacing.xl)

            // Bouton : tester la carte dans l’Apple Wallet
        }
        .padding(.top, AppTheme.Spacing.lg)
        .padding(.bottom, AppTheme.Spacing.md)
    }

    // MARK: - Boutons d'action (mode aperçu)

    private var actionsSection: some View {
        VStack(spacing: 14) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isEditingCard = true }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed.fill")
                        .font(.title3)
                    Text("Modifier la carte")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)

            addToWalletButton
        }
        .padding(.horizontal, AppTheme.Spacing.lg)
        .padding(.top, AppTheme.Spacing.lg)
    }

    // MARK: - Formulaire d'édition inline (la carte reste visible au-dessus)

    private var editFormSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Personnalisation")
                .font(.headline)
                .foregroundStyle(AppTheme.Colors.textPrimary)
                .padding(.horizontal, AppTheme.Spacing.lg)
                .padding(.top, 24)
                .padding(.bottom, 12)

            VStack(alignment: .leading, spacing: 20) {
                editNameBlock
                editLogoBlock
                editStampEmojiBlock
                editStampsBlock
                editColorsBlock
            }
            .padding(AppTheme.Spacing.lg)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, AppTheme.Spacing.lg)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isEditingCard = false }
                } label: {
                    Text("Terminer")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.Colors.textPrimary)

                Button {
                    saveAndStayInEditMode()
                } label: {
                    HStack(spacing: 8) {
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else if savedFeedback {
                            Image(systemName: "checkmark.circle.fill")
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Text(isSaving ? "Enregistrement…" : (savedFeedback ? "Enregistré" : "Enregistrer"))
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(savedFeedback ? AppTheme.Colors.success : AppTheme.Colors.primary)
                .disabled(isSaving)
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, 20)
            .padding(.bottom, 8)
        }
    }

    private var editNameBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nom de l'établissement", systemImage: "textformat")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            TextField("Ex: Café du coin, Ma Boulangerie", text: $displayName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
                .autocorrectionDisabled()
        }
    }

    private var editLogoBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Logo sur la carte", systemImage: "photo")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            TextField("URL de l'image (https://…)", text: $logoURL)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $logoPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Importer une image", systemImage: "photo.on.rectangle.angled")
                        .font(.callout)
                }
                .onChange(of: logoPhotoItem) { _, new in
                    Task { await loadLogoFromPicker(new) }
                }
                if !logoURL.isEmpty {
                    Button(role: .destructive) {
                        logoURL = ""
                        logoPhotoItem = nil
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }
        }
    }

    private var editStampEmojiBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Emoji sur la carte", systemImage: "face.smiling")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Un emoji affiché à côté des points (ex. ☕ pour un café, 🍔 pour un burger)")
                .font(.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(StampEmojiPresets.all, id: \.self) { emoji in
                        Button {
                            stampEmoji = stampEmoji == emoji ? "" : emoji
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                                .frame(width: 44, height: 44)
                                .background((stampEmoji == emoji ? AppTheme.Colors.primary.opacity(0.2) : Color.clear))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        stampEmoji = ""
                    } label: {
                        Text("Aucun")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                            .frame(width: 60, height: 44)
                            .background(stampEmoji.isEmpty ? AppTheme.Colors.primary.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var editStampsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tampons pour une récompense", systemImage: "star.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            HStack(spacing: 16) {
                Text("\(requiredStamps)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .frame(minWidth: 32, alignment: .trailing)
                Slider(
                    value: Binding(
                        get: { Double(requiredStamps) },
                        set: { requiredStamps = Int($0.rounded()) }
                    ),
                    in: 5...30,
                    step: 1
                )
                .tint(AppTheme.Colors.primary)
            }
            .padding(.vertical, 4)
        }
    }

    private var editColorsBlock: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Couleurs", systemImage: "paintpalette")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)
            ColorPickerRow(
                title: "Couleur principale",
                subtitle: "Fond de la carte",
                hex: $primaryHex
            )
            ColorPickerRow(
                title: "Couleur des points",
                subtitle: "Tampons et compteur",
                hex: $accentHex
            )
        }
    }

    private func saveAndStayInEditMode() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await saveTemplate()
            await MainActor.run {
                triggerSavedFeedback()
                isSaving = false
            }
        }
    }

    private var addToWalletButton: some View {
        Button {
            addToWalletTapped()
        } label: {
            HStack(spacing: 10) {
                if walletLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "wallet.pass.fill")
                        .font(.title3)
                }
                Text(walletLoading ? "Chargement…" : "Tester dans l’Apple Wallet")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black)
        .disabled(walletLoading || !PKAddPassesViewController.canAddPasses())
    }

    private func addToWalletTapped() {
        walletLoading = true
        walletErrorMessage = nil
        Task {
            // Enregistrer d’abord le design actuel (celui affiché, y compris en mode Grille) pour que le pass Wallet le reflète.
            await saveTemplate()

            var slug = AuthStorage.currentBusinessSlug
            if slug == nil, AuthStorage.isLoggedIn {
                await syncService.syncIfNeeded()
                slug = AuthStorage.currentBusinessSlug
            }
            guard let slug else {
                await MainActor.run {
                    walletLoading = false
                    walletErrorMessage = "Votre commerce n’a pas encore été chargé. Vérifiez votre connexion, tirez pour actualiser le tableau de bord puis réessayez."
                }
                return
            }
            guard let template = dataService.currentCardTemplate() else {
                await MainActor.run {
                    walletLoading = false
                    walletErrorMessage = "Données du commerce manquantes. Actualisez le tableau de bord puis réessayez."
                }
                return
            }
            let members = dataService.clientCards(for: template)
            guard let memberId = members.first?.qrCodeValue, !memberId.isEmpty else {
                await MainActor.run {
                    walletLoading = false
                    walletErrorMessage = "Aucun membre. Synchronisez le tableau de bord (tirez pour actualiser) ou ajoutez un client pour tester le pass."
                }
                return
            }
            let design = WalletPassDesign(
                organizationName: displayName.trimmingCharacters(in: .whitespaces).isEmpty ? "Ma Carte Fidélité" : displayName.trimmingCharacters(in: .whitespaces),
                backgroundColor: primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex,
                foregroundColor: accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex,
                stampEmoji: stampEmoji,
                requiredStamps: requiredStamps,
                template: isCafeDesArts ? "cafe" : nil
            )
            do {
                let data = try await APIClient.shared.requestData(.walletPass(slug: slug, memberId: memberId, design: design))
                await MainActor.run {
                    walletLoading = false
                    walletPassData = data
                }
            } catch APIError.notFound {
                await MainActor.run {
                    walletLoading = false
                    walletErrorMessage = "Pass non trouvé pour ce membre. Réessayez ou ajoutez un client."
                }
            } catch {
                await MainActor.run {
                    walletLoading = false
                    walletErrorMessage = (error as? APIError)?.errorDescription ?? "Impossible de charger le pass. Réessayez plus tard."
                }
            }
        }
    }

    // MARK: - Section personnalisation du design

    private var designSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
            Label("Personnaliser le design", systemImage: "paintbrush.fill")
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)

            VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
                // Nom de la carte
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Nom de la carte")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    TextField("Ex: Carte Café", text: $displayName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.background)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                                .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                        )
                        .autocorrectionDisabled()
                }

                // Logo
                logoSection

                // Nombre de tampons pour une récompense
                VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                    Text("Tampons pour une récompense")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    HStack {
                        Text("\(requiredStamps)")
                            .font(AppTheme.Fonts.title2())
                            .foregroundStyle(AppTheme.Colors.primary)
                            .frame(width: 36, alignment: .trailing)
                        Slider(value: Binding(
                            get: { Double(requiredStamps) },
                            set: { requiredStamps = Int($0.rounded()) }
                        ), in: 5...30, step: 1)
                            .tint(AppTheme.Colors.primary)
                    }
                }

                // Couleur principale
                ColorPickerRow(
                    title: "Couleur principale",
                    subtitle: "Fond de la carte",
                    hex: $primaryHex
                )

                // Couleur des points
                ColorPickerRow(
                    title: "Couleur des points",
                    subtitle: "Tampons et compteur",
                    hex: $accentHex
                )

                // Bouton enregistrer
                Button {
                    Task {
                        await saveTemplate()
                        triggerSavedFeedback()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if savedFeedback {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(AppTheme.Colors.success)
                        }
                        Text(savedFeedback ? "Enregistré" : "Enregistrer le design")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppTheme.Spacing.md)
                }
                .buttonStyle(.borderedProminent)
                .tint(savedFeedback ? AppTheme.Colors.success : AppTheme.Colors.primary)
                .padding(.top, AppTheme.Spacing.sm)
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg))
            .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    private var logoSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Logo de la carte")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("URL de l’image ou choisir une photo")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)

            TextField("https://… ou laisser vide", text: $logoURL)
                .textFieldStyle(.plain)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)
                .background(AppTheme.Colors.background)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.sm)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: AppTheme.Spacing.sm) {
                PhotosPicker(
                    selection: $logoPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Choisir une photo", systemImage: "photo.on.rectangle.angled")
                        .font(AppTheme.Fonts.callout())
                }
                .onChange(of: logoPhotoItem) { _, new in
                    Task { await loadLogoFromPicker(new) }
                }

                if !logoURL.isEmpty {
                    Button(role: .destructive) {
                        logoURL = ""
                        logoPhotoItem = nil
                    } label: {
                        Label("Supprimer le logo", systemImage: "trash")
                            .font(AppTheme.Fonts.caption())
                    }
                }
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
            if path != nil { logoPhotoItem = nil }
        }
    }

    private func loadCurrentTemplate() {
        let t = dataService.createOrGetCurrentCardTemplate()
        displayName = t.displayName ?? "Ma Carte Fidélité"
        requiredStamps = Int(t.requiredStamps)
        primaryHex = t.primaryColorHex ?? "2563EB"
        accentHex = t.accentColorHex ?? "F59E0B"
        logoURL = t.logoURL ?? ""
        stampEmoji = t.stampEmoji ?? ""
        previewStampsCount = min(3, requiredStamps)
    }

    /// Applique un design de la galerie à la carte, enregistre en local et pousse vers le backend (affiché dans le Wallet).
    /// On met à jour le template Core Data tout de suite pour que loadCurrentTemplate() (onAppear au retour) ne réécrive pas avec d’anciennes données.
    private func applyDesignFromGallery(_ preset: CardDesignPreset) {
        displayName = preset.displayName
        primaryHex = preset.primaryHex
        accentHex = preset.accentHex
        stampEmoji = preset.stampEmoji ?? ""
        requiredStamps = Int(preset.requiredStamps)
        if previewStampsCount > requiredStamps {
            previewStampsCount = requiredStamps
        }
        let nameFinal = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? "Ma Carte Fidélité" : displayName.trimmingCharacters(in: .whitespaces)
        dataService.updateCardTemplate(
            displayName: nameFinal,
            requiredStamps: Int32(requiredStamps),
            primaryColorHex: primaryHex,
            accentColorHex: accentHex,
            logoURL: logoURL.isEmpty ? nil : logoURL,
            stampEmoji: stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(8))
        )
        Task {
            await saveTemplate()
            await MainActor.run { triggerSavedFeedback() }
        }
    }

    private func saveTemplate() async {
        let nameToSave = displayName.trimmingCharacters(in: .whitespaces)
        let nameFinal = nameToSave.isEmpty ? "Ma Carte Fidélité" : nameToSave
        let bgHex = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
        let fgHex = accentHex.hasPrefix("#") ? String(accentHex.dropFirst()) : accentHex

        dataService.updateCardTemplate(
            displayName: nameFinal,
            requiredStamps: Int32(requiredStamps),
            primaryColorHex: primaryHex,
            accentColorHex: accentHex,
            logoURL: logoURL.isEmpty ? nil : logoURL,
            stampEmoji: stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(8))
        )
        UserDefaults.standard.set(Date(), forKey: "myfidpass.templateLastSavedAt")

        if let slug = AuthStorage.currentBusinessSlug {
            var logoBase64: String? = nil
            var logoUrl: String? = nil
            if !logoURL.isEmpty {
                let trimmed = logoURL.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
                    let url = URL(string: trimmed)
                    if let url, url.host() != APIConfig.baseURL.host() || !url.path.contains("/logo") {
                        logoUrl = trimmed
                    }
                } else if trimmed.contains("CardLogos") || trimmed.hasPrefix("/") {
                    logoBase64 = CardLogoStorage.compressedBase64FromFile(path: trimmed)
                }
            } else {
                logoBase64 = ""
            }
            do {
                _ = try await APIClient.shared.request(APIEndpoint.updateCardSettings(
                    slug: slug,
                    organizationName: nameFinal,
                    backgroundColor: bgHex,
                    foregroundColor: fgHex,
                    requiredStamps: requiredStamps,
                    logoBase64: logoBase64,
                    logoUrl: logoUrl,
                    locationAddress: nil,
                    stampEmoji: stampEmoji.isEmpty ? nil : String(stampEmoji.prefix(8))
                )) as EmptyResponse
                await MainActor.run { saveLogoError = nil }
                if let sentBase64 = logoBase64, !sentBase64.isEmpty {
                    let base = APIConfig.baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                    let apiLogoURL = "\(base)/api/businesses/\(slug)/logo"
                    if let t = dataService.currentCardTemplate() {
                        t.logoURL = apiLogoURL
                        t.updatedAt = Date()
                    }
                    let b = dataService.createOrGetCurrentBusiness()
                    b.logoURL = apiLogoURL
                    try? viewContext.save()
                    logoURL = apiLogoURL
                    UserDefaults.standard.set(Date(), forKey: SyncService.lastLogoUploadAtKey)
                }
            } catch {
                await MainActor.run {
                    saveLogoError = "Le logo n'a pas été synchronisé avec le logiciel. Vérifiez la connexion et réessayez."
                }
            }
        }
    }

    private func triggerSavedFeedback() {
        withAnimation(.easeOut(duration: 0.2)) { savedFeedback = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.2)) { savedFeedback = false }
        }
    }
}

// MARK: - Ligne de choix de couleur (palette + sélection) — partagé avec MyCardEditView

struct ColorPickerRow: View {
    let title: String
    let subtitle: String
    @Binding var hex: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                Text(subtitle)
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(MyCardPresetColors.all, id: \.hex) { preset in
                        ColorPresetButton(hex: preset.hex, name: preset.name, isSelected: hex == preset.hex) {
                            withAnimation(.easeOut(duration: 0.2)) { hex = preset.hex }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

struct ColorPresetButton: View {
    let hex: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 40, height: 40)
                    Circle()
                        .strokeBorder(isSelected ? Color(hex: hex).opacity(0.6) : Color.clear, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1)
                    }
                }
                Text(name)
                    .font(.system(.caption2, design: .default, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Emojis pour la carte (points / tampons)

enum StampEmojiPresets {
    static let all: [String] = ["☕", "🍔", "⭐", "🎁", "🍕", "🌸", "💄", "✂️", "🍰", "🛍️"]
}

// MARK: - Palette de couleurs

enum MyCardPresetColors {
    static let all: [(name: String, hex: String)] = [
        ("Bleu", "2563EB"),
        ("Vert", "10B981"),
        ("Violet", "8B5CF6"),
        ("Ambre", "F59E0B"),
        ("Rouge", "EF4444"),
        ("Indigo", "4F46E5"),
        ("Teal", "14B8A6"),
        ("Rose", "EC4899"),
    ]
}

#Preview {
    MyCardView(context: PersistenceController.preview.container.viewContext)
        .environmentObject(SyncService(context: PersistenceController.preview.container.viewContext))
}
