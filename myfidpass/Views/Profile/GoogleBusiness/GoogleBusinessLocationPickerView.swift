//
//  GoogleBusinessLocationPickerView.swift
//  myfidpass
//
//  Présenté en sheet après un OAuth Google Business réussi quand le compte gère plusieurs fiches.
//  Le marchand choisit l'établissement à lier ; l'app appelle POST /location/select pour fixer
//  le choix côté backend, puis remonte le résultat via onLocationSelected.
//

import SwiftUI

struct GoogleBusinessLocationPickerView: View {
    let locations: [GoogleBusinessLocationItem]
    /// Place ID configuré côté commerce (pour mettre en avant la fiche recommandée).
    let configuredPlaceId: String?
    let slug: String
    var onLocationSelected: (GoogleBusinessSelectLocationResponse) -> Void
    var onDismiss: () -> Void

    @State private var selectingLocationId: String?
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Plusieurs établissements trouvés", systemImage: "building.2.crop.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Text("Ce compte Google gère plusieurs fiches. Sélectionnez celle qui correspond à votre commerce.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
            }

            Section("Fiches disponibles") {
                ForEach(locations) { location in
                    Button {
                        select(location)
                    } label: {
                        locationRow(location)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectingLocationId != nil)
                }
            }

            if let err = errorMessage {
                Section {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.Colors.error)
                        .listRowBackground(AppTheme.Colors.error.opacity(0.06))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Choisir l'établissement")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { onDismiss() }
            }
        }
    }

    @ViewBuilder
    private func locationRow(_ location: GoogleBusinessLocationItem) -> some View {
        let isRecommended = configuredPlaceId != nil && location.placeId == configuredPlaceId
        let isSelecting = selectingLocationId == location.locationId

        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isRecommended ? AppTheme.Colors.success.opacity(0.14) : AppTheme.Colors.primary.opacity(0.08))
                    .frame(width: 40, height: 40)
                Image(systemName: isRecommended ? "checkmark.seal.fill" : "building.2")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(isRecommended ? AppTheme.Colors.success : AppTheme.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(location.locationName)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                        .lineLimit(1)
                    if isRecommended {
                        Text("Recommandé")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.Colors.success))
                    }
                }
                if let addr = location.address, !addr.isEmpty {
                    Text(addr)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelecting {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.45))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func select(_ location: GoogleBusinessLocationItem) {
        guard selectingLocationId == nil else { return }
        selectingLocationId = location.locationId
        errorMessage = nil
        Task {
            do {
                let result = try await GoogleBusinessAPI.shared.selectLocation(slug: slug, locationId: location.locationId)
                await MainActor.run {
                    selectingLocationId = nil
                    onLocationSelected(result)
                }
            } catch {
                await MainActor.run {
                    selectingLocationId = nil
                    errorMessage = "Impossible de sélectionner cette fiche. Vérifiez votre connexion et réessayez."
                }
            }
        }
    }
}
