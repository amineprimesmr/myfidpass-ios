//
//  AddressSearchField.swift
//  myfidpass
//
//  Champ adresse avec suggestions automatiques (MapKit MKLocalSearchCompleter).
//  Permet de rechercher un établissement ou une adresse comme sur le site (Google Places).
//

import SwiftUI
import MapKit
import Combine

/// Une suggestion d'adresse retournée par MKLocalSearchCompleter.
struct AddressSuggestion: Identifiable {
    let id = UUID()
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
        // Priorité France pour les résultats (établissements et adresses)
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
            AddressSuggestion(
                title: result.title,
                subtitle: result.subtitle
            )
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

/// Champ de saisie avec liste de suggestions d'adresses (établissements et adresses).
struct AddressSearchField: View {
    @Binding var text: String
    var placeholder: String = "Rechercher une adresse ou un établissement…"
    var onSelect: ((String) -> Void)?

    @StateObject private var completer = AddressSearchCompleter()
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AppTheme.Colors.primary)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .focused($isFocused)
                    .onChange(of: text) { _, newValue in
                        completer.search(query: newValue)
                    }
                if !text.isEmpty {
                    Button {
                        text = ""
                        completer.clear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .padding(AppTheme.Spacing.md)
            .background(AppTheme.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))

            if isFocused && !completer.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(completer.suggestions.prefix(5)) { suggestion in
                        Button {
                            let full = suggestion.fullAddress
                            text = full
                            onSelect?(full)
                            completer.clear()
                            isFocused = false
                        } label: {
                            HStack(alignment: .top, spacing: AppTheme.Spacing.sm) {
                                Image(systemName: "location.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Colors.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.title)
                                        .font(AppTheme.Fonts.subheadline())
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    if !suggestion.subtitle.isEmpty {
                                        Text(suggestion.subtitle)
                                            .font(AppTheme.Fonts.caption())
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(AppTheme.Spacing.sm)
                        }
                        .buttonStyle(.plain)
                        Divider()
                            .padding(.leading, AppTheme.Spacing.md + 20)
                    }
                }
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md))
                .shadow(color: AppTheme.Colors.shadow, radius: 8, x: 0, y: 4)
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
        .animation(.easeOut(duration: 0.2), value: completer.suggestions.isEmpty)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var address = ""
        var body: some View {
            AddressSearchField(text: $address)
                .padding()
        }
    }
    return PreviewWrapper()
}
