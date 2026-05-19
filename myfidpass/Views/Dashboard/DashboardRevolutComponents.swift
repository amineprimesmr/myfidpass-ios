//
//  DashboardRevolutComponents.swift
//  myfidpass
//
//  Style « home » type Revolut : palette adaptée au mode clair / sombre.
//

import SwiftUI

struct DashboardRevolutPalette {
    let canvas: Color
    let card: Color
    let secondaryText: Color
    let tertiaryText: Color
    let accentBlue: Color
    let accentGreen: Color
    /// Titres / champs sur le fond « canvas » (hors cartes).
    let onCanvasPrimary: Color
    let onCanvasSecondary: Color
    /// Texte principal sur les cartes bento.
    let onCardPrimary: Color
    let cardStroke: Color
    let divider: Color
    let searchFieldStroke: Color
    let barButtonFill: Color
    let chipSelectedFG: Color
    let chipUnselectedFG: Color
    let chipUnselectedBG: Color
    /// Pastille transaction (liste type neo-banque).
    let transactionPillBG: Color
    let transactionIconDisc: Color

    init(colorScheme: ColorScheme) {
        switch colorScheme {
        case .dark:
            canvas = .black
            card = Color(red: 0.11, green: 0.11, blue: 0.12)
            secondaryText = Color.white.opacity(0.55)
            tertiaryText = Color.white.opacity(0.38)
            accentBlue = Color(red: 0.35, green: 0.55, blue: 1.0)
            accentGreen = Color(red: 0.2, green: 0.78, blue: 0.55)
            onCanvasPrimary = .white
            onCanvasSecondary = Color.white.opacity(0.55)
            onCardPrimary = .white
            cardStroke = Color.white.opacity(0.06)
            divider = Color.white.opacity(0.08)
            searchFieldStroke = Color.white.opacity(0.08)
            barButtonFill = Color.white.opacity(0.14)
            chipSelectedFG = .white
            chipUnselectedFG = Color.white.opacity(0.65)
            chipUnselectedBG = Color.white.opacity(0.12)
            transactionPillBG = Color.white.opacity(0.10)
            transactionIconDisc = Color.white.opacity(0.16)
        case .light:
            canvas = Color(red: 0.96, green: 0.97, blue: 0.99)
            card = Color.white
            secondaryText = Color(red: 0.39, green: 0.45, blue: 0.55)
            tertiaryText = Color(red: 0.58, green: 0.64, blue: 0.72)
            accentBlue = Color(red: 0.15, green: 0.39, blue: 0.92)
            accentGreen = Color(red: 0.05, green: 0.65, blue: 0.45)
            onCanvasPrimary = Color(red: 0.06, green: 0.09, blue: 0.16)
            onCanvasSecondary = secondaryText
            onCardPrimary = Color(red: 0.06, green: 0.09, blue: 0.16)
            cardStroke = Color.black.opacity(0.06)
            divider = Color.black.opacity(0.08)
            searchFieldStroke = Color.black.opacity(0.08)
            barButtonFill = Color.black.opacity(0.10)
            chipSelectedFG = .white
            chipUnselectedFG = onCanvasPrimary.opacity(0.72)
            chipUnselectedBG = Color.black.opacity(0.08)
            transactionPillBG = Color(red: 0.89, green: 0.91, blue: 0.94)
            transactionIconDisc = Color(red: 0.82, green: 0.85, blue: 0.90)
        @unknown default:
            canvas = .black
            card = Color(red: 0.11, green: 0.11, blue: 0.12)
            secondaryText = Color.white.opacity(0.55)
            tertiaryText = Color.white.opacity(0.38)
            accentBlue = Color(red: 0.35, green: 0.55, blue: 1.0)
            accentGreen = Color(red: 0.2, green: 0.78, blue: 0.55)
            onCanvasPrimary = .white
            onCanvasSecondary = Color.white.opacity(0.55)
            onCardPrimary = .white
            cardStroke = Color.white.opacity(0.06)
            divider = Color.white.opacity(0.08)
            searchFieldStroke = Color.white.opacity(0.08)
            barButtonFill = Color.white.opacity(0.14)
            chipSelectedFG = .white
            chipUnselectedFG = Color.white.opacity(0.65)
            chipUnselectedBG = Color.white.opacity(0.12)
            transactionPillBG = Color.white.opacity(0.10)
            transactionIconDisc = Color.white.opacity(0.16)
        }
    }
}

/// Section d’accueil : titre (et chevron optionnel) **dans** le même rectangle que le contenu, UX homogène.
struct RevolutDashboardSection<Content: View>: View {
    let title: String
    var showChevron: Bool = true
    let palette: DashboardRevolutPalette
    /// Si non-nil, toute la ligne de titre est cliquable (ex. ouvrir l’historique complet).
    var onHeaderTap: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    private var headerRow: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(palette.secondaryText)
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(palette.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let onHeaderTap {
                Button(action: onHeaderTap) {
                    headerRow
                }
                .buttonStyle(.borderless)
            } else {
                headerRow
            }
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.cardStroke, lineWidth: 1)
        )
    }
}

/// Ligne membre dans le hub « Membres & activité » (style Revolut).
struct RevolutMemberActivityRow: View {
    let summary: MemberActivitySummary
    let palette: DashboardRevolutPalette

    private var name: String { summary.card.clientDisplayName ?? "Client" }

    private var initial: String {
        let t = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = t.first else { return "?" }
        return String(c).uppercased()
    }

    private var activityDate: Date {
        summary.lastScanDate ?? summary.card.createdAt ?? .distantPast
    }

    private var isScanHighlight: Bool { summary.lastScanDate != nil || summary.card.stampsCount > 0 }

    private var eventTitle: String { isScanHighlight ? "Scan" : "Carte créée" }

    private var iconBackground: Color {
        isScanHighlight ? palette.accentGreen.opacity(0.2) : palette.accentBlue.opacity(0.22)
    }

    private var iconTint: Color {
        isScanHighlight ? palette.accentGreen : palette.accentBlue
    }

    private var formattedWhen: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .abbreviated
        return f.localizedString(for: activityDate, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Text(initial)
                    .font(.system(size: 17, weight: .bold, design: .default))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.onCardPrimary)
                    .lineLimit(1)
                if let email = summary.card.clientEmail, !email.isEmpty {
                    Text(email)
                        .font(.caption)
                        .foregroundStyle(palette.secondaryText)
                        .lineLimit(1)
                }
                Text("\(eventTitle) · \(formattedWhen)")
                    .font(.caption)
                    .foregroundStyle(palette.tertiaryText)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(summary.card.stampsCount)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(palette.onCardPrimary)
                Text("pts")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(palette.tertiaryText)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

struct RevolutActivityRow: View {
    let entry: DashboardActivityEntry
    let palette: DashboardRevolutPalette

    private var iconBackground: Color {
        switch entry.kind {
        case .newCard: return palette.accentBlue.opacity(0.22)
        case .scan: return palette.accentGreen.opacity(0.2)
        }
    }

    private var iconTint: Color {
        switch entry.kind {
        case .newCard: return palette.accentBlue
        case .scan: return palette.accentGreen
        }
    }

    private var formattedWhen: String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "fr_FR")
        f.unitsStyle = .abbreviated
        return f.localizedString(for: entry.date, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconBackground)
                    .frame(width: 44, height: 44)
                Image(systemName: entry.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.clientName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.onCardPrimary)
                Text("\(entry.eventTitle) · \(formattedWhen)")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryText)
            }
            Spacer(minLength: 0)
            Text(entry.kind == .scan ? "Scan" : "Carte")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.tertiaryText)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Fond écran flyer (éditeur) — partagé avec d’autres écrans (ex. paywall Pro) pour le même graphite + halo.

enum FlyerEditorSurfaceColors {
    /// Identique à l’arrière-plan `ScrollView` de l’assistant flyer (`#0e1113`).
    static let canvas = Color(red: 14 / 255, green: 17 / 255, blue: 19 / 255)
    /// Halo bleu-gris derrière les blocs flyer (`#242d3b`).
    static let glowDepth = Color(red: 36 / 255, green: 45 / 255, blue: 59 / 255)
}

/// Même halo radial que Paywall PRO / surfaces « Flyer » (assistant, blocs halo).
struct FlyerEditorCanvasBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let endR = max(proxy.size.width, proxy.size.height) * 0.95
            ZStack {
                FlyerEditorSurfaceColors.canvas
                RadialGradient(
                    colors: [
                        FlyerEditorSurfaceColors.glowDepth.opacity(0.65),
                        FlyerEditorSurfaceColors.glowDepth.opacity(0.28),
                        FlyerEditorSurfaceColors.canvas.opacity(0),
                    ],
                    center: UnitPoint(x: 0.5, y: 0.08),
                    startRadius: 0,
                    endRadius: endR
                )
                .blur(radius: 24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
