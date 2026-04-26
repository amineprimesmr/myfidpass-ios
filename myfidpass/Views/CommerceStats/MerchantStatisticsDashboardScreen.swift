//
//  MerchantStatisticsDashboardScreen.swift
//  myfidpass
//
//  Statistiques commerçant : navigation classique ou couche « verre » par-dessus Commerce (Revolut).
//

import SwiftUI
import CoreData

struct MerchantStatisticsDashboardScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    /// Fond flou / chrome type Revolut (overlay Commerce).
    var glassOverlayPresentation: Bool = false
    /// Si non nil : fermeture explicite (overlay) au lieu de `dismiss()`.
    var onOverlayDismiss: (() -> Void)? = nil

    @StateObject private var vm = MerchantStatsIndicatorsViewModel()
    @State private var statsMonthKeys = CommerceStatsMonthNavigator.sixMonthKeysEndingCurrentMonth()
    @State private var selectedStatsMonthIndex = 0

    var body: some View {
        CommerceStatisticsDashboardView(
            vm: vm,
            statsMonthKeys: statsMonthKeys,
            selectedMonthIndex: $selectedStatsMonthIndex,
            onClose: {
                if let onOverlayDismiss {
                    onOverlayDismiss()
                } else {
                    dismiss()
                }
            },
            showsInlineCloseButton: true,
            glassOverlayMode: glassOverlayPresentation
        )
        .environment(\.managedObjectContext, viewContext)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}
