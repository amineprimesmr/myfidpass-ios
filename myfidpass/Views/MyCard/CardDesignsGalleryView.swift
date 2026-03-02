//
//  CardDesignsGalleryView.swift
//  myfidpass
//
//  Galerie de designs de cartes par secteur : explorer les possibilités (couleurs, emojis, styles).
//

import SwiftUI

// MARK: - Modèle d’un design de carte

struct CardDesignPreset: Identifiable {
    let id: String
    let sectorName: String
    let sectorIcon: String
    let displayName: String
    let primaryHex: String
    let accentHex: String
    let stampEmoji: String?
    let requiredStamps: Int32
    let description: String
    /// Style d’affichage de la carte : nil = Wallet par défaut, .stampGrid = grille de tampons (style STELLAR HUB).
    let displayFormat: CardPreviewFormat?

    init(id: String, sectorName: String, sectorIcon: String, displayName: String, primaryHex: String, accentHex: String, stampEmoji: String?, requiredStamps: Int32, description: String, displayFormat: CardPreviewFormat? = nil) {
        self.id = id
        self.sectorName = sectorName
        self.sectorIcon = sectorIcon
        self.displayName = displayName
        self.primaryHex = primaryHex
        self.accentHex = accentHex
        self.stampEmoji = stampEmoji
        self.requiredStamps = requiredStamps
        self.description = description
        self.displayFormat = displayFormat
    }
}

// MARK: - Catalogue de designs par secteur

enum CardDesignPresets {
    static let all: [CardDesignPreset] = [
        CardDesignPreset(
            id: "cafe-classic",
            sectorName: "Café",
            sectorIcon: "cup.and.saucer.fill",
            displayName: "Café des Arts",
            primaryHex: "5d4e37",
            accentHex: "d7ccc8",
            stampEmoji: "☕",
            requiredStamps: 10,
            description: "Marron chaud, emoji café — idéal pour un coffee shop."
        ),
        CardDesignPreset(
            id: "cafe-modern",
            sectorName: "Café",
            sectorIcon: "cup.and.saucer.fill",
            displayName: "Bean & Co",
            primaryHex: "3e2723",
            accentHex: "8d6e63",
            stampEmoji: "☕",
            requiredStamps: 8,
            description: "Brun foncé et beige — look premium."
        ),
        // Restauration / Fast-food
        CardDesignPreset(
            id: "fastfood",
            sectorName: "Restauration",
            sectorIcon: "fork.knife",
            displayName: "Burger House",
            primaryHex: "8B2942",
            accentHex: "ffd54f",
            stampEmoji: "🍔",
            requiredStamps: 10,
            description: "Bordeaux et or — classique fast-food."
        ),
        CardDesignPreset(
            id: "pizza",
            sectorName: "Restauration",
            sectorIcon: "fork.knife",
            displayName: "Pizza Roma",
            primaryHex: "c62828",
            accentHex: "ffeb3b",
            stampEmoji: "🍕",
            requiredStamps: 12,
            description: "Rouge et jaune — énergie et convivialité."
        ),
        // Boulangerie / Pâtisserie
        CardDesignPreset(
            id: "boulangerie",
            sectorName: "Boulangerie",
            sectorIcon: "birthday.cake.fill",
            displayName: "Au Pain Doré",
            primaryHex: "b8860b",
            accentHex: "fff8e1",
            stampEmoji: "🍞",
            requiredStamps: 10,
            description: "Or et crème — chaleur de la boulangerie."
        ),
        CardDesignPreset(
            id: "patisserie",
            sectorName: "Pâtisserie",
            sectorIcon: "birthday.cake.fill",
            displayName: "Douceur",
            primaryHex: "ad1457",
            accentHex: "fce4ec",
            stampEmoji: "🍰",
            requiredStamps: 8,
            description: "Rose et poudre — univers pâtissier."
        ),
        // Beauté / Esthétique
        CardDesignPreset(
            id: "beaute",
            sectorName: "Beauté",
            sectorIcon: "sparkles",
            displayName: "Institut Éclat",
            primaryHex: "b76e79",
            accentHex: "fce4ec",
            stampEmoji: "💄",
            requiredStamps: 10,
            description: "Rose poudré — élégance et douceur."
        ),
        CardDesignPreset(
            id: "beaute-dark",
            sectorName: "Beauté",
            sectorIcon: "sparkles",
            displayName: "Noir & Rose",
            primaryHex: "4a1942",
            accentHex: "f8bbd9",
            stampEmoji: "🌸",
            requiredStamps: 8,
            description: "Violet profond et rose — luxe discret."
        ),
        // Coiffure
        CardDesignPreset(
            id: "coiffure",
            sectorName: "Coiffure",
            sectorIcon: "scissors",
            displayName: "Salon Élégance",
            primaryHex: "5c4a6a",
            accentHex: "d1c4e0",
            stampEmoji: "✂️",
            requiredStamps: 10,
            description: "Violet et lavande — univers coiffure."
        ),
        // Boucherie / Boucher
        CardDesignPreset(
            id: "boucherie",
            sectorName: "Boucherie",
            sectorIcon: "leaf.fill",
            displayName: "Boucherie du Marché",
            primaryHex: "6d2c3e",
            accentHex: "ffcdd2",
            stampEmoji: "🥩",
            requiredStamps: 10,
            description: "Rouge bordeaux et rose — tradition et qualité."
        ),
        // Retail / Mode
        CardDesignPreset(
            id: "retail",
            sectorName: "Commerce",
            sectorIcon: "bag.fill",
            displayName: "Style & Co",
            primaryHex: "37474f",
            accentHex: "cfd8dc",
            stampEmoji: "🛍️",
            requiredStamps: 10,
            description: "Gris anthracite — moderne et sobre."
        ),
        CardDesignPreset(
            id: "retail-teal",
            sectorName: "Commerce",
            sectorIcon: "bag.fill",
            displayName: "Trendy Shop",
            primaryHex: "00695c",
            accentHex: "b2dfdb",
            stampEmoji: "✨",
            requiredStamps: 12,
            description: "Teal et menthe — fraîcheur et modernité."
        ),
        // Classiques (points génériques)
        CardDesignPreset(
            id: "classic-green",
            sectorName: "Classique",
            sectorIcon: "star.fill",
            displayName: "Ma Carte Fidélité",
            primaryHex: "0a7c42",
            accentHex: "e8f5e9",
            stampEmoji: "⭐",
            requiredStamps: 10,
            description: "Vert et vert clair — le plus populaire."
        ),
        CardDesignPreset(
            id: "classic-blue",
            sectorName: "Classique",
            sectorIcon: "star.fill",
            displayName: "Fidélité Plus",
            primaryHex: "1565c0",
            accentHex: "bbdefb",
            stampEmoji: "⭐",
            requiredStamps: 10,
            description: "Bleu confiance — polyvalent."
        ),
        CardDesignPreset(
            id: "classic-amber",
            sectorName: "Classique",
            sectorIcon: "star.fill",
            displayName: "Avantages",
            primaryHex: "ff8f00",
            accentHex: "ffe0b2",
            stampEmoji: "🎁",
            requiredStamps: 10,
            description: "Ambre et orange — chaleureux et visible."
        ),
        CardDesignPreset(
            id: "classic-dark",
            sectorName: "Classique",
            sectorIcon: "star.fill",
            displayName: "Carte Privilège",
            primaryHex: "212121",
            accentHex: "b0b0b0",
            stampEmoji: nil,
            requiredStamps: 10,
            description: "Noir et gris — premium et épuré."
        ),
    ]

    static func bySector(_ sector: String) -> [CardDesignPreset] {
        all.filter { $0.sectorName == sector }
    }

    static var sectors: [String] {
        Array(Set(all.map(\.sectorName))).sorted()
    }
}

// MARK: - Vue galerie

struct CardDesignsGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    /// Si fourni, un bouton « Appliquer » permet d’appliquer le design à la carte et de l’enregistrer (affiché dans le Wallet).
    var onApplyDesign: ((CardDesignPreset) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        CardDesignsCarouselView(
            presets: CardDesignPresets.all,
            onApplyDesign: onApplyDesign,
            onDismiss: { onDismiss?() ?? dismiss() }
        )
        .background(Color.black)
        .navigationTitle("Galerie de designs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onDismiss?()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        CardDesignsGalleryView(onApplyDesign: nil)
    }
}
