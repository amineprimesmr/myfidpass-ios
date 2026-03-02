//
//  ScansTodayView.swift
//  myfidpass
//
//  Liste des scans du jour (activité récente). Accessible depuis « Scans aujourd'hui » sur le tableau de bord.
//

import SwiftUI
import CoreData

struct ScansTodayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var syncService: SyncService
    @StateObject private var dataService: DataService

    init(context: NSManagedObjectContext) {
        _dataService = StateObject(wrappedValue: DataService(context: context))
    }

    private var stampsToday: Int { dataService.stampsCountToday() }
    private var recentStamps: [Stamp] { dataService.recentStamps(limit: 100) }

    var body: some View {
        Group {
            if recentStamps.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(recentStamps, id: \.objectID) { stamp in
                        if let card = stamp.clientCard {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.Colors.success)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.clientDisplayName ?? "Client")
                                        .font(AppTheme.Fonts.body())
                                        .foregroundStyle(AppTheme.Colors.textPrimary)
                                    Text(formattedDate(stamp.createdAt ?? Date()))
                                        .font(AppTheme.Fonts.caption())
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Scans aujourd'hui")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Fermer") { dismiss() }
            }
        }
        .refreshable {
            await syncService.syncIfNeeded()
        }
        .background(AppTheme.Colors.background)
    }

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 56))
                .foregroundStyle(AppTheme.Colors.accent.opacity(0.6))
            Text("Aucun scan pour le moment")
                .font(AppTheme.Fonts.title3())
                .foregroundStyle(AppTheme.Colors.textPrimary)
            Text("Les passages enregistrés aujourd'hui apparaîtront ici.")
                .font(AppTheme.Fonts.body())
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func formattedDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        f.locale = Locale(identifier: "fr_FR")
        return f.localizedString(for: date, relativeTo: Date())
    }
}
