//
//  AddressSearchField.swift
//  myfidpass
//
//  Champ adresse avec suggestions (MKLocalSearchCompleter).
//

import SwiftUI
import MapKit
import Combine

/// Une suggestion d'adresse retournée par MKLocalSearchCompleter.
struct AddressSuggestion: Identifiable {
    var id: String { "\(title)|\(subtitle)" }
    let title: String
    let subtitle: String
    var fullAddress: String {
        if subtitle.isEmpty { return title }
        return "\(title), \(subtitle)"
    }
}

/// Gestionnaire des suggestions d'adresse (MKLocalSearchCompleter).
final class AddressSearchCompleter: NSObject, ObservableObject {
    private let completer = MKLocalSearchCompleter()
    @Published var suggestions: [AddressSuggestion] = []
    @Published var isSearching = false

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 46.6, longitude: 2.4),
            span: MKCoordinateSpan(latitudeDelta: 12, longitudeDelta: 10)
        )
    }

    func search(query: String) {
        let q = query.trimmingCharacters(in: .whitespaces)
        if q.isEmpty {
            suggestions = []
            isSearching = false
            return
        }
        completer.queryFragment = q
        isSearching = true
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
        isSearching = false
    }
}

extension AddressSearchCompleter: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let list = completer.results.map { result in
            AddressSuggestion(title: result.title, subtitle: result.subtitle)
        }
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = list
            self?.isSearching = false
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.suggestions = []
            self?.isSearching = false
        }
    }
}

// MARK: - Champ

extension AddressSearchField {
    enum Appearance {
        case standard
        /// Champ sur carte / glass : fond système + suggestions en matériau (suit le thème clair/sombre).
        case mapOverlay
    }
}

struct AddressSearchField: View {
    @Binding var text: String
    var placeholder: String = "Rechercher une adresse ou un établissement…"
    var appearance: Appearance = .standard
    var onSelect: ((String) -> Void)?

    @StateObject private var completer = AddressSearchCompleter()
    @FocusState private var isFocused: Bool
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: horizontalIconSpacing) {
                Image(systemName: "mappin.circle.fill")
                    .font(iconFont)
                    .foregroundStyle(AppTheme.Colors.primary)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(fieldFont)
                    .foregroundStyle(fieldForeground)
                    .focused($isFocused)
                    .submitLabel(.search)
                    .onChange(of: text) { _, newValue in
                        debounceTask?.cancel()
                        debounceTask = Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 260_000_000)
                            guard !Task.isCancelled else { return }
                            completer.search(query: newValue)
                        }
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                        completer.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(clearButtonColor)
                    }
                    .accessibilityLabel("Effacer")
                }
            }
            .padding(fieldPadding)
            .background {
                if appearance == .standard {
                    AppTheme.Colors.background
                } else {
                    Color(uiColor: .secondarySystemGroupedBackground)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: fieldCornerRadius, style: .continuous))

            if isFocused && (!completer.suggestions.isEmpty || completer.isSearching) {
                suggestionsPanel
                    .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .animation(.easeOut(duration: 0.18), value: completer.suggestions.isEmpty)
        .animation(.easeOut(duration: 0.18), value: completer.isSearching)
        .onDisappear {
            debounceTask?.cancel()
        }
    }

    @ViewBuilder
    private var suggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if completer.isSearching && completer.suggestions.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.85)
                    Text("Recherche…")
                        .font(AppTheme.Fonts.caption())
                        .foregroundStyle(suggestionSecondaryForeground)
                }
                .padding(AppTheme.Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<min(8, completer.suggestions.count), id: \.self) { index in
                        let suggestion = completer.suggestions[index]
                        Button {
                            let full = suggestion.fullAddress
                            text = full
                            onSelect?(full)
                            completer.clear()
                            isFocused = false
                        } label: {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.Colors.primary)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(AppTheme.Fonts.subheadline())
                                        .foregroundStyle(suggestionPrimaryForeground)
                                        .multilineTextAlignment(.leading)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(AppTheme.Fonts.caption())
                                            .foregroundStyle(suggestionSecondaryForeground)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, AppTheme.Spacing.sm)
                            .padding(.vertical, 10)
                        }

                        if index < min(8, completer.suggestions.count) - 1 {
                            Divider()
                                .background(suggestionDividerColor)
                                .padding(.leading, AppTheme.Spacing.sm + 14)
                        }
                    }
                }
            }
            .frame(maxHeight: suggestionMaxHeight)
            .scrollDismissesKeyboard(.interactively)
        }
        .background {
            switch appearance {
            case .standard:
                AppTheme.Colors.cardBackground
            case .mapOverlay:
                Rectangle()
                    .fill(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        .shadow(color: suggestionShadow, radius: 10, x: 0, y: 4)
    }

    // MARK: - Apparence

    private var iconFont: Font {
        appearance == .mapOverlay
            ? .system(size: 18, weight: .semibold)
            : .title3
    }

    private var fieldFont: Font {
        appearance == .mapOverlay
            ? AppTheme.Fonts.subheadline()
            : AppTheme.Fonts.body()
    }

    private var horizontalIconSpacing: CGFloat {
        appearance == .mapOverlay ? 10 : AppTheme.Spacing.sm
    }

    private var fieldPadding: EdgeInsets {
        switch appearance {
        case .standard:
            return EdgeInsets(
                top: AppTheme.Spacing.md,
                leading: AppTheme.Spacing.md,
                bottom: AppTheme.Spacing.md,
                trailing: AppTheme.Spacing.md
            )
        case .mapOverlay:
            return EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        }
    }

    private var fieldCornerRadius: CGFloat { AppTheme.Radius.md }

    private var fieldForeground: Color {
        appearance == .mapOverlay ? AppTheme.Colors.textPrimary : AppTheme.Colors.textPrimary
    }

    private var clearButtonColor: Color {
        appearance == .mapOverlay ? AppTheme.Colors.textSecondary.opacity(0.7) : AppTheme.Colors.textSecondary
    }

    private var suggestionMaxHeight: CGFloat { 220 }

    private var suggestionPrimaryForeground: Color {
        AppTheme.Colors.textPrimary
    }

    private var suggestionSecondaryForeground: Color {
        AppTheme.Colors.textSecondary
    }

    private var suggestionDividerColor: Color {
        Color(uiColor: .separator)
    }

    private var suggestionShadow: Color {
        AppTheme.Colors.shadow
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var address = ""
        var body: some View {
            VStack(spacing: 20) {
                AddressSearchField(text: $address)
                AddressSearchField(text: $address, appearance: .mapOverlay)
            }
            .padding()
            .background(Color.gray.opacity(0.3))
        }
    }
    return PreviewWrapper()
}
