//
//  MyCardEditView.swift
//  myfidpass
//
//  Vue d’édition complète de la carte : nom, logo, tampons, couleurs. Aperçu live en haut.
//

import SwiftUI
import PhotosUI

struct MyCardEditView: View {
    @Binding var displayName: String
    @Binding var requiredStamps: Int
    @Binding var primaryHex: String
    @Binding var accentHex: String
    @Binding var logoURL: String
    @Binding var logoPhotoItem: PhotosPickerItem?
    @Binding var isPresented: Bool
    var onSave: () async -> Void

    @State private var savedFeedback = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    livePreviewBlock
                    editForm
                }
                .padding(.bottom, 32)
            }
            .background(AppTheme.Colors.background)
            .navigationTitle("Modifier la carte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        isPresented = false
                    }
                    .foregroundStyle(AppTheme.Colors.primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .scaleEffect(0.9)
                        } else {
                            Text(savedFeedback ? "Enregistré" : "Enregistrer")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(savedFeedback ? AppTheme.Colors.success : AppTheme.Colors.primary)
                    .disabled(savedFeedback || isSaving)
                }
            }
            .onChange(of: requiredStamps) { _, new in
                // Rien à faire, le parent gère previewStampsCount
            }
        }
    }

    // MARK: - Aperçu live compact (format Wallet)

    private var livePreviewBlock: some View {
        VStack(spacing: 12) {
            Text("Aperçu en direct")
                .font(AppTheme.Fonts.caption())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            WalletCardPreview(
                displayName: displayName.isEmpty ? "Nom de la carte" : displayName,
                requiredStamps: Int32(requiredStamps),
                stampsCount: Int32(min(3, requiredStamps)),
                primaryColorHex: primaryHex,
                accentColorHex: accentHex,
                logoURL: logoURL.isEmpty ? nil : logoURL,
                compact: true
            )
            .frame(height: 100)
            .padding(.horizontal, 20)
        }
        .padding(.top, 16)
        .padding(.bottom, 24)
    }

    // MARK: - Formulaire

    private var editForm: some View {
        VStack(alignment: .leading, spacing: 24) {
            nameSection
            logoSection
            stampsSection
            colorsSection
        }
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Nom de la carte", systemImage: "textformat")
                .font(AppTheme.Fonts.subheadline().weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            TextField("Ex: Carte Café, Ma Boulangerie", text: $displayName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.2), lineWidth: 1)
                )
                .autocorrectionDisabled()
        }
    }

    private var logoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Logo", systemImage: "photo")
                .font(AppTheme.Fonts.subheadline().weight(.semibold))
                .foregroundStyle(AppTheme.Colors.textPrimary)

            TextField("URL de l’image (https://…)", text: $logoURL)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.cardBackground)
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
                        Label("Supprimer", systemImage: "trash")
                            .font(AppTheme.Fonts.caption())
                    }
                }
            }
        }
    }

    private var stampsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Tampons pour une récompense", systemImage: "star.circle")
                .font(AppTheme.Fonts.subheadline().weight(.semibold))
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

    private var colorsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Couleurs", systemImage: "paintpalette")
                .font(AppTheme.Fonts.subheadline().weight(.semibold))
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

    private func saveAndDismiss() {
        guard !isSaving else { return }
        isSaving = true
        Task {
            await onSave()
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.2)) { savedFeedback = true }
            }
            try? await Task.sleep(nanoseconds: 600_000_000)
            await MainActor.run {
                isSaving = false
                isPresented = false
            }
        }
    }
}
