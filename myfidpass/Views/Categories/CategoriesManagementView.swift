//
//  CategoriesManagementView.swift
//  myfidpass
//
//  Gestion des catégories de membres : créer, modifier, supprimer, assigner les membres.
//

import SwiftUI
import CoreData

struct CategoriesManagementView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService
    @State private var showAddCategory = false
    @State private var categoryToEdit: MemberCategory?
    @State private var categoryToDelete: MemberCategory?
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var template: CardTemplate? { dataService.currentCardTemplate() }
    private var categories: [MemberCategory] {
        guard let t = template else { return [] }
        return dataService.categories(for: t)
    }

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty && !showAddCategory {
                    emptyState
                } else {
                    List {
                        ForEach(categories, id: \.serverId) { category in
                            categoryRow(category)
                        }
                        .onDelete(perform: deleteCategoriesAt)
                    }
                }
            }
            .navigationTitle("Catégories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddCategory = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showAddCategory) {
                CategoryEditSheet(mode: .create, onSave: { name, colorHex in
                    Task { await createCategory(name: name, colorHex: colorHex) }
                    showAddCategory = false
                }, onCancel: { showAddCategory = false })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .modifier(LiquidGlassSheetModifier())
            }
            .sheet(item: Binding(
                get: { categoryToEdit.map { IdentifiableCategory(category: $0) } },
                set: { categoryToEdit = $0?.category }
            )) { wrap in
                CategoryEditSheet(mode: .edit(wrap.category), onSave: { name, colorHex in
                    Task { await updateCategory(wrap.category, name: name, colorHex: colorHex) }
                    categoryToEdit = nil
                }, onCancel: { categoryToEdit = nil })
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .modifier(LiquidGlassSheetModifier())
            }
            .alert("Supprimer la catégorie ?", isPresented: .constant(categoryToDelete != nil)) {
                Button("Annuler", role: .cancel) { categoryToDelete = nil }
                Button("Supprimer", role: .destructive) {
                    if let cat = categoryToDelete {
                        Task { await deleteCategory(cat) }
                    }
                    categoryToDelete = nil
                }
            } message: {
                if let cat = categoryToDelete {
                    Text("« \(cat.name ?? "") » sera supprimée. Les membres ne seront pas supprimés.")
                }
            }
            .alert("Erreur", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.primary.opacity(0.6))
            Text("Aucune catégorie")
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Créez des catégories pour classer vos membres (ex. classes, promotions) et cibler vos notifications.")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button {
                showAddCategory = true
            } label: {
                Label("Créer une catégorie", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func categoryRow(_ category: MemberCategory) -> some View {
        NavigationLink {
            CategoryMembersView(category: category, dataService: dataService)
        } label: {
            HStack {
                if let hex = category.colorHex, !hex.isEmpty {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 12, height: 12)
                }
                Text(category.name ?? "Sans nom")
                    .font(AppTheme.Fonts.body())
                Spacer()
                Text("\(dataService.memberCount(for: category))")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                categoryToDelete = category
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
            Button {
                categoryToEdit = category
            } label: {
                Label("Modifier", systemImage: "pencil")
            }
            .tint(AppTheme.Colors.primary)
        }
    }

    private func deleteCategoriesAt(_ offsets: IndexSet) {
        for index in offsets {
            if index < categories.count {
                categoryToDelete = categories[index]
                return
            }
        }
    }

    private func createCategory(name: String, colorHex: String?) async {
        guard let slug = AuthStorage.currentBusinessSlug else {
            errorMessage = "Aucun commerce."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await APIClient.shared.request(.createCategory(slug: slug, name: name, colorHex: colorHex, sortOrder: nil)) as CategoryDTO
            await syncService.syncAfterServerMutation()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func updateCategory(_ category: MemberCategory, name: String, colorHex: String?) async {
        guard let slug = AuthStorage.currentBusinessSlug, let id = category.serverId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await APIClient.shared.request(.updateCategory(slug: slug, categoryId: id, name: name, colorHex: colorHex, sortOrder: nil)) as CategoryDTO
            category.name = name
            category.colorHex = colorHex
            try? viewContext.save()
            await syncService.syncAfterServerMutation()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func deleteCategory(_ category: MemberCategory) async {
        guard let slug = AuthStorage.currentBusinessSlug, let id = category.serverId else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await APIClient.shared.request(.deleteCategory(slug: slug, categoryId: id)) as EmptyResponse
            viewContext.delete(category)
            try? viewContext.save()
            await syncService.syncAfterServerMutation()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

private struct IdentifiableCategory: Identifiable {
    let category: MemberCategory
    var id: String { category.serverId ?? "" }
}

// MARK: - Category edit sheet

struct CategoryEditSheet: View {
    enum Mode {
        case create
        case edit(MemberCategory)
    }
    let mode: Mode
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var colorHex: String = ""

    private var sheetTitle: String {
        mode.isCreate ? "Nouvelle catégorie" : "Modifier"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var colorHexDigitsNorm: String {
        colorHex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
    }

    private var colorPaletteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    categoryColorSwatch(hex6: nil, isNone: true)
                    ForEach(AppVibrantColorPalette.hex6, id: \.self) { h in
                        categoryColorSwatch(hex6: h, isNone: false)
                    }
                }
            }
            if !colorHexDigitsNorm.isEmpty, !AppVibrantColorPalette.containsHex6(colorHexDigitsNorm) {
                Text("Cette couleur n’est pas dans la palette. Choisis une des pastilles pour unifier l’app.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func categoryColorSwatch(hex6: String?, isNone: Bool) -> some View {
        let selected: Bool = {
            if isNone { return colorHexDigitsNorm.isEmpty }
            guard let hex6 else { return false }
            return colorHexDigitsNorm == hex6
        }()
        return Button {
            if isNone {
                colorHex = ""
            } else if let hex6 {
                colorHex = hex6
            }
        } label: {
            ZStack {
                if isNone {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    Image(systemName: "slash.circle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                } else {
                    Circle()
                        .fill(Color(hex: hex6 ?? "000000"))
                        .frame(width: 36, height: 36)
                }
                Circle()
                    .strokeBorder(selected ? AppTheme.Colors.primary : Color.black.opacity(0.12), lineWidth: selected ? 3 : 1)
                    .frame(width: 40, height: 40)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isNone ? "Aucune couleur" : "Couleur #\(hex6 ?? "")")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    if #available(iOS 26.0, *) {
                        Button("Annuler", action: onCancel)
                            .buttonStyle(.glass(.regular))
                            .buttonBorderShape(.capsule)
                            .controlSize(.regular)
                    } else {
                        Button("Annuler", action: onCancel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                    Spacer(minLength: 8)
                    Text(sheetTitle)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if #available(iOS 26.0, *) {
                        Button("Enregistrer") {
                            let hex = colorHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : colorHex.trimmingCharacters(in: .whitespaces)
                            onSave(name.trimmingCharacters(in: .whitespaces), hex)
                        }
                        .disabled(!canSave)
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                        .tint(AppTheme.Colors.primary)
                    } else {
                        Button("Enregistrer") {
                            let hex = colorHex.trimmingCharacters(in: .whitespaces).isEmpty ? nil : colorHex.trimmingCharacters(in: .whitespaces)
                            onSave(name.trimmingCharacters(in: .whitespaces), hex)
                        }
                        .disabled(!canSave)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(canSave ? AppTheme.Colors.primary : AppTheme.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Form {
                    Section("Nom") {
                        TextField("Ex. Classe A, Promo 2025", text: $name)
                    }
                    Section("Couleur (optionnel)") {
                        colorPaletteSection
                    }
                }
            }
            .sheetHideNavigationBar()
            .onAppear {
                if case .edit(let cat) = mode {
                    name = cat.name ?? ""
                    colorHex = cat.colorHex ?? ""
                }
            }
        }
    }
}

extension CategoryEditSheet.Mode {
    var isCreate: Bool {
        if case .create = self { return true }
        return false
    }
}

// MARK: - Category members (assign / unassign)

struct CategoryMembersView: View {
    let category: MemberCategory
    @ObservedObject var dataService: DataService
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var syncService: SyncService

    private var inCategory: [ClientCard] { dataService.clientCards(in: category) }
    private var allMembers: [ClientCard] {
        guard let t = category.template else { return [] }
        return dataService.uniqueClientCards(for: t).filter {
            !WalletPreviewMember.shouldExcludeFromMerchantActivity(clientEmail: $0.clientEmail)
        }
    }
    private var notInCategory: [ClientCard] {
        let inSet = Set(inCategory.map { $0.objectID })
        return allMembers.filter { !inSet.contains($0.objectID) }
    }

    var body: some View {
        List {
            Section("Dans cette catégorie (\(inCategory.count))") {
                ForEach(inCategory, id: \.objectID) { card in
                    memberRow(card, inCategory: true)
                }
            }
            Section("Autres membres") {
                ForEach(notInCategory, id: \.objectID) { card in
                    memberRow(card, inCategory: false)
                }
            }
        }
        .navigationTitle(category.name ?? "Catégorie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func memberRow(_ card: ClientCard, inCategory: Bool) -> some View {
        Button {
            toggleMember(card, inCategory: inCategory)
        } label: {
            HStack {
                Text(card.clientDisplayName ?? "Client")
                    .font(AppTheme.Fonts.body())
                Spacer()
                if inCategory {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.Colors.success)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.borderless)
    }

    private func toggleMember(_ card: ClientCard, inCategory: Bool) {
        guard let slug = AuthStorage.currentBusinessSlug,
              let memberId = card.qrCodeValue,
              let template = category.template,
              let catServerId = category.serverId else { return }
        let currentIds = (card.categories?.allObjects as? [MemberCategory])?.compactMap(\.serverId) ?? []
        var newIds = currentIds
        if inCategory {
            newIds.removeAll { $0 == catServerId }
        } else {
            if !newIds.contains(catServerId) { newIds.append(catServerId) }
        }
        Task {
            do {
                _ = try await APIClient.shared.request(.updateMemberCategories(slug: slug, memberId: memberId, categoryIds: newIds)) as EmptyResponse
                let newCategories = newIds.compactMap { dataService.category(byServerId: $0, template: template) }
                await MainActor.run {
                    card.categories = NSSet(array: newCategories)
                    try? viewContext.save()
                }
                await syncService.syncAfterServerMutation()
            } catch {
                await MainActor.run {
                    AppState.shared.showError((error as? APIError)?.errorDescription ?? "Mise à jour des catégories impossible.")
                }
            }
        }
    }
}
