//
//  GoogleEstablishmentPicker.swift
//  myfidpass
//
//  Recherche d’établissement via l’API Places du backend (aligné SaaS / landing myfidpass.fr).
//

import SwiftUI
import UIKit

struct GoogleEstablishmentPicker: View {
    @Binding var selectedPlaceId: String?
    @Binding var selectedDescription: String?
    /// Si la recherche est indisponible (503), le parent peut autoriser l’inscription sans lieu.
    @Binding var relaxRequirement: Bool
    /// Masque le titre et le texte d’aide (ex. onboarding plein écran avec titre déjà affiché).
    var compactIntro: Bool = false
    /// UX type Process « Comment devons-nous t’appeler ? » : champ centré, placeholder question, saisie en grand.
    var processEstablishmentStyle: Bool = false

    @State private var query = ""
    @State private var predictions: [PlaceAutocompletePrediction] = []
    @State private var isSearching = false
    @State private var hint: String?
    @State private var debounceTask: Task<Void, Never>?
    @FocusState private var processFieldFocused: Bool
    /// Libellés d’affichage (évite le doublon nom + adresse dans l’UI).
    @State private var selectedMainText: String?
    @State private var selectedSecondaryText: String?

    var body: some View {
        Group {
            if processEstablishmentStyle {
                processStyleBody
            } else {
                formStyleBody
            }
        }
        .onChange(of: query) { _, new in
            debounceTask?.cancel()
            let trimmed = new.trimmingCharacters(in: .whitespaces)
            if trimmed.count < 2 {
                predictions = []
                if hint != nil, selectedPlaceId == nil { hint = nil }
                return
            }
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                await search(trimmed)
            }
        }
        .onAppear {
            syncLabelsFromBindingsIfNeeded()
        }
        .onChange(of: selectedPlaceId) { _, _ in
            syncLabelsFromBindingsIfNeeded()
        }
        .onChange(of: selectedDescription) { _, _ in
            syncLabelsFromBindingsIfNeeded()
        }
    }

    /// Si le parent restaure `placeId` + `description` (onboarding repris), reconstruit titre / sous-titre sans doublon.
    private func syncLabelsFromBindingsIfNeeded() {
        guard selectedPlaceId != nil, selectedMainText == nil, let desc = selectedDescription else { return }
        let trimmed = desc.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            selectedMainText = String(parts[0])
            selectedSecondaryText = String(parts[1])
        } else {
            selectedMainText = trimmed
            selectedSecondaryText = nil
        }
    }

    // MARK: - Style Process (onboarding « Comment s’appelle… »)

    private var processStyleBody: some View {
        VStack(alignment: .center, spacing: 20) {
            if selectedPlaceId == nil {
                questionFieldBlock
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.98))
                        )
                    )
            } else {
                selectedEstablishmentProcessBlock
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .move(edge: .bottom))
                        )
                    )
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.9)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            if selectedPlaceId == nil, !predictions.isEmpty {
                predictionsProcessScroll()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        )
                    )
            }

            if let hint {
                Text(hint)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.52, dampingFraction: 0.86), value: selectedPlaceId != nil)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: predictions.count)
        .animation(.easeOut(duration: 0.2), value: isSearching)
    }

    private var questionFieldBlock: some View {
        ZStack {
            TextField("", text: $query)
                .font(.system(size: query.isEmpty ? 22 : 36, weight: .medium))
                .foregroundStyle(Color.clear)
                .tint(Color.clear)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($processFieldFocused)
                .submitLabel(.search)

            Group {
                if query.isEmpty {
                    Text(processPlaceholderQuestion)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .allowsHitTesting(false)
                } else {
                    Text(query)
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .multilineTextAlignment(.center)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 32)
    }

    /// Carte unique type Réglages : nom + adresse, sans répétition ni « Effacer ».
    private var selectedEstablishmentProcessBlock: some View {
        VStack(spacing: 14) {
            GroupedSettingsCard {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: GroupedSettingsMetrics.iconBoxCorner, style: .continuous)
                            .fill(AppTheme.Colors.success.opacity(0.18))
                            .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.success)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedMainText ?? fallbackTitleFromBinding)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color(UIColor.label))
                            .multilineTextAlignment(.leading)
                        if let sub = selectedSecondaryText, !sub.isEmpty {
                            Text(sub)
                                .font(.subheadline)
                                .foregroundStyle(Color(UIColor.secondaryLabel))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            }

            modifierSearchButton
        }
        .padding(.horizontal, 4)
    }

    private var fallbackTitleFromBinding: String {
        guard let d = selectedDescription else { return "" }
        let parts = d.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? d
    }

    private var modifierSearchButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button {
                    modifySearchTapped()
                } label: {
                    Text("Modifier la recherche")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass(.regular))
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            } else {
                Button(action: modifySearchTapped) {
                    Text("Modifier la recherche")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func modifySearchTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            clearSelection()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            processFieldFocused = true
        }
    }

    private func predictionsProcessScroll() -> some View {
        ScrollView(showsIndicators: false) {
            predictionsGroupedList(predictions: predictions)
        }
        .frame(maxHeight: min(CGFloat(predictions.count) * 76 + 24, 280))
    }

    @ViewBuilder
    private func predictionsGroupedList(predictions: [PlaceAutocompletePrediction]) -> some View {
        GroupedSettingsCard {
            ForEach(Array(predictions.enumerated()), id: \.element.placeId) { index, p in
                if index > 0 { GroupedSettingsRowDivider() }
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                        select(p)
                    }
                } label: {
                    GroupedSettingsNavigationRow(
                        icon: "mappin.and.ellipse",
                        title: title(for: p),
                        subtitle: subtitleForRow(p),
                        value: nil,
                        showsChevron: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func subtitleForRow(_ p: PlaceAutocompletePrediction) -> String? {
        let s = p.secondaryText?.trimmingCharacters(in: .whitespaces) ?? ""
        return s.isEmpty ? nil : s
    }

    private var processPlaceholderQuestion: String {
        "Comment s’appelle votre établissement ?"
    }

    // MARK: - Style formulaire (inscription classique)

    private var formStyleBody: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            if !compactIntro {
                Text("Votre établissement")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                Text("Recherchez votre commerce dans la liste Google, puis choisissez le bon résultat — comme sur le site MyFidpass.")
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.9))
            }

            if selectedPlaceId == nil {
                HStack {
                    TextField("Ex. Boulangerie Martin, Lyon", text: $query)
                        .textFieldStyle(.roundedBorder)
                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.85)
                    }
                }
            } else {
                GroupedSettingsCard {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: GroupedSettingsMetrics.iconBoxCorner, style: .continuous)
                                .fill(AppTheme.Colors.success.opacity(0.18))
                                .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.Colors.success)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedMainText ?? fallbackTitleFromBinding)
                                .font(.body.weight(.semibold))
                            if let sub = selectedSecondaryText, !sub.isEmpty {
                                Text(sub)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(UIColor.secondaryLabel))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
                    .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
                }

                if #available(iOS 26.0, *) {
                    Button(action: modifySearchTappedForm) {
                        Text("Modifier la recherche")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass(.regular))
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                } else {
                    Button(action: modifySearchTappedForm) {
                        Text("Modifier la recherche")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            if selectedPlaceId == nil, !predictions.isEmpty {
                predictionsGroupedList(predictions: predictions)
            }

            if let hint {
                Text(hint)
                    .font(AppTheme.Fonts.caption2())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
        }
    }

    private func modifySearchTappedForm() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.88)) {
            clearSelection()
        }
    }

    // MARK: - Logique

    private func title(for p: PlaceAutocompletePrediction) -> String {
        if let m = p.mainText, !m.isEmpty { return m }
        return p.description
    }

    private func secondaryLine(for p: PlaceAutocompletePrediction) -> String? {
        if let s = p.secondaryText {
            let t = s.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { return t }
        }
        let full = p.description
        let main = title(for: p)
        if full.hasPrefix(main) {
            let rest = full.dropFirst(main.count).trimmingCharacters(in: CharacterSet(charactersIn: " ,"))
            return rest.isEmpty ? nil : String(rest)
        }
        return nil
    }

    private func clearSelection() {
        selectedPlaceId = nil
        selectedDescription = nil
        selectedMainText = nil
        selectedSecondaryText = nil
        predictions = []
        query = ""
        hint = nil
    }

    private func select(_ p: PlaceAutocompletePrediction) {
        let main = title(for: p)
        selectedPlaceId = p.placeId
        selectedDescription = p.description
        selectedMainText = main
        selectedSecondaryText = secondaryLine(for: p)
        predictions = []
        query = main
        hint = nil
        relaxRequirement = false
        processFieldFocused = false
    }

    private func search(_ input: String) async {
        await MainActor.run { isSearching = true }
        do {
            let res: PlacesAutocompleteResponse = try await APIClient.shared.request(.placesAutocomplete(input: input))
            await MainActor.run {
                predictions = res.predictions
                hint = predictions.isEmpty ? "Aucun résultat. Essayez un autre libellé ou la ville." : nil
            }
        } catch {
            await MainActor.run {
                predictions = []
                if case let APIError.server(code, msg) = error, code == 503 {
                    relaxRequirement = true
                    hint = (msg ?? "Recherche indisponible") + " Vous pourrez configurer votre commerce après connexion (Paramètres)."
                } else {
                    hint = "Impossible de lancer la recherche. Vérifiez la connexion."
                }
            }
        }
        await MainActor.run { isSearching = false }
    }
}
