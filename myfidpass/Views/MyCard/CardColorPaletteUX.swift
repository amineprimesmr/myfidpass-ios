//
//  CardColorPaletteUX.swift
//  myfidpass
//
//  Pastilles : grille `AppVibrantColorPalette` + carrousel flyer (teintes seules, ordre HSV).
//

import SwiftUI
import UIKit

// MARK: - Normalisation hex

enum CardColorPaletteUX {
    static func normalizeHex(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard t.count == 6, t.allSatisfy(\.isHexDigit) else { return AppVibrantColorPalette.defaultHex6 }
        return t
    }

    static func hexWithHash(_ raw: String) -> String {
        "#" + normalizeHex(raw)
    }

    /// Luminance relative approximative (sRGB, 0 = noir, 1 = blanc) — ordre d’affichage « dégradé » cohérent.
    static func relativeLuminance01(hex6: String) -> Double {
        let n = normalizeHex(hex6)
        guard let r = UInt8(String(n.prefix(2)), radix: 16),
              let g = UInt8(String(n.dropFirst(2).prefix(2)), radix: 16),
              let b = UInt8(String(n.suffix(2)), radix: 16) else { return 0 }
        let rs = Double(r) / 255
        let gs = Double(g) / 255
        let bs = Double(b) / 255
        return 0.2126 * rs + 0.7152 * gs + 0.0722 * bs
    }
}

// MARK: - Pastilles prédéfinies (scroll large)

enum CardCanvaScrollPresets {
    static var swatches: [(id: String, hex: String)] { AppVibrantColorPalette.scrollSwatches }
}

// MARK: - Barre horizontale + bouton précision

struct CanvaStylePaletteRow: View {
    @Binding var hex: String
    /// Teintes extraites des images (logo, fond de carte) — ajoutées après les préréglages.
    var suggestedFromImages: [String] = []
    /// Intégré dans une carte type « prompt flyer » : pas d’encart gris, pastilles plus petites.
    var compactEmbedded: Bool = false
    /// Anneau de sélection (ex. thème violet carte vs violet studio flyer).
    var selectionRingColor: Color = Color(hex: "7C3AED")

    /// `nil` si aucune couleur explicite (ex. libellés = défaut système).
    private var selectionNorm: String? {
        let raw = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "").uppercased()
        guard raw.count == 6, raw.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { return nil }
        return raw
    }

    /// Couleurs issues du logo / fond : **sans** filtre sur les préréglages (sinon orange ≈ preset → rien n’apparaissait en « extra » en fin de liste).
    private var imagePaletteSwatches: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in suggestedFromImages {
            let stripped = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "").uppercased()
            guard stripped.count == 6, stripped.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { continue }
            let norm = CardColorPaletteUX.normalizeHex(stripped)
            guard !seen.contains(norm) else { continue }
            seen.insert(norm)
            out.append(norm)
        }
        return out
    }

    /// Couleur enregistrée hors palette (ex. ancienne donnée) : une pastille pour la conserver ou choisir une teinte de la grille.
    private var orphanSelectionHex6: String? {
        guard let s = selectionNorm else { return nil }
        let preset = Set(CardCanvaScrollPresets.swatches.map { CardColorPaletteUX.normalizeHex($0.hex) })
        if preset.contains(s) { return nil }
        if imagePaletteSwatches.contains(s) { return nil }
        return s
    }

    private var swatchDiameter: CGFloat { compactEmbedded ? 32 : 40 }
    private var rowSpacing: CGFloat { compactEmbedded ? 8 : 12 }
    private var horizontalPadding: CGFloat { compactEmbedded ? 2 : 14 }
    private var verticalPadding: CGFloat { compactEmbedded ? 4 : 12 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: rowSpacing) {
                if let o = orphanSelectionHex6 {
                    swatchButton(fixedHex: o)
                }
                ForEach(imagePaletteSwatches, id: \.self) { n in
                    swatchButton(fixedHex: n)
                }
                ForEach(CardCanvaScrollPresets.swatches, id: \.id) { item in
                    swatchButton(fixedHex: item.hex)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .modifier(CanvaPaletteRowChrome(compactEmbedded: compactEmbedded))
    }

    @ViewBuilder
    private func swatchButton(fixedHex: String) -> some View {
        let norm = CardColorPaletteUX.normalizeHex(fixedHex)
        let selected = selectionNorm == norm
        let isWhite = norm == "FFFFFF"
        let outer: CGFloat = selected ? swatchDiameter + 6 : swatchDiameter + 2
        Button {
            withAnimation(.easeOut(duration: 0.18)) {
                hex = "#" + norm
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: norm))
                    .frame(width: swatchDiameter, height: swatchDiameter)
                Circle()
                    .strokeBorder(swatchRing(isWhite: isWhite, selected: selected), lineWidth: selected ? 3 : 1)
                    .frame(width: outer, height: outer)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Couleur #\(norm)"))
    }

    private func swatchRing(isWhite: Bool, selected: Bool) -> Color {
        if selected { return selectionRingColor }
        if isWhite { return Color.black.opacity(0.14) }
        return Color.black.opacity(0.08)
    }
}

// MARK: - Flyer IA : jusqu’à `maxSlots` couleur(s) (défaut 1), ordre = priorité

struct FlyerAIPriorityPaletteRow: View {
    @Binding var orderedHexes: [String]
    var suggestedFromImages: [String] = []
    /// Palette imposée (ordre exact) ; `nil` = palette par défaut du composant.
    var customSwatches: [String]? = nil
    var compactEmbedded: Bool = false
    var selectionRingColor: Color = Color(hex: "7C3AED")
    /// Nombre max de couleurs sélectionnées (l’API flyer utilise surtout la 1re comme accent).
    var maxSlots: Int = 1
    /// Ouvre une feuille **grille** uniquement (pastilles) — application immédiate au tap.
    var showPrecisionColorPlus: Bool = true
    /// Teintes extraites du logo : désactivé pour l’éditeur flyer (ordre confus + doublons avec la grille).
    var includeImageSuggestions: Bool = false

    @State private var dropHoverHex: String?
    @State private var precisionSheetOpen = false

    private var swatchDiameter: CGFloat { compactEmbedded ? 32 : 40 }
    private var rowSpacing: CGFloat { compactEmbedded ? 8 : 12 }
    private var horizontalPadding: CGFloat { compactEmbedded ? 2 : 14 }
    private var verticalPadding: CGFloat { compactEmbedded ? 4 : 12 }

    private var normalizedOrdered: [String] {
        orderedHexes.compactMap { Self.canonHex($0) }
    }

    private var presetNormSet: Set<String> {
        Set(baseSwatchHexes.map { CardColorPaletteUX.normalizeHex($0) })
    }

    private var baseSwatchHexes: [String] {
        if let customSwatches, !customSwatches.isEmpty {
            return customSwatches
        }
        return CardCanvaScrollPresets.swatches.map(\.hex)
    }

    private var extraLogoSwatches: [String] {
        guard includeImageSuggestions else { return [] }
        let seen = presetNormSet
        var out: [String] = []
        for raw in suggestedFromImages {
            let stripped = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
            guard stripped.count == 6, stripped.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { continue }
            guard !seen.contains(stripped), !out.contains(stripped) else { continue }
            out.append(stripped)
        }
        return out.sorted { hueSortKey6($0) < hueSortKey6($1) }
    }

    /// Tri teinte (même logique que `AppVibrantColorPalette.flyerCarouselHex6`).
    private func hueSortKey6(_ raw: String) -> Double {
        AppVibrantColorPalette.flyerHueSortKey6(raw)
    }

    /// Pastilles « + » : teinte courante + carrousel + grille HSB (sans doublon).
    private var precisionGridHex6Ordered: [String] {
        var seen = Set<String>()
        var out: [String] = []
        func push(_ raw: String) {
            let n = CardColorPaletteUX.normalizeHex(raw.replacingOccurrences(of: "#", with: ""))
            guard seen.insert(n).inserted else { return }
            out.append(n)
        }
        if let f = normalizedOrdered.first { push(f) }
        for c in legacyOrderedNotInPreset { push(c) }
        for h in baseSwatchHexes { push(h) }
        for h in AppVibrantColorPalette.precisionPickerGridHex6 { push(h) }
        return out
    }

    /// Couleurs encore choisies mais absentes de la grille (données existantes).
    private var legacyOrderedNotInPreset: [String] {
        let preset = Set(baseSwatchHexes.map { CardColorPaletteUX.normalizeHex($0) })
        let extra = Set(extraLogoSwatches.map { CardColorPaletteUX.normalizeHex($0) })
        var out: [String] = []
        for canon in normalizedOrdered {
            let n = CardColorPaletteUX.normalizeHex(canon.replacingOccurrences(of: "#", with: ""))
            if !preset.contains(n), !extra.contains(n), !out.contains(canon) {
                out.append(canon)
            }
        }
        return out
    }

    var body: some View {
        VStack(alignment: .leading, spacing: maxSlots > 1 ? 12 : 8) {
            if maxSlots > 1 {
                priorityStrip
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: rowSpacing) {
                    if showPrecisionColorPlus {
                        precisionPlusButton
                    }
                    ForEach(legacyOrderedNotInPreset, id: \.self) { canon in
                        swatchButton(fixedHex: canon)
                    }
                    ForEach(baseSwatchHexes, id: \.self) { hex in
                        swatchButton(fixedHex: hex)
                    }
                    ForEach(extraLogoSwatches, id: \.self) { n in
                        swatchButton(fixedHex: n)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
            }
            .modifier(CanvaPaletteRowChrome(compactEmbedded: compactEmbedded))
        }
    }

    private var priorityStrip: some View {
        let arr = normalizedOrdered
        return HStack(spacing: 10) {
            HStack(spacing: 12) {
                ForEach(arr, id: \.self) { hx in
                    priorityChip(rank: (arr.firstIndex(of: hx) ?? 0) + 1, hex: hx)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: arr)
            Spacer(minLength: 0)
            Text("\(arr.count)/\(max(1, maxSlots))")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.42))
        }
    }

    @ViewBuilder
    private func priorityChip(rank: Int, hex: String) -> some View {
        let norm = hex
        let chipSize: CGFloat = compactEmbedded ? 38 : 44
        let isHover = dropHoverHex == norm
        let canDrag = maxSlots > 1
        let core = priorityChipVisual(rank: rank, norm: norm, chipSize: chipSize, isHover: isHover)
            .scaleEffect(isHover ? 1.06 : 1, anchor: .center)
            .animation(.spring(response: 0.32, dampingFraction: 0.82), value: isHover)
            .onTapGesture {
                removeHex(norm)
            }
        if canDrag {
            core
                .draggable(norm) {
                    priorityChipVisual(rank: rank, norm: norm, chipSize: max(28, chipSize - 8), isHover: false)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let dragged = items.first, dragged != norm else { return false }
                    reorder(dragged: dragged, before: norm)
                    return true
                } isTargeted: { targeted in
                    if targeted { dropHoverHex = norm } else if dropHoverHex == norm { dropHoverHex = nil }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Couleur priorité \(rank), retirer ou réordonner par glisser"))
        } else {
            core
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Couleur du flyer, appuyer sur une pastille pour changer"))
        }
    }

    private func priorityChipVisual(rank: Int, norm: String, chipSize: CGFloat, isHover: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: norm))
                .frame(width: chipSize - 6, height: chipSize - 6)
                .shadow(color: Color.black.opacity(0.35), radius: 6, y: 3)
            Circle()
                .strokeBorder(isHover ? Color.white.opacity(0.85) : Color.white.opacity(0.35), lineWidth: isHover ? 2.5 : 1.5)
                .frame(width: chipSize - 6, height: chipSize - 6)
        }
        .frame(width: chipSize, height: chipSize)
        .overlay(alignment: .topTrailing) {
            Text("\(rank)")
                .font(.system(size: 10, weight: .black, design: .default))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.black.opacity(0.48)))
                .offset(x: 5, y: -5)
        }
    }

    /// Taille de case fixe : la sélection ne grossit pas la pastille (seulement contour renforcé).
    private var swatchSlotSize: CGFloat { swatchDiameter + 10 }

    private var precisionPlusButton: some View {
        let outer: CGFloat = swatchDiameter + 4
        return Button {
            precisionSheetOpen = true
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: swatchDiameter, height: swatchDiameter)
                Circle()
                    .strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    .frame(width: outer, height: outer)
                Image(systemName: "plus")
                    .font(.system(size: compactEmbedded ? 14 : 16, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .frame(width: swatchSlotSize, height: swatchSlotSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Choisir une couleur précise"))
        .sheet(isPresented: $precisionSheetOpen) {
            FlyerPrecisionColorGridSheet(
                selectionHex6: normalizedOrdered.first.map {
                    CardColorPaletteUX.normalizeHex($0.replacingOccurrences(of: "#", with: ""))
                },
                gridHex6: precisionGridHex6Ordered,
                selectionRingColor: selectionRingColor,
                swatchPixel: max(36, swatchDiameter + 2),
                columnSpacing: compactEmbedded ? 8 : 10,
                onSelectCanon: { canon in
                    promote(canon)
                },
                dismiss: { precisionSheetOpen = false }
            )
            .presentationDragIndicator(.visible)
            .presentationDetents([.medium, .large])
        }
    }

    /// Bord cranté visible sur blanc / gris très clair.
    private static func isLightSwatchBackground(_ norm: String) -> Bool {
        let s = Set(["FFFFFF", "F5F5F7", "F5F5F5", "FAFAFA", "F0F0F0", "E8E8ED", "D1D1D6"])
        return s.contains(norm.uppercased())
    }

    @ViewBuilder
    private func swatchButton(fixedHex: String) -> some View {
        let norm = CardColorPaletteUX.normalizeHex(fixedHex)
        let canon = "#" + norm
        let selected = normalizedOrdered.contains(canon)
        let isLight = Self.isLightSwatchBackground(norm)
        let ringW: CGFloat = selected ? 3 : 1.25
        Button {
            if selected {
                if normalizedOrdered.count <= 1 {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                } else {
                    removeHex(canon)
                }
            } else {
                promote(canon)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(hex: norm))
                    .frame(width: swatchDiameter, height: swatchDiameter)
                if selected {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                        .frame(width: swatchDiameter + 5, height: swatchDiameter + 5)
                }
                Circle()
                    .strokeBorder(swatchRing(isLight: isLight, selected: selected), lineWidth: ringW)
                    .frame(width: swatchDiameter + (selected ? 7 : 4), height: swatchDiameter + (selected ? 7 : 4))
            }
            .frame(width: swatchSlotSize, height: swatchSlotSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            Text(
                selected
                    ? (maxSlots <= 1 ? "Couleur du flyer sélectionnée, #\(norm)" : "Retirer la couleur #\(norm)")
                    : "Choisir la couleur #\(norm) pour le flyer"
            )
        )
    }

    private func swatchRing(isLight: Bool, selected: Bool) -> Color {
        if selected { return selectionRingColor }
        if isLight { return Color.black.opacity(0.16) }
        return Color.black.opacity(0.08)
    }

    private func reorder(dragged: String, before target: String) {
        dropHoverHex = nil
        var arr = normalizedOrdered
        guard let i = arr.firstIndex(of: dragged), let j = arr.firstIndex(of: target), dragged != target else { return }
        arr.remove(at: i)
        let dest = i < j ? j - 1 : j
        arr.insert(dragged, at: dest)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            orderedHexes = arr
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func promote(_ canon: String) {
        var arr = normalizedOrdered
        arr.removeAll { $0 == canon }
        arr.insert(canon, at: 0)
        let cap = max(1, maxSlots)
        if arr.count > cap {
            arr = Array(arr.prefix(cap))
        }
        guard !arr.isEmpty else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
            orderedHexes = arr
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func removeHex(_ canon: String) {
        var arr = normalizedOrdered
        guard arr.contains(canon) else { return }
        if arr.count <= 1 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            return
        }
        arr.removeAll { $0 == canon }
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            orderedHexes = arr
        }
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }

    private static func canonHex(_ raw: String) -> String? {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withHash = t.hasPrefix("#") ? t : "#\(t)"
        guard withHash.range(of: #"^#[0-9A-Fa-f]{6}$"#, options: .regularExpression) != nil else { return nil }
        return withHash
    }
}

// MARK: - Grille « couleur précise » (flyer)

/// Feuille du bouton **+** : pastilles en grille seulement — tap = validation + fermeture.
private struct FlyerPrecisionColorGridSheet: View {
    let selectionHex6: String?
    let gridHex6: [String]
    let selectionRingColor: Color
    let swatchPixel: CGFloat
    let columnSpacing: CGFloat
    let onSelectCanon: (String) -> Void
    let dismiss: () -> Void

    private static let sheetCanvas = Color(red: 14 / 255, green: 17 / 255, blue: 19 / 255)

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: swatchPixel + 4, maximum: 54), spacing: columnSpacing)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: columnSpacing) {
                ForEach(gridHex6, id: \.self) { raw in
                    let norm = CardColorPaletteUX.normalizeHex(raw)
                    let selected = selectionHex6 == norm
                    let isLight = Self.lightSwatchNorms.contains(norm.uppercased())
                    Button {
                        onSelectCanon("#" + norm)
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: norm))
                                .frame(width: swatchPixel, height: swatchPixel)
                            if selected {
                                Circle()
                                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                                    .frame(width: swatchPixel + 5, height: swatchPixel + 5)
                            }
                            Circle()
                                .strokeBorder(swatchRing(isLight: isLight, selected: selected), lineWidth: selected ? 3 : 1.25)
                                .frame(width: swatchPixel + (selected ? 7 : 4), height: swatchPixel + (selected ? 7 : 4))
                        }
                        .frame(height: swatchPixel + 14)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(selected ? "Couleur #\(norm), sélectionnée" : "Choisir #\(norm)"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .background(Self.sheetCanvas.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }

    private func swatchRing(isLight: Bool, selected: Bool) -> Color {
        if selected { return selectionRingColor }
        if isLight { return Color.black.opacity(0.16) }
        return Color.black.opacity(0.08)
    }

    private static let lightSwatchNorms: Set<String> = [
        "FFFFFF", "F5F5F7", "F5F5F5", "FAFAFA", "F0F0F0", "E8E8ED", "D1D1D6", "C7C7CC",
        "FFF176", "FF80AB", "EA80FC", "18FFFF", "4DD0E1", "80DEEA",
        "F0E6D8", "F5EBDD", "FAF3E8", "E8DCC8", "FCE4EC", "FFF9C4", "FFE0B2", "B2EBF2", "F3E5F5",
        "D7CCC8", "BCAAA4", "C5E1A5", "A5D6A7", "FFCC80",
    ]
}

// MARK: - Éditeur flyer : un champ #RRGGBB = même carrousel que la création (+ précision)

/// Pastilles horizontales + bouton **+** (couleur précise) — palette flyer sans neutres, ordre teinte.
struct FlyerAIColorFieldCarousel: View {
    @Binding var hex: String
    var selectionRingColor: Color = Color(hex: "7C3AED")
    var compactEmbedded: Bool = true
    /// Pastilles affichées (sans `#`). `nil` = `AppVibrantColorPalette.flyerCarouselHex6`.
    var presetHex6: [String]? = nil

    @State private var ordered: [String] = []

    private var baseHexList: [String] {
        if let presetHex6, !presetHex6.isEmpty { return presetHex6 }
        return AppVibrantColorPalette.flyerCarouselHex6
    }

    var body: some View {
        FlyerAIPriorityPaletteRow(
            orderedHexes: $ordered,
            suggestedFromImages: [],
            customSwatches: baseHexList,
            compactEmbedded: compactEmbedded,
            selectionRingColor: selectionRingColor,
            maxSlots: 1,
            showPrecisionColorPlus: true,
            includeImageSuggestions: false
        )
        .onAppear(perform: pullFromHex)
        .onChange(of: hex) { _, _ in pullFromHex() }
        .onChange(of: ordered) { _, new in
            guard let f = new.first else { return }
            let withHash: String? = {
                let t = f.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("#"), t.count == 7, t.dropFirst().allSatisfy(\.isHexDigit) {
                    return t.uppercased()
                }
                let u = t.replacingOccurrences(of: "#", with: "").uppercased()
                if u.count == 6 && u.allSatisfy(\.isHexDigit) { return "#" + u }
                return nil
            }()
            guard let wh = withHash else { return }
            if wh.uppercased() != hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                hex = wh
            }
        }
    }

    private func pullFromHex() {
        let t = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        let withHash: String?
        if t.hasPrefix("#"), t.count == 7, t.dropFirst().allSatisfy(\.isHexDigit) {
            withHash = t.uppercased()
        } else {
            let u = t.replacingOccurrences(of: "#", with: "").uppercased()
            if u.count == 6 && u.allSatisfy(\.isHexDigit) {
                withHash = "#\(u)"
            } else {
                return
            }
        }
        guard let w = withHash else { return }
        if ordered != [w] {
            ordered = [w]
        }
    }
}

// MARK: - Chrome optionnel (carte vs embarqué)

private struct CanvaPaletteRowChrome: ViewModifier {
    var compactEmbedded: Bool

    func body(content: Content) -> some View {
        if compactEmbedded {
            content
        } else {
            content
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Bloc titré (feuille Ma Carte)

struct LabeledCanvaColorPalette: View {
    var title: String?
    var caption: String?
    @Binding var hex: String
    var imageSuggestions: [String] = []

    init(title: String? = nil, caption: String? = nil, hex: Binding<String>, imageSuggestions: [String] = []) {
        self.title = title
        self.caption = caption
        self._hex = hex
        self.imageSuggestions = imageSuggestions
    }

    private var showTitle: Bool {
        guard let title else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var showCaption: Bool {
        guard let caption else { return false }
        return !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: (showTitle || showCaption) ? 8 : 0) {
            if showTitle, let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)
            }
            if showCaption, let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            CanvaStylePaletteRow(hex: $hex, suggestedFromImages: imageSuggestions)
        }
    }
}
