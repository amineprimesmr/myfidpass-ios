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
    var showsAttentionDot: Bool = false

    var body: some View {
        HStack(alignment: subtitle == nil ? .center : .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(UIColor.label))
                    if showsAttentionDot {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 9, height: 9)
                            .accessibilityHidden(true)
                    }
                }
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

/// Champ numérique éditable (tap + clavier) — remplace le Stepper +/- pour les plafonds caisse.
struct GroupedSettingsEditableIntRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var zeroLabel: String = "Illimité"

    @State private var draft: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(Color(UIColor.label))
            TextField("", text: $draft, prompt: Text(zeroLabel).foregroundStyle(Color(UIColor.secondaryLabel)))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .multilineTextAlignment(.trailing)
                .font(.body.monospacedDigit())
                .foregroundStyle(Color(UIColor.label))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(UIColor.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onAppear { syncDraftFromValue() }
                .onChange(of: value) { _, _ in
                    if !isFocused { syncDraftFromValue() }
                }
                .onChange(of: draft) { _, new in
                    let digits = new.filter(\.isNumber)
                    if digits != new { draft = digits }
                    guard !digits.isEmpty, let parsed = Int(digits) else { return }
                    let clamped = min(max(parsed, range.lowerBound), range.upperBound)
                    if clamped != value { value = clamped }
                    if parsed != clamped { draft = String(clamped) }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { commitDraft() }
                }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private func syncDraftFromValue() {
        draft = value == 0 ? "" : String(value)
    }

    private func commitDraft() {
        if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            value = 0
        } else if let parsed = Int(draft.filter(\.isNumber)) {
            value = min(max(parsed, range.lowerBound), range.upperBound)
        }
        syncDraftFromValue()
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

// MARK: - Synchronisation

struct GroupedSettingsLastSyncSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var syncService: SyncService

    var showsSyncNowButton: Bool = true
    var onSyncStarted: (() -> Void)? = nil

    private static let relativeSyncFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .abbreviated
        return f
    }()

    private var lastSyncText: String {
        guard let d = syncService.lastSyncDate else { return "Jamais" }
        return Self.relativeSyncFormatter.localizedString(for: d, relativeTo: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            lastSyncRow
            if showsSyncNowButton {
                GroupedSettingsRowDivider()
                syncNowRow
            }
        }
    }

    private var lastSyncRow: some View {
        HStack(alignment: .top, spacing: 12) {
            GroupedSettingsIconBox(systemName: "arrow.triangle.2.circlepath")
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Dernière synchro")
                        .font(.body.weight(.medium))
                        .foregroundStyle(Color(UIColor.label))
                    Spacer(minLength: 8)
                    Text(lastSyncText)
                        .font(.body)
                        .foregroundStyle(Color(UIColor.secondaryLabel))
                }
                if let err = syncService.lastError, !err.isEmpty {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Color(UIColor.systemRed).opacity(colorScheme == .dark ? 0.9 : 1))
                }
            }
        }
        .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
        .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
    }

    private var syncNowRow: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Task { await syncService.syncAfterServerMutation() }
            onSyncStarted?()
        } label: {
            HStack(spacing: 12) {
                GroupedSettingsIconBox(systemName: "arrow.clockwise")
                Text("Synchroniser maintenant")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(UIColor.label))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, GroupedSettingsMetrics.horizontalPadding)
            .padding(.vertical, GroupedSettingsMetrics.rowVerticalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Titre centré au-dessus de la première section (Compte, Paramètres…).
struct GroupedSettingsPageTitle: View {
    var title: String = "Compte"
    /// Dans l’en-tête Commerce : police plus légère pour rester propre dans le panneau.
    var compact: Bool = false

    var body: some View {
        Text(title)
            .font(compact ? .title2.weight(.bold) : .largeTitle.weight(.bold))
            .foregroundStyle(Color(UIColor.label))
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.top, compact ? 28 : 16)
            .padding(.bottom, 12)
    }
}
