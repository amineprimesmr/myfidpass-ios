//
//  CommerceStatisticsGlassBackdrop.swift
//  myfidpass
//
//  Clef d’environnement : sections du dashboard en mode « verre » (overlay Commerce).
//  Le voile sous-jacent est géré dans `ProfileView` (`presentationBackground(.clear)` + matériau).
//

import SwiftUI

private enum CommerceStatsGlassOverlayKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// `true` quand dashboard / détail sont présentés en couche verre par-dessus Commerce.
    var commerceStatsGlassOverlay: Bool {
        get { self[CommerceStatsGlassOverlayKey.self] }
        set { self[CommerceStatsGlassOverlayKey.self] = newValue }
    }
}
