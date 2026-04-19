//
//  SettingsLocationDetailView.swift
//  myfidpass
//
//  Localisation commerce : rappel Wallet + lien Plans (données depuis la fiche).
//

import SwiftUI
import CoreData
import UIKit

struct SettingsLocationDetailView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var dataService: DataService
    @State private var address: String = ""

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                Text("L’adresse de votre commerce est utilisée dans le pass Apple Wallet (emplacements pertinents). La zone utile côté Wallet pour une carte fidélité est d’environ 100 m maximum ; réglez le rayon précis dans l’onglet Carte de l’app.")
                    .font(AppTheme.Fonts.body())
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                if address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Renseignez l’adresse dans Fiche commerce puis enregistrez.")
                        .font(AppTheme.Fonts.subheadline())
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(AppTheme.Colors.primary)
                        Text(address)
                            .font(AppTheme.Fonts.body())
                    }
                    Button {
                        openInMaps(address)
                    } label: {
                        Label("Ouvrir dans Plans", systemImage: "map.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.Colors.primary)
                }

                Text("Pour modifier l’adresse : Paramètres → Fiche commerce.")
                    .font(AppTheme.Fonts.caption())
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, 48)
        }
        .background(AppTheme.Colors.background)
        .navigationTitle("Localisation")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let b = dataService.createOrGetCurrentBusiness()
            address = b.address ?? ""
        }
        .task {
            await reloadFromServer()
        }
    }

    private func reloadFromServer() async {
        guard let slug = AuthStorage.currentBusinessSlug else { return }
        do {
            let settings = try await APIClient.shared.request(APIEndpoint.businessSettings(slug: slug)) as BusinessSettingsResponse
            await MainActor.run {
                if let addr = settings.locationAddress, !addr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    address = addr
                }
            }
        } catch {}
    }

    private func openInMaps(_ address: String) {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let url = URL(string: "maps://?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
