//
//  GroupedSettingsComponents.swift
//  myfidpass
//
//  Style aligné sur Réglages iOS : fond groupé, cartes blanches arrondies, icônes en carré gris clair.
//

import SwiftUI
import UIKit

// MARK: - Constantes (proche SF / HIG)

enum GroupedSettingsMetrics {
    /// Fond de page type « groupé » (≈ systemGroupedBackground).
    static var pageBackground: Color {
        Color(UIColor.systemGroupedBackground)
    }

    /// Rayon élevé type bulle (réf. Réglages iOS récents).
    static let cardCornerRadius: CGFloat = 28
    static let iconBoxSize: CGFloat = 29
    static let iconBoxCorner: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let interCardSpacing: CGFloat = 20
    /// Décalage du séparateur après la pastille d’icône (comme Réglages iOS).
    static let dividerLeadingInset: CGFloat = horizontalPadding + iconBoxSize + 12
}

// MARK: - Pastille d’icône

struct GroupedSettingsIconBox: View {
    let systemName: String
    var destructive: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: GroupedSettingsMetrics.iconBoxCorner, style: .continuous)
                .fill(iconBackground)
                .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconForeground)
        }
        .accessibilityHidden(true)
    }

    private var iconBackground: Color {
        if destructive {
            return Color(UIColor.systemRed).opacity(0.15)
        }
        return Color(UIColor.secondarySystemGroupedBackground)
    }

    private var iconForeground: Color {
        if destructive {
            return Color(UIColor.systemRed)
        }
        return Color(UIColor.label)
    }
}

// MARK: - Carte groupe

struct GroupedSettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(cardFill, in: RoundedRectangle(cornerRadius: GroupedSettingsMetrics.cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: GroupedSettingsMetrics.cardCornerRadius, style: .continuous)
                .strokeBorder(Color(UIColor.separator).opacity(colorScheme == .dark ? 0.22 : 0.16), lineWidth: 0.5)
        )
    }

    @Environment(\.colorScheme) private var colorScheme

    private var cardFill: Color {
        Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor.secondarySystemGroupedBackground : UIColor.systemBackground
        })
    }
}

// MARK: - Séparateur entre lignes

struct GroupedSettingsRowDivider: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
                .frame(width: GroupedSettingsMetrics.dividerLeadingInset)
            Rectangle()
                .fill(Color(UIColor.separator))
                .frame(height: Self.hairlineHeight)
        }
    }

    /// Épaisseur 1 px logique sans `UIScreen.main` (déprécié iOS 26).
    private static var hairlineHeight: CGFloat {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scale = scenes.first(where: { $0.activationState == .foregroundActive })?.screen.scale
            ?? scenes.first?.screen.scale
            ?? 2
        return 1 / scale
    }
}

// MARK: - Lignes

/// Ligne navigation / tap avec chevron optionnel.
struct GroupedSettingsNavigationRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    var value: String?
    var showsChevron: Bool = true

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(UIColor.label))
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let value, !value.isEmpty {
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
                    .multilineTextAlignment(.trailing)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(UIColor.tertiaryLabel))
            }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}

/// Ligne simple (info) sans chevron.
struct GroupedSettingsInfoRow: View {
    let icon: String
    let title: String
    var value: String
    var valueMultiline: Bool = false
    /// Si non-nil, remplace la limite dérivée de `valueMultiline` (ex. e-mail : 2 lignes max).
    var valueLineLimit: Int? = nil

    private var resolvedValueLineLimit: Int {
        if let valueLineLimit { return valueLineLimit }
        return valueMultiline ? 4 : 1
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: icon)
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
                .fixedSize(horizontal: true, vertical: false)
            valueText
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    @ViewBuilder
    private var valueText: some View {
        Text(value)
            .font(.body)
            .foregroundStyle(Color(UIColor.secondaryLabel))
            .multilineTextAlignment(.trailing)
            .lineLimit(resolvedValueLineLimit)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

/// Ligne destructive (suppression de compte).
struct GroupedSettingsDestructiveRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                GroupedSettingsIconBox(systemName: "trash.fill", destructive: true)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(UIColor.systemRed))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ligne « session » (déconnexion) — icône orange / ambre.
struct GroupedSettingsLogoutRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: GroupedSettingsMetrics.iconBoxCorner, style: .continuous)
                        .fill(Color.orange.opacity(0.15))
                        .frame(width: GroupedSettingsMetrics.iconBoxSize, height: GroupedSettingsMetrics.iconBoxSize)
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }
                Text("Se déconnecter")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color(UIColor.label))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Titre centré « Réglages » au-dessus de la première section.
struct GroupedSettingsPageTitle: View {
    /// Dans l’en-tête Commerce : police plus légère pour rester propre dans le panneau.
    var compact: Bool = false

    var body: some View {
        Text("Réglages")
            .font(compact ? .title2.weight(.bold) : .largeTitle.weight(.bold))
            .foregroundStyle(Color(UIColor.label))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, compact ? 28 : 16)
            .padding(.bottom, 12)
    }
}
