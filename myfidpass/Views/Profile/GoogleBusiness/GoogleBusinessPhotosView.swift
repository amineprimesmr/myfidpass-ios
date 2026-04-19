//
//  GoogleBusinessPhotosView.swift
//  myfidpass
//
//  Gestion des photos de la fiche Google Business. Ajout via URL publique (https://).
//

import SwiftUI
import Combine

@MainActor
final class GoogleBusinessPhotosVM: ObservableObject {
    @Published var media: [GoogleBusinessMedia] = []
    @Published var isLoading: Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?

    private let slug: String
    init(slug: String) { self.slug = slug }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            self.media = try await GoogleBusinessAPI.shared.listMedia(slug: slug)
            self.errorMessage = nil
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func addFromURL(_ url: String, category: String) async -> Bool {
        guard !isUploading else { return false }
        isUploading = true
        defer { isUploading = false }
        do {
            self.media = try await GoogleBusinessAPI.shared.createMedia(slug: slug, sourceUrl: url, category: category)
            errorMessage = nil
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return false
        }
    }

    func delete(_ m: GoogleBusinessMedia) async {
        do {
            try await GoogleBusinessAPI.shared.deleteMedia(slug: slug, mediaId: m.mediaId)
            await load()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct GoogleBusinessPhotosView: View {
    let slug: String
    @StateObject private var vm: GoogleBusinessPhotosVM
    @State private var showAdd = false

    init(slug: String) {
        self.slug = slug
        _vm = StateObject(wrappedValue: GoogleBusinessPhotosVM(slug: slug))
    }

    var body: some View {
        Group {
            if vm.isLoading && vm.media.isEmpty {
                ProgressView().padding(40)
            } else if vm.media.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(vm.media) { m in
                            mediaCell(m)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(AppTheme.Colors.background.ignoresSafeArea())
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(AppTheme.Colors.primary)
                }
            }
        }
        .task { await vm.load() }
        .refreshable { await vm.load() }
        .sheet(isPresented: $showAdd) {
            GoogleBusinessAddPhotoSheet { url, category in
                Task {
                    _ = await vm.addFromURL(url, category: category)
                }
            }
        }
    }

    @ViewBuilder
    private func mediaCell(_ m: GoogleBusinessMedia) -> some View {
        ZStack(alignment: .topTrailing) {
            if let url = (m.thumbnailUrl ?? m.googleUrl).flatMap(URL.init(string:)) {
                AsyncImage(url: url) { img in
                    img.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(AppTheme.Colors.textSecondary.opacity(0.15))
                }
                .frame(height: 120)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Menu {
                Button(role: .destructive) {
                    Task { await vm.delete(m) }
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(6)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))
            Text("Aucune photo sur votre fiche")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Colors.textSecondary)
            Text("Ajoutez des photos d'intérieur, d'extérieur, de vos produits pour rassurer vos futurs clients.")
                .font(.footnote)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                showAdd = true
            } label: {
                Label("Ajouter une photo", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(AppTheme.Colors.primary))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct GoogleBusinessAddPhotoSheet: View {
    var onSubmit: (_ sourceUrl: String, _ category: String) -> Void

    @State private var sourceUrl: String = ""
    @State private var category: String = "ADDITIONAL"
    @Environment(\.dismiss) private var dismiss

    private let categories: [(String, String)] = [
        ("ADDITIONAL", "Photo générique"),
        ("COVER", "Couverture"),
        ("PROFILE", "Profil"),
        ("LOGO", "Logo"),
        ("EXTERIOR", "Extérieur"),
        ("INTERIOR", "Intérieur"),
        ("PRODUCT", "Produit"),
        ("AT_WORK", "Au travail"),
        ("FOOD_AND_DRINK", "Plats / boissons"),
        ("MENU", "Menu"),
        ("TEAMS", "Équipe"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("URL de la photo (publique https://)") {
                    TextField("https://…/photo.jpg", text: $sourceUrl)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                }
                Section("Catégorie") {
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.0) { Text($0.1).tag($0.0) }
                    }
                }
                Section {
                    Text("Google télécharge l'image depuis l'URL fournie. Hébergez-la publiquement (ex. Imgur, Cloudinary, votre site).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ajouter une photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ajouter") {
                        let t = sourceUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty {
                            onSubmit(t, category)
                            dismiss()
                        }
                    }
                    .font(.body.weight(.semibold))
                    .disabled(sourceUrl.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
