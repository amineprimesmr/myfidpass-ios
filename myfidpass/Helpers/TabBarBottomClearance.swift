//
//  TabBarBottomClearance.swift
//  myfidpass
//
//  Distance stable pour placer la pastille abonnement au-dessus de la UITabBar.
//

import SwiftUI
import UIKit

enum TabBarBottomClearance {
    /// Marge confortable entre la pastille et le haut de la tab bar.
    static let gapAboveTabBar: CGFloat = 12

    /// Valeur par défaut (iPhone avec tab bar flottante) — évite un saut au 1er frame.
    static let stableFallback: CGFloat = 58

    private static let minClearance: CGFloat = 50
    private static let maxClearance: CGFloat = 74

    /// Mesure ponctuelle (pas en continu) : évite les sauts pendant les animations d’onglet.
    static func remeasureFromKeyWindow() -> CGFloat {
        measure(from: nil)
    }

    static func measure(from anchor: UIView?) -> CGFloat {
        guard let window = anchor?.window ?? keyWindow else {
            return stableFallback
        }
        guard let tabBar = findTabBar(from: window.rootViewController),
              !tabBar.isHidden,
              tabBar.alpha > 0.01
        else {
            return stableFallback
        }
        let frameInWindow = tabBar.convert(tabBar.bounds, to: window)
        let distanceFromBottom = window.bounds.maxY - frameInWindow.minY
        let raw = max(distanceFromBottom, 44) + gapAboveTabBar
        return min(max(raw, minClearance), maxClearance)
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func findTabBar(from root: UIViewController?) -> UITabBar? {
        guard let root else { return nil }
        if let tabController = root as? UITabBarController {
            return tabController.tabBar
        }
        for child in root.children {
            if let found = findTabBar(from: child) { return found }
        }
        if let presented = root.presentedViewController {
            if let found = findTabBar(from: presented) { return found }
        }
        return nil
    }
}
