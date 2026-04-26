//
//  CardColorPaletteUX.swift
//  myfidpass
//
//  Palettes type Canva : défilement horizontal de pastilles + feuille saturation/teinte/hex.
//

import SwiftUI
import UIKit

// MARK: - Normalisation hex

enum CardColorPaletteUX {
    static func normalizeHex(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
        guard t.count == 6, t.allSatisfy(\.isHexDigit) else { return "2563EB" }
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
    /// Identifiants stables pour ForEach (évite collisions si deux teintes identiques).
    /// **Neutres** (Y → clair) puis **cercle chromatique** (HSL ~0° → 360°, tons type Tailwind), puis **terre** / kaki.
    /// Réf. : échelle tailwind / Material — ordre = arc-en-ciel lisible, pas aléatoire.
    static let swatches: [(id: String, hex: String)] = [
        // Gris (éclairci strict : du noir au blanc, ref. type Tailwind `gray` / sRGB)
        ("ink", "0A0A0A"), ("n950", "030712"), ("n900", "111827"), ("n800", "1F2937"), ("n700", "374151"),
        ("n600", "4B5563"), ("n500", "6B7280"), ("n400", "9CA3AF"), ("n200", "E5E7EB"), ("n100", "F3F4F6"), ("n50", "F9FAFB"), ("white", "FFFFFF"),
        // Gris teintés (froid : ardoise / bleu) puis légèrement chaud, avant le spectre
        ("navy", "1E3A8A"), ("slate7", "334155"), ("slate5", "64748B"), ("slate3", "CBD5E1"),
        ("zne7", "3F3F46"), ("zinc5", "71717A"), ("zinc2", "E4E4E7"), ("stn5", "78716C"), ("stn2", "E7E5E4"),
        // — Spectre (rouge → … → rose) — mêmes familles qu’en UI moderne
        ("red8", "991B1B"), ("red5", "EF4444"), ("red3", "FCA5A5"),
        ("rorg6", "EA580C"), ("orange5", "F97316"), ("ambr6", "D97706"), ("ambr5", "F59E0B"), ("ambr2", "FDE68A"),
        ("yel5", "EAB308"), ("yel3", "FDE047"), ("lme5", "84CC16"), ("lme3", "BEF264"), ("lme1", "ECFCCB"),
        ("grn6", "16A34A"), ("grn5", "22C55E"), ("emr5", "10B981"), ("emr3", "6EE7B7"), ("teal5", "14B8A6"), ("teal3", "5EEAD4"),
        ("cya6", "0891B2"), ("cya5", "06B6D4"), ("cya3", "67E8F9"), ("sky5", "0EA5E9"), ("sky3", "7DD3FC"), ("blu6", "2563EB"), ("blu4", "60A5FA"),
        ("ing6", "4F46E5"), ("ing5", "6366F1"), ("ing3", "A5B4FC"), ("vio6", "7C3AED"), ("vio5", "8B5CF6"), ("vio2", "DDD6FE"),
        ("pur5", "A855F7"), ("pur2", "E9D5FF"), ("fuc5", "D946EF"), ("fuc2", "F0ABFC"),         ("pik5", "EC4899"), ("pik2", "F9A8D4"), ("rse5", "F43F5E"), ("rse2", "FECDD3"),
        // Terre / sépia (chaud, après l’arc-en-ciel)
        ("amb9", "78350F"), ("brn6", "92400E"), ("kki7", "3F6212"),
    ]
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

    @State private var showPrecision = false

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

    private var swatchDiameter: CGFloat { compactEmbedded ? 32 : 40 }
    private var precisionDiameter: CGFloat { compactEmbedded ? 36 : 44 }
    private var plusIconSize: CGFloat { compactEmbedded ? 15 : 17 }
    private var rowSpacing: CGFloat { compactEmbedded ? 8 : 12 }
    private var horizontalPadding: CGFloat { compactEmbedded ? 2 : 14 }
    private var verticalPadding: CGFloat { compactEmbedded ? 4 : 12 }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: rowSpacing) {
                precisionEntryButton
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
        .sheet(isPresented: $showPrecision) {
            CardColorPrecisionSheet(hex: $hex)
        }
    }

    private var precisionEntryButton: some View {
        Button {
            showPrecision = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red,
                            ]),
                            center: .center,
                            angle: .degrees(-90)
                        )
                    )
                    .frame(width: precisionDiameter, height: precisionDiameter)
                Image(systemName: "plus")
                    .font(.system(size: plusIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .accessibilityLabel(Text("Couleur personnalisée"))
        }
        .buttonStyle(.plain)
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
    var compactEmbedded: Bool = false
    var selectionRingColor: Color = Color(hex: "7C3AED")
    /// Nombre max de couleurs sélectionnées (l’API flyer utilise surtout la 1re comme accent).
    var maxSlots: Int = 1

    @State private var showPrecision = false
    @State private var precisionScratchHex = "#FFFFFF"
    @State private var dropHoverHex: String?

    private var swatchDiameter: CGFloat { compactEmbedded ? 32 : 40 }
    private var precisionDiameter: CGFloat { compactEmbedded ? 36 : 44 }
    private var plusIconSize: CGFloat { compactEmbedded ? 15 : 17 }
    private var rowSpacing: CGFloat { compactEmbedded ? 8 : 12 }
    private var horizontalPadding: CGFloat { compactEmbedded ? 2 : 14 }
    private var verticalPadding: CGFloat { compactEmbedded ? 4 : 12 }

    private var normalizedOrdered: [String] {
        orderedHexes.compactMap { Self.canonHex($0) }
    }

    private var presetNormSet: Set<String> {
        Set(CardCanvaScrollPresets.swatches.map { CardColorPaletteUX.normalizeHex($0.hex) })
    }

    private var extraLogoSwatches: [String] {
        let seen = presetNormSet
        var out: [String] = []
        for raw in suggestedFromImages {
            let stripped = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "").uppercased()
            guard stripped.count == 6, stripped.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil else { continue }
            guard !seen.contains(stripped), !out.contains(stripped) else { continue }
            out.append(stripped)
        }
        return out.sorted { CardColorPaletteUX.relativeLuminance01(hex6: $0) < CardColorPaletteUX.relativeLuminance01(hex6: $1) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: maxSlots > 1 ? 12 : 8) {
            if maxSlots > 1 {
                priorityStrip
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: rowSpacing) {
                    precisionEntryButton
                    ForEach(CardCanvaScrollPresets.swatches, id: \.id) { item in
                        swatchButton(fixedHex: item.hex)
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
        .sheet(isPresented: $showPrecision) {
            CardColorPrecisionSheet(hex: $precisionScratchHex, onCommit: {
                if let c = Self.canonHex(precisionScratchHex) {
                    promote(c)
                }
            })
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

    private var precisionEntryButton: some View {
        Button {
            precisionScratchHex = normalizedOrdered.first ?? "#FF6B9D"
            showPrecision = true
        } label: {
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .purple, .red,
                            ]),
                            center: .center,
                            angle: .degrees(-90)
                        )
                    )
                    .frame(width: precisionDiameter, height: precisionDiameter)
                Image(systemName: "plus")
                    .font(.system(size: plusIconSize, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .accessibilityLabel(Text("Couleur personnalisée"))
        }
        .buttonStyle(.plain)
    }

    /// Taille de case fixe : la sélection ne grossit pas la pastille (seulement contour renforcé).
    private var swatchSlotSize: CGFloat { swatchDiameter + 10 }

    @ViewBuilder
    private func swatchButton(fixedHex: String) -> some View {
        let norm = CardColorPaletteUX.normalizeHex(fixedHex)
        let canon = "#" + norm
        let selected = normalizedOrdered.contains(canon)
        let isWhite = norm == "FFFFFF"
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
                    .strokeBorder(swatchRing(isWhite: isWhite, selected: selected), lineWidth: ringW)
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

    private func swatchRing(isWhite: Bool, selected: Bool) -> Color {
        if selected { return selectionRingColor }
        if isWhite { return Color.black.opacity(0.14) }
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

// MARK: - Éditeur flyer : un champ #RRGGBB = même carrousel que la création (+ précision)

/// Pastilles horizontales + bouton **+** (couleur précise) — aligné sur `FlyerAIPriorityPaletteRow` (création flyer).
struct FlyerAIColorFieldCarousel: View {
    @Binding var hex: String
    var selectionRingColor: Color = Color(hex: "7C3AED")
    var compactEmbedded: Bool = true

    @State private var ordered: [String] = ["#2563EB"]

    var body: some View {
        FlyerAIPriorityPaletteRow(
            orderedHexes: $ordered,
            compactEmbedded: compactEmbedded,
            selectionRingColor: selectionRingColor,
            maxSlots: 1
        )
        .onAppear(perform: pullFromHex)
        .onChange(of: hex) { _, _ in pullFromHex() }
        .onChange(of: ordered) { _, new in
            guard let f = new.first else { return }
            let withHash: String = {
                let t = f.trimmingCharacters(in: .whitespacesAndNewlines)
                if t.hasPrefix("#"), t.count == 7 { return t.uppercased() }
                let u = t.replacingOccurrences(of: "#", with: "").uppercased()
                guard u.count == 6, u.count == u.filter(\.isHexDigit).count else { return "#2563EB" }
                return "#" + u
            }()
            if withHash.uppercased() != hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                hex = withHash
            }
        }
    }

    private func pullFromHex() {
        let t = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let withHash: String
        if t.hasPrefix("#"), t.count == 7, t.dropFirst().allSatisfy(\.isHexDigit) {
            withHash = t.uppercased()
        } else {
            let u = t.replacingOccurrences(of: "#", with: "").uppercased()
            withHash = (u.count == 6 && u.allSatisfy(\.isHexDigit)) ? "#\(u)" : "#2563EB"
        }
        if ordered != [withHash] {
            ordered = [withHash]
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

// MARK: - Feuille précision (carré SB + teinte + hex)

struct CardColorPrecisionSheet: View {
    @Binding var hex: String
    /// Appelé après validation OK (après écriture dans `hex`).
    var onCommit: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var hue: Double = 0.65
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var hexInput: String = "#FFFFFF"
    @State private var didLoad = false

    private var composedColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    private var titleLabel: String {
        if saturation < 0.08 {
            if brightness > 0.92 { return "Blanc" }
            if brightness < 0.08 { return "Noir" }
            if brightness < 0.42 { return "Gris foncé" }
            return "Gris"
        }
        let deg = Int((hue * 360).truncatingRemainder(dividingBy: 360))
        switch deg {
        case 0..<18, 342...360: return "Rouge"
        case 18..<45: return "Orange"
        case 45..<70: return "Jaune"
        case 70..<165: return "Vert"
        case 165..<200: return "Cyan"
        case 200..<260: return "Bleu"
        case 260..<290: return "Violet"
        case 290..<342: return "Rose"
        default: return "Couleur"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack {
                    if #available(iOS 26.0, *) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                        .accessibilityLabel(Text("Fermer"))
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(AppTheme.Colors.textSecondary)
                        }
                        .accessibilityLabel(Text("Fermer"))
                    }
                    Spacer(minLength: 0)
                    if #available(iOS 26.0, *) {
                        Button("OK") {
                            commitToBinding()
                            onCommit?()
                            dismiss()
                        }
                        .buttonStyle(.glass(.regular))
                        .buttonBorderShape(.capsule)
                        .controlSize(.regular)
                        .tint(AppTheme.Colors.primary)
                    } else {
                        Button("OK") {
                            commitToBinding()
                            onCommit?()
                            dismiss()
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                    }
                }

                Text(titleLabel)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppTheme.Colors.textPrimary)

                saturationBrightnessField
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    )

                hueSlider
                    .frame(height: 32)

                hexAndPickerRow
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
            .padding(.top, 4)
            .padding(.bottom, 16)
            .background(AppTheme.Colors.background)
            .sheetHideNavigationBar()
        }
        .presentationDetents([.height(380), .medium])
        .presentationDragIndicator(.hidden)
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            loadFromBinding()
        }
    }

    private var saturationBrightnessField: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack(alignment: .topLeading) {
                ZStack {
                    LinearGradient(
                        colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let x = min(max(0, g.location.x / w), 1)
                            let y = min(max(0, g.location.y / h), 1)
                            saturation = x
                            brightness = 1 - y
                            syncHexFromHSB()
                        }
                )

                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(composedColor))
                    .position(
                        x: CGFloat(saturation) * w,
                        y: CGFloat(1 - brightness) * h
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private var hueSlider: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let thumb: CGFloat = 26
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: [
                        Color(hue: 0, saturation: 1, brightness: 1),
                        Color(hue: 0.15, saturation: 1, brightness: 1),
                        Color(hue: 0.3, saturation: 1, brightness: 1),
                        Color(hue: 0.45, saturation: 1, brightness: 1),
                        Color(hue: 0.6, saturation: 1, brightness: 1),
                        Color(hue: 0.75, saturation: 1, brightness: 1),
                        Color(hue: 0.9, saturation: 1, brightness: 1),
                        Color(hue: 1, saturation: 1, brightness: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.black.opacity(0.12), lineWidth: 1)
                )
                .contentShape(Capsule())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let x = min(max(0, g.location.x), w)
                            hue = Double(x / max(w, 1))
                            syncHexFromHSB()
                        }
                )

                Circle()
                    .fill(Color.white)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
                    .offset(x: CGFloat(hue) * max(w - thumb, 1))
                    .allowsHitTesting(false)
            }
        }
    }

    private var hexAndPickerRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(composedColor)
                .frame(width: 40, height: 40)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.1), lineWidth: 1))

            TextField("#RRGGBB", text: $hexInput)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(AppTheme.Colors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.Colors.textSecondary.opacity(0.15), lineWidth: 1)
                )
                .onChange(of: hexInput) { _, new in
                    applyHexInput(new)
                }
        }
    }

    private func loadFromBinding() {
        let raw = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "").uppercased()
        let norm: String
        if raw.count == 6, raw.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil {
            norm = raw
        } else {
            norm = "FFFFFF"
        }
        let ui = UIColor(Color(hex: norm))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            hue = Double(h)
            saturation = Double(s)
            brightness = Double(b)
        } else {
            var w: CGFloat = 0
            ui.getWhite(&w, alpha: &a)
            hue = 0
            saturation = 0
            brightness = Double(w)
        }
        hexInput = "#" + norm
    }

    private func syncHexFromHSB() {
        let out = composedColor.toHexRGBString()
        hexInput = out
        hex = out
    }

    private func applyHexInput(_ raw: String) {
        let cleaned = raw.replacingOccurrences(of: "#", with: "").uppercased()
        guard cleaned.count == 6, isValidHex6(cleaned) else { return }
        let ui = UIColor(Color(hex: cleaned))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a) {
            hue = Double(h)
            saturation = Double(s)
            brightness = Double(b)
        } else {
            var w: CGFloat = 0
            ui.getWhite(&w, alpha: &a)
            hue = 0
            saturation = 0
            brightness = Double(w)
        }
        hex = "#" + cleaned
    }

    private func commitToBinding() {
        hex = composedColor.toHexRGBString()
    }

    private func isValidHex6(_ s: String) -> Bool {
        s.range(of: "^[0-9A-F]{6}$", options: .regularExpression) != nil
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
