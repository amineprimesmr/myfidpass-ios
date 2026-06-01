//
//  MerchantTabActivity.swift
//  myfidpass
//
//  Onglet actif + montage paresseux — navigation TabView fluide (pas de travail lourd en arrière-plan).
//

import SwiftUI

// MARK: - Environnement

private struct MerchantTabIsActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// `true` uniquement pour l’onglet actuellement sélectionné dans le TabView.
    var merchantTabIsActive: Bool {
        get { self[MerchantTabIsActiveKey.self] }
        set { self[MerchantTabIsActiveKey.self] = newValue }
    }
}

// MARK: - Montage paresseux (1er affichage, puis conservé en mémoire)

struct MerchantLazyTabContent<Content: View>: View {
    let tag: Int
    let selection: Int
    @ViewBuilder var content: () -> Content

    @State private var didMount = false

    private var shouldShowContent: Bool {
        didMount || selection == tag
    }

    var body: some View {
        Group {
            if shouldShowContent {
                content()
            } else {
                Color.clear
            }
        }
        .onAppear {
            if selection == tag { didMount = true }
        }
        .onChange(of: selection) { _, newValue in
            if newValue == tag { didMount = true }
        }
    }
}

