//
//  CardPreviewEditModels.swift
//  myfidpass
//
//  Segmentation des zones tactiles sur l’aperçu Wallet (Ma Carte) → édition ciblée.
//

import SwiftUI

/// Zone visuelle de la carte (tap → feuille de personnalisation contextuelle).
enum CardPreviewEditZone: Equatable, Hashable, Identifiable {
    /// Logo, texte bandeau ou import image.
    case logoBand
    /// Lien Récompenses en-tête : paliers ou récompenses tampons (choix Points / Tampons identique à « Système de carte »).
    case headerRight
    /// Bannière image sous l’en-tête.
    case backgroundImage
    /// Fond, texte principal, libellés (menu « Autres réglages » — pas de zone sur la carte).
    case cardAppearance
    /// Zone bandeau / métriques : mode points ou tampons, options associées (tampons / image de fond), pas les récompenses.
    case mainMetrics
    /// Colonne membre (titre + aperçu nom).
    case memberColumn
    /// Zone QR (lien public carte).
    case qrCode
    /// Verso du pass & notifications (menu Personnaliser — pas de zone sur la carte).
    case walletPassBack

    var id: String {
        switch self {
        case .logoBand: return "logoBand"
        case .headerRight: return "headerRight"
        case .backgroundImage: return "backgroundImage"
        case .cardAppearance: return "cardAppearance"
        case .mainMetrics: return "mainMetrics"
        case .memberColumn: return "memberColumn"
        case .qrCode: return "qrCode"
        case .walletPassBack: return "walletPassBack"
        }
    }

    /// Titre affiché en tête de la feuille de personnalisation.
    var customizationSheetTitle: String {
        switch self {
        case .logoBand: return "Logo"
        case .headerRight: return "Récompenses"
        case .backgroundImage: return "Image de fond"
        case .cardAppearance: return "Couleurs de la carte"
        case .mainMetrics: return "Système de carte"
        case .memberColumn: return "Colonne membre"
        case .qrCode: return "Lien & QR code"
        case .walletPassBack: return "Verso & notifications"
        }
    }
}

/// Texte fixe du lien « Récompenses » dans l’en-tête de la carte (non modifiable dans l’app).
enum CardRewardsHeaderLink {
    static let displayText = "Récompenses ↗"
}

// MARK: - Style bouton zones carte

/// Les `Button` SwiftUI appliquent une teinte au libellé (souvent la couleur d’accent de l’app ou `.primary`),
/// ce qui écrase `foregroundStyle` et rend les textes noirs sur fond carte sombre.
struct PassPreviewZoneButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.88 : 1.0)
    }
}

// MARK: - Zones tactiles réutilisées (Wallet + Café des Arts)

struct CardPreviewTappableZone<Content: View>: View {
    let zone: CardPreviewEditZone
    let accessibilityLabel: String
    var onEditZoneTap: ((CardPreviewEditZone) -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        if let onEditZoneTap {
            Button {
                onEditZoneTap(zone)
            } label: {
                content()
                    .contentShape(Rectangle())
            }
            .buttonStyle(PassPreviewZoneButtonStyle())
            .accessibilityLabel(Text(accessibilityLabel))
            .accessibilityAddTraits(.isButton)
        } else {
            content()
        }
    }
}
