//
//  MerchantStatisticsDashboardScreen.swift
//  myfidpass
//
//  Statistiques commerçant : poussé sur la pile de navigation de l’onglet Commerce (pas dans le sheet Réglages).
//

import SwiftUI
import CoreData

struct MerchantStatisticsDashboardScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Commerce : ouvre l’écran détail Revolut. Paywall : fournir la variante qui pousse sur la même `NavigationStack`.
    var onRequestStatisticDetail: ((CommerceStatisticDetailTopic, String) -> Void)? = nil

    @StateObject private var vm = MerchantStatsIndicatorsViewModel()
    @State private var periodTab: CommerceStatsPeriodTab = .oneMonth
    @State private var organizationName = "Ma boutique"

    var body: some View {
        CommerceStatisticsDashboardView(
            vm: vm,
            periodTab: $periodTab,
            organizationName: organizationName,
            onClose: { dismiss() },
            showsInlineCloseButton: true,
            onOpenStatisticDetail: onRequestStatisticDetail == nil
                ? nil
                : { topic in onRequestStatisticDetail!(topic, periodTab.rawValue) }
        )
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear { refreshOrganizationLabel() }
        .task { await vm.load(period: periodTab.rawValue) }
    }

    private func refreshOrganizationLabel() {
        let ds = DataService(context: viewContext)
        let business = ds.createOrGetCurrentBusiness()
        let template = ds.currentCardTemplate()
        let name = template?.displayName ?? business.name
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        organizationName = trimmed.isEmpty ? "Ma boutique" : trimmed
    }
}
