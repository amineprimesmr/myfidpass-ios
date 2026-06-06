//
//  CommerceStatsSocialNetworkCard.swift
//  myfidpass
//
//  Carte réseaux sociaux — même structure UX exacte que CommerceStatsPointsAttributedCard,
//  avec vrai logo PNG et couleur de courbe propre à chaque plateforme.
//

import SwiftUI

// MARK: - Palette couleurs par réseau

private enum SocialNetworkPalette {

    static func lineColor(for networkId: String) -> Color {
        switch networkId {
        case "social-instagram": return Color(red: 0.87, green: 0.17, blue: 0.48)
        case "social-tiktok":    return Color(red: 0.41, green: 0.79, blue: 0.82)
        case "social-facebook":  return Color(red: 0.24, green: 0.47, blue: 0.95)
        case "social-twitter":   return Color(red: 0.10, green: 0.10, blue: 0.10)
        default:                 return .blue
        }
    }

    static func areaColors(for networkId: String) -> [Color] {
        switch networkId {
        case "social-instagram":
            return [Color(red: 0.96, green: 0.53, blue: 0.16).opacity(0.28),
                    Color(red: 0.87, green: 0.17, blue: 0.48).opacity(0.14),
                    Color(red: 0.51, green: 0.20, blue: 0.69).opacity(0.04)]
        case "social-tiktok":
            return [Color(red: 0.41, green: 0.79, blue: 0.82).opacity(0.26),
                    Color(red: 0.93, green: 0.11, blue: 0.32).opacity(0.08),
                    Color(red: 0.93, green: 0.11, blue: 0.32).opacity(0.04)]
        case "social-facebook":
            return [Color(red: 0.24, green: 0.47, blue: 0.95).opacity(0.26),
                    Color(red: 0.15, green: 0.33, blue: 0.83).opacity(0.04)]
        case "social-twitter":
            return [Color(red: 0.10, green: 0.10, blue: 0.10).opacity(0.22),
                    Color(red: 0.10, green: 0.10, blue: 0.10).opacity(0.04)]
        default:
            return [Color.blue.opacity(0.22), Color.blue.opacity(0.04)]
        }
    }

    static func assetName(for networkId: String) -> String? {
        switch networkId {
        case "social-instagram": return "SocialInstagram"
        case "social-tiktok":    return "SocialTikTok"
        case "social-facebook":  return "SocialFacebook"
        default:                 return nil
        }
    }

    static func label(for networkId: String) -> String {
        switch networkId {
        case "social-instagram": return "Instagram"
        case "social-tiktok":    return "TikTok"
        case "social-facebook":  return "Facebook"
        case "social-twitter":   return "X"
        default:                 return networkId
        }
    }

    static func infoMessage(for networkId: String) -> String {
        let name = label(for: networkId)
        return "Nombre de clients ayant suivi le compte \(name) via la mission fidélité sur la période affichée."
    }
}

// MARK: - Logo réseau (vrai PNG ou X dessiné en SwiftUI)

private struct SocialNetworkLogo: View {
    let networkId: String
    let size: CGFloat

    var body: some View {
        ZStack {
            if let asset = SocialNetworkPalette.assetName(for: networkId) {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                // X logo dessiné
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(Color.black)
                    .frame(width: size, height: size)
                XLogoShape()
                    .fill(Color.white)
                    .frame(width: size * 0.56, height: size * 0.56)
            }
        }
    }
}

private struct XLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let t: CGFloat = w * 0.14   // épaisseur barre

        var p = Path()
        // Barre diagonale \ (haut-gauche → bas-droite)
        let pts1: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: t, y: 0),
            CGPoint(x: w, y: h),
            CGPoint(x: w - t, y: h),
        ]
        p.move(to: pts1[0]); pts1.dropFirst().forEach { p.addLine(to: $0) }; p.closeSubpath()

        // Barre diagonale / (haut-droite → bas-gauche)
        let pts2: [CGPoint] = [
            CGPoint(x: w - t, y: 0),
            CGPoint(x: w, y: 0),
            CGPoint(x: t, y: h),
            CGPoint(x: 0, y: h),
        ]
        p.move(to: pts2[0]); pts2.dropFirst().forEach { p.addLine(to: $0) }; p.closeSubpath()
        return p
    }
}

// MARK: - Courbe lissée (réutilise la même logique Bezier que PointsAttributed)

private struct SocialLineShape: Shape {
    let values: [CGFloat]
    func path(in rect: CGRect) -> Path {
        guard !values.isEmpty else { return Path() }
        let w = max(1, rect.width); let h = max(1, rect.height)
        let topPad: CGFloat = 6; let bottomPad: CGFloat = 8
        let usableH = max(1, h - topPad - bottomPad)
        let pts: [CGPoint] = values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) / CGFloat(max(1, values.count - 1)) * w,
                    y: topPad + usableH - min(1, max(0, v)) * usableH * 0.92)
        }
        var p = Path(); p.move(to: pts[0])
        guard pts.count > 1 else { return p }
        if pts.count == 2 { p.addLine(to: pts[1]); return p }
        for i in 1 ..< pts.count - 1 {
            let mid = CGPoint(x: (pts[i].x + pts[i+1].x) * 0.5, y: (pts[i].y + pts[i+1].y) * 0.5)
            p.addQuadCurve(to: mid, control: pts[i])
        }
        p.addQuadCurve(to: pts.last!, control: pts[pts.count - 2])
        return p
    }
}

private struct SocialAreaShape: Shape {
    let values: [CGFloat]
    func path(in rect: CGRect) -> Path {
        guard !values.isEmpty else { return Path() }
        let w = max(1, rect.width); let h = max(1, rect.height)
        let yBase = rect.maxY
        let topPad: CGFloat = 6; let bottomPad: CGFloat = 8
        let usableH = max(1, h - topPad - bottomPad)
        let pts: [CGPoint] = values.enumerated().map { i, v in
            CGPoint(x: CGFloat(i) / CGFloat(max(1, values.count - 1)) * w,
                    y: topPad + usableH - min(1, max(0, v)) * usableH * 0.92)
        }
        var p = Path()
        p.move(to: CGPoint(x: 0, y: yBase)); p.addLine(to: pts[0])
        if pts.count == 2 { p.addLine(to: pts[1]) }
        else {
            for i in 1 ..< pts.count - 1 {
                let mid = CGPoint(x: (pts[i].x + pts[i+1].x) * 0.5, y: (pts[i].y + pts[i+1].y) * 0.5)
                p.addQuadCurve(to: mid, control: pts[i])
            }
            p.addQuadCurve(to: pts.last!, control: pts[pts.count - 2])
        }
        p.addLine(to: CGPoint(x: w, y: yBase)); p.closeSubpath()
        return p
    }
}

// MARK: - Carte principale (identique PointsAttributed dans sa structure)

struct CommerceStatsSocialNetworkCard: View {
    @Environment(\.commerceStatsGlassOverlay) private var g

    let row: CommerceCategoryRowData
    let detail: CommerceSocialFollowsDetail
    var showsInlineInfo: Bool = true

    @State private var showInfoSheet = false

    private var lc: Color { SocialNetworkPalette.lineColor(for: detail.networkId) }
    private var netLabel: String { SocialNetworkPalette.label(for: detail.networkId) }

    var body: some View {
        Group {
            if showsInlineInfo {
                mainStack
                    .alert(netLabel, isPresented: $showInfoSheet) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text(SocialNetworkPalette.infoMessage(for: detail.networkId))
                    }
            } else {
                mainStack
            }
        }
    }

    private var mainStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
                .padding(.bottom, 12)

            valueTrendBlock
                .padding(.bottom, 6)

            Text("Abonnés gagnés sur la période")
                .font(CommerceStatisticsTheme.statsText(size: 11, weight: .medium))
                .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.9))
                .padding(.bottom, 14)

            chartBlock
        }
        .padding(.top, 16)
        .padding(.bottom, 14)
        .padding(.leading, 18)
        .padding(.trailing, 16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // — Identique à PointsAttributedCard.headerRow mais avec logo réseau —
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                SocialNetworkLogo(networkId: detail.networkId, size: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(netLabel)
                        .font(CommerceStatisticsTheme.kpiTileTitleFont())
                        .foregroundStyle(CommerceStatisticsTheme.kpiTileTitleGradient(forGlassOverlay: g))
                    Text(row.subtitle)
                        .font(CommerceStatisticsTheme.statsText(size: 13, weight: .medium))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g))
                }
            }
            Spacer(minLength: 8)
            if showsInlineInfo {
                Button { showInfoSheet = true } label: {
                    Image(systemName: "info.circle")
                        .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                        .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Informations sur \(netLabel)")
            }
        }
    }

    // — Identique à PointsAttributedCard.valueTrendBlock —
    @ViewBuilder
    private var valueTrendBlock: some View {
        let raw = row.rightPrimary
        let primary = raw.hasPrefix("+") ? String(raw.dropFirst()) : raw
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(primary)
                .font(CommerceStatisticsTheme.statisticNumbers(size: 30, weight: .bold))
                .foregroundStyle(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let t = detail.trendPct {
                let sign = t >= 0 ? "+" : "−"
                Text("\(sign)\(String(format: "%.1f%%", abs(t)))")
                    .font(CommerceStatisticsTheme.statisticNumbers(size: 16, weight: .semibold))
                    .foregroundStyle(CommerceStatisticsTheme.kpiTrendPositiveGreen)
                    .padding(.leading, 10)
            }
            Spacer(minLength: 0)
        }
    }

    // — Identique à PointsAttributedCard.chartBlock —
    private var chartBlock: some View {
        let values = detail.sparkline
        let peakIdx = values.enumerated().max(by: { $0.element < $1.element })?.offset ?? max(0, values.count - 1)
        let areaColors = SocialNetworkPalette.areaColors(for: detail.networkId)

        return ZStack(alignment: .topLeading) {
            SocialNetworkDotGrid()
            referenceLines(peakFrac: peakFraction(index: peakIdx, count: values.count))
            ZStack(alignment: .bottomLeading) {
                SocialAreaShape(values: values)
                    .fill(LinearGradient(colors: areaColors, startPoint: .top, endPoint: .bottom))
                SocialLineShape(values: values)
                    .stroke(lc.opacity(0.22), lineWidth: 3)
                SocialLineShape(values: values)
                    .stroke(lc, lineWidth: 2.1)
            }
            if !values.isEmpty {
                peakMarker(values: values, index: peakIdx)
            }
        }
        .drawingGroup(opaque: false, colorMode: .nonLinear)
        .frame(height: 100)
        .clipped()
    }

    private func peakFraction(index: Int, count: Int) -> CGFloat {
        guard count > 1 else { return 0.5 }
        return CGFloat(index) / CGFloat(max(1, count - 1))
    }

    @ViewBuilder
    private func referenceLines(peakFrac: CGFloat) -> some View {
        let secondary = CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g)
        GeometryReader { proxy in
            let w = proxy.size.width; let h = proxy.size.height
            Path { p in p.move(to: CGPoint(x: 0, y: h * 0.24)); p.addLine(to: CGPoint(x: w, y: h * 0.24)) }
                .stroke(secondary.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            Path { p in let x = peakFrac * w; p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: h)) }
                .stroke(secondary.opacity(0.20), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
        .allowsHitTesting(false)
    }

    private func peakMarker(values: [CGFloat], index: Int) -> some View {
        GeometryReader { proxy in
            let w = max(1, proxy.size.width); let h = max(1, proxy.size.height)
            let topPad: CGFloat = 6; let bottomPad: CGFloat = 8
            let usableH = max(1, h - topPad - bottomPad)
            let v = min(1, max(0, values[min(index, values.count - 1)]))
            let x = CGFloat(index) / CGFloat(max(1, values.count - 1)) * w
            let y = topPad + usableH - v * usableH * 0.92
            ZStack {
                Circle().fill(CommerceStatisticsTheme.onCardPrimary(forGlassOverlay: g).opacity(0.96)).frame(width: 9, height: 9)
                Circle().strokeBorder(lc, lineWidth: 2).frame(width: 9, height: 9)
            }
            .position(x: x, y: y)
        }
    }
}

// MARK: - Ligne bouton avec i séparé (même pattern que PointsAttributedListButtonRow)

struct CommerceStatsSocialNetworkListButtonRow: View {
    @Environment(\.commerceStatsGlassOverlay) private var g

    let row: CommerceCategoryRowData
    let detail: CommerceSocialFollowsDetail
    let onRowTap: () -> Void

    @State private var showInfo = false
    private var netLabel: String { SocialNetworkPalette.label(for: detail.networkId) }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button { onRowTap() } label: {
                CommerceStatsSocialNetworkCard(row: row, detail: detail, showsInlineInfo: false)
            }
            Button { showInfo = true } label: {
                Image(systemName: "info.circle")
                    .font(CommerceStatisticsTheme.statsText(size: 17, weight: .regular))
                    .foregroundStyle(CommerceStatisticsTheme.onCardSecondary(forGlassOverlay: g).opacity(0.85))
            }
            .buttonStyle(.borderless)
            .padding(.trailing, 20)
            .padding(.top, 16)
            .zIndex(2)
        }
        .alert(netLabel, isPresented: $showInfo) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(SocialNetworkPalette.infoMessage(for: detail.networkId))
        }
    }
}

// MARK: - Grille de points (identique PointsAttributed)

private struct SocialNetworkDotGrid: View {
    private let cols = 24; private let rows = 6
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width; let h = proxy.size.height
            let stepX = w / CGFloat(max(1, cols - 1))
            let stepY = h / CGFloat(max(1, rows - 1))
            let dot = Color.white.opacity(0.1)
            ForEach(0..<rows, id: \.self) { r in
                ForEach(0..<cols, id: \.self) { c in
                    Circle().fill(dot).frame(width: 1.2, height: 1.2)
                        .position(x: CGFloat(c) * stepX, y: CGFloat(r) * stepY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
