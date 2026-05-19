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
    /// Vue embarquée (ex. onglet Commerce = stats): pas de bouton retour local.
    var showsInlineCloseButton: Bool = true
    /// Affiche/masque le grand titre "Outils d'analyse".
    var showsTopTitle: Bool = true
    /// Certains contextes veulent garder la tab bar visible (stats directement dans Commerce).
    var hidesTabBar: Bool = true

    @EnvironmentObject private var authService: AuthService

    @StateObject private var vm = MerchantStatsIndicatorsViewModel()
    @State private var selectedStatsMonthIndex = 0

    private var statsMonthKeys: [String] {
        let slug = AuthStorage.currentBusinessSlug?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rawCreatedAt = authService.businesses.first(where: { $0.slug == slug })?.createdAt
        let creationMonth: String? = rawCreatedAt.flatMap { raw in
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count >= 7 else { return nil }
            let candidate = String(trimmed.prefix(7))
            return CommerceStatsMonthNavigator.isCalendarMonthPeriod(candidate) ? candidate : nil
        }
        return CommerceStatsMonthNavigator.monthKeys(from: creationMonth)
    }

    var body: some View {
        let keys = statsMonthKeys
        let maxIdx = max(0, keys.count - 1)
        CommerceStatisticsDashboardView(
            vm: vm,
            statsMonthKeys: keys,
            selectedMonthIndex: Binding(
                get: { min(selectedStatsMonthIndex, maxIdx) },
                set: { newVal in
                    selectedStatsMonthIndex = min(max(0, newVal), maxIdx)
                }
            ),
            onClose: {
                if let onOverlayDismiss {
                    onOverlayDismiss()
                } else {
                    dismiss()
                }
            },
            showsInlineCloseButton: showsInlineCloseButton,
            showsTopTitle: showsTopTitle,
            glassOverlayMode: glassOverlayPresentation
        )
        .environment(\.managedObjectContext, viewContext)
        .background(Color.clear)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .modifier(MerchantStatsTabBarVisibilityModifier(hidesTabBar: hidesTabBar))
    }
}

private struct MerchantStatsTabBarVisibilityModifier: ViewModifier {
    let hidesTabBar: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if hidesTabBar {
            content.toolbar(.hidden, for: .tabBar)
        } else {
            content
        }
    }
}
