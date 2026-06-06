//
//  FlyerNativeCanvasRenderer.swift
//  myfidpass
//
//  Rendu natif CoreGraphics du flyer (roue, QR, textes) — remplace le canvas JS embarqué.
//

import UIKit

struct FlyerNativeRenderRequest: Equatable {
    var state: FlyerStateDTO
    var shareURL: String
    var logoImage: UIImage?
    var underlayImage: UIImage?
    var canvasSize: CGSize
    /// Si `true`, ne dessine que le calque transparent (roue/QR/texte) — fond via `FlyerNativeUnderlayStack`.
    var overlayOnly: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.state == rhs.state
            && lhs.shareURL == rhs.shareURL
            && lhs.canvasSize == rhs.canvasSize
            && lhs.overlayOnly == rhs.overlayOnly
            && lhs.logoImage === rhs.logoImage
            && lhs.underlayImage === rhs.underlayImage
    }
}

enum FlyerNativeCanvasRenderer {

    /// Composite complet (fond + calque flyer) — export partage / cache raster.
    static func renderFullComposite(_ request: FlyerNativeRenderRequest, scale: CGFloat) -> UIImage? {
        var full = request
        full.overlayOnly = false
        return render(full, scale: scale)
    }

    /// Calque transparent (roue, QR, textes) pour superposition sur underlay SwiftUI.
    static func renderOverlay(_ request: FlyerNativeRenderRequest, scale: CGFloat) -> UIImage? {
        var overlay = request
        overlay.overlayOnly = true
        return render(overlay, scale: scale)
    }

    static func render(_ request: FlyerNativeRenderRequest, scale: CGFloat) -> UIImage? {
        let size = request.canvasSize
        guard size.width > 1, size.height > 1 else { return nil }
        let metrics = FlyerLayoutMetrics(canvasSize: size)

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = !request.overlayOnly

        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            if !request.overlayOnly {
                if let underlay = request.underlayImage {
                    underlay.draw(in: CGRect(origin: .zero, size: size))
                } else {
                    drawFallbackBackground(in: cg, state: request.state, size: size)
                }
            }

            drawCommerceLogo(cg, state: request.state, logo: request.logoImage, metrics: metrics)
            drawWheelStack(cg, state: request.state, metrics: metrics)
            drawGiftPromo(cg, metrics: metrics)
            drawHeadline(cg, state: request.state, metrics: metrics, hasLogo: request.logoImage != nil)
            drawCTAPill(cg, state: request.state, metrics: metrics)
            drawQRCode(cg, url: request.shareURL, metrics: metrics)
            drawFooter(cg, state: request.state, metrics: metrics)
        }
    }

    // MARK: - Background

    private static func drawFallbackBackground(in ctx: CGContext, state: FlyerStateDTO, size: CGSize) {
        let top = UIColor.flyerHex(state.colorBgTop)
        let bottom = UIColor.flyerHex(state.colorBgBottom)
        let colors = [top.cgColor, UIColor.flyerHex(state.colorPrimary).cgColor, bottom.cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) else { return }
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: size.width / 2, y: 0),
            end: CGPoint(x: size.width / 2, y: size.height),
            options: []
        )
    }

    // MARK: - Logo

    private static func drawCommerceLogo(
        _ ctx: CGContext,
        state: FlyerStateDTO,
        logo: UIImage?,
        metrics: FlyerLayoutMetrics
    ) {
        guard let logo, let cg = logo.cgImage else { return }
        let layout = metrics.logoLayout(from: state)
        let maxW = metrics.canvasWidth * layout.maxW
        let maxH = metrics.canvasHeight * layout.maxH
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        guard sw > 0, sh > 0 else { return }
        let scale = min(maxW / sw, maxH / sh)
        let dw = sw * scale
        let dh = sh * scale
        let rect = CGRect(
            x: (metrics.canvasWidth - dw) / 2,
            y: metrics.canvasHeight * layout.centerY - dh / 2,
            width: dw,
            height: dh
        )
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: metrics.designScale * 4), blur: metrics.designScale * 8, color: UIColor.black.withAlphaComponent(0.25).cgColor)
        ctx.draw(cg, in: rect)
        ctx.restoreGState()
    }

    // MARK: - Wheel

    private static func drawWheelStack(_ ctx: CGContext, state: FlyerStateDTO, metrics: FlyerLayoutMetrics) {
        let cx = metrics.wheelCenterX
        let cy = metrics.wheelCenterY
        let spinnerR = metrics.spinnerRadius

        if let flyergame = UIImage(named: "flyergame"), let cg = flyergame.cgImage {
            let fitBox = spinnerR * 2.35
            let sw = CGFloat(cg.width)
            let sh = CGFloat(cg.height)
            let s = max(fitBox / sw, fitBox / sh)
            let dw = sw * s
            let dh = sh * s
            let rect = CGRect(x: cx - dw / 2, y: cy - dh / 2, width: dw, height: dh)
            ctx.draw(cg, in: rect)
        }

        let colors = FlyerWheelGeometry.normalizedSegmentColors(from: state)
        ctx.saveGState()
        ctx.setBlendMode(.sourceAtop)
        ctx.setAlpha(0.62)
        drawWheelSegments(ctx, cx: cx, cy: cy, radius: spinnerR, colors: colors, offsetDeg: state.wheelSegmentOffsetDeg)
        ctx.restoreGState()

        drawWheelLabels(ctx, cx: cx, cy: cy, radius: spinnerR, state: state, colors: colors)
    }

    private static func drawWheelSegments(
        _ ctx: CGContext,
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        colors: [UIColor],
        offsetDeg: Double
    ) {
        for i in 0..<FlyerWheelGeometry.segmentCount {
            let angles = FlyerWheelGeometry.segmentAngles(index: i, offsetDeg: offsetDeg)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cx, y: cy))
            path.addArc(center: CGPoint(x: cx, y: cy), radius: radius, startAngle: angles.start, endAngle: angles.end, clockwise: false)
            path.closeSubpath()
            ctx.setFillColor(colors[i].cgColor)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }

    private static func drawWheelLabels(
        _ ctx: CGContext,
        cx: CGFloat,
        cy: CGFloat,
        radius: CGFloat,
        state: FlyerStateDTO,
        colors: [UIColor]
    ) {
        let wl = state.flyerWheelLabelScalePct
        let wsc = min(1.35, max(0.7, wl / 100))
        let fontPx = max(11, radius * 0.104 * wsc)
        let labelR = radius * 0.5
        let font = UIFont.systemFont(ofSize: fontPx, weight: .heavy)

        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: cx - radius * 0.82, y: cy - radius * 0.82, width: radius * 1.64, height: radius * 1.64))
        ctx.clip()

        for i in 0..<FlyerWheelGeometry.segmentCount {
            let angles = FlyerWheelGeometry.segmentAngles(index: i, offsetDeg: state.wheelSegmentOffsetDeg)
            let mid = (angles.start + angles.end) / 2
            let tx = cx + cos(mid) * labelR
            let ty = cy + sin(mid) * labelR
            let label = i.isMultiple(of: 2) ? "GAGNÉ !" : "PERDU !"
            let fill = colors[i].relativeLuminance() > 0.62 ? UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1) : .white

            ctx.saveGState()
            ctx.translateBy(x: tx, y: ty)
            var rot = mid
            if sin(mid) > 0 { rot += .pi }
            ctx.rotate(by: rot)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: fill,
            ]
            let size = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    // MARK: - Gift promo

    private static func drawGiftPromo(_ ctx: CGContext, metrics: FlyerLayoutMetrics) {
        guard let gift = UIImage(named: "giftflyer"), let cg = gift.cgImage else { return }
        let sw = CGFloat(cg.width)
        let sh = CGFloat(cg.height)
        guard sw > 0, sh > 0 else { return }
        let giftW = metrics.canvasWidth * 0.48
        let giftH = giftW * sh / sw
        let lead = max(8 * metrics.designScale, metrics.canvasWidth * 0.02)
        let bottomPad = max(4 * metrics.designScale, metrics.canvasHeight * 0.01)
        let lift = max(126 * metrics.designScale, metrics.canvasHeight * 0.19)
        let rect = CGRect(
            x: lead,
            y: metrics.canvasHeight - bottomPad - giftH - lift,
            width: giftW,
            height: giftH
        )
        ctx.draw(cg, in: rect)
    }

    // MARK: - Headline

    private static func drawHeadline(
        _ ctx: CGContext,
        state: FlyerStateDTO,
        metrics: FlyerLayoutMetrics,
        hasLogo: Bool
    ) {
        let text = state.headline.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let sizePct = min(18, max(5, state.headlineSizePct))
        let fontSize = round(metrics.canvasWidth * (sizePct / 100) * 1.1)
        let lineH = round(fontSize * 1.02)
        let font = UIFont.systemFont(ofSize: fontSize, weight: .black)
        let maxW = metrics.canvasWidth * 0.92
        let lines = wrapHeadline(text.uppercased(), font: font, maxWidth: maxW).prefix(3)

        let gapFrac = min(28, max(0, state.headlineLogoGapPct)) / 100
        let blockTop = metrics.canvasHeight * metrics.logoBlockBottomFrac(hasLogo: hasLogo, state: state)
            + metrics.canvasHeight * gapFrac
        let fill = UIColor.flyerHex(state.headlineTextColor, fallback: "#ffffff")
        let stroke = UIColor.flyerHex(state.headlineStrokeColor, fallback: "#0B1020")
        let strokeW = max(1.2, metrics.designScale * min(48, max(0, state.headlineStrokeWidth)))

        for (index, line) in lines.enumerated() {
            let y = blockTop + lineH * 0.5 + CGFloat(index) * lineH
            drawOutlinedText(
                ctx,
                text: line,
                center: CGPoint(x: metrics.canvasWidth / 2, y: y),
                font: font,
                fill: fill,
                stroke: stroke,
                strokeWidth: strokeW
            )
        }
    }

    private static func wrapHeadline(_ text: String, font: UIFont, maxWidth: CGFloat) -> [String] {
        let words = text.split(separator: " ").map(String.init)
        var lines: [String] = []
        var current = ""
        for word in words {
            let next = current.isEmpty ? word : "\(current) \(word)"
            if (next as NSString).size(withAttributes: [.font: font]).width <= maxWidth {
                current = next
            } else {
                if !current.isEmpty { lines.append(current) }
                current = word
            }
        }
        if !current.isEmpty { lines.append(current) }
        return lines
    }

    private static func drawOutlinedText(
        _ ctx: CGContext,
        text: String,
        center: CGPoint,
        font: UIFont,
        fill: UIColor,
        stroke: UIColor,
        strokeWidth: CGFloat
    ) {
        let attrsStrokeOuter: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.42),
            .strokeColor: UIColor.black.withAlphaComponent(0.42),
            .strokeWidth: -strokeWidth * 1.9,
        ]
        let attrsStroke: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: stroke,
            .strokeColor: stroke,
            .strokeWidth: -strokeWidth * 1.15,
        ]
        let attrsFill: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: fill,
        ]
        let size = (text as NSString).size(withAttributes: attrsFill)
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: attrsStrokeOuter)
        (text as NSString).draw(at: origin, withAttributes: attrsStroke)
        (text as NSString).draw(at: origin, withAttributes: attrsFill)
    }

    // MARK: - CTA pill

    private static func drawCTAPill(_ ctx: CGContext, state: FlyerStateDTO, metrics: FlyerLayoutMetrics) {
        let raw = state.ctaBanner.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        let parts = raw.split(separator: " ").map(String.init)
        let line1 = parts.first?.uppercased() ?? ""
        let line2 = parts.count > 1 ? parts.dropFirst().joined(separator: " ").uppercased() : ""
        guard !line1.isEmpty else { return }

        let ds = metrics.designScale
        let padX = 44 * ds
        let padY = 28 * ds
        let fontBig = round(min(132 * ds, max(78 * ds, metrics.qrSize * 0.31)))
        let fontSmall = line2.isEmpty ? fontBig : round(fontBig * 0.58)
        let fontBigUI = UIFont.systemFont(ofSize: fontBig, weight: .heavy)
        let fontSmallUI = UIFont.systemFont(ofSize: fontSmall, weight: .bold)

        let w1 = (line1 as NSString).size(withAttributes: [.font: fontBigUI]).width
        let w2 = line2.isEmpty ? 0 : (line2 as NSString).size(withAttributes: [.font: fontSmallUI]).width
        let pillW = max(w1, w2) + padX * 2
        let row1H = fontBig * 1.08
        let row2H = line2.isEmpty ? 0 : fontSmall * 1.1
        let pillH = padY * 2 + row1H + (line2.isEmpty ? 0 : 8 * ds + row2H)

        var pillLeft = metrics.qrOriginX - (-18 * ds) - pillW
        let pillTop = metrics.qrOriginY + metrics.qrSize * 0.7 - pillH / 2
        pillLeft = max(10 * ds, pillLeft)
        let rect = CGRect(x: pillLeft, y: pillTop, width: pillW, height: pillH)
        let rr = min(32 * ds, pillH / 2)

        let fill = UIColor.flyerHex(state.ctaBannerBgColor, fallback: "#ec4899")
        let textFill = UIColor.flyerHex(state.ctaTextColor, fallback: "#ffffff")

        let path = UIBezierPath(roundedRect: rect, cornerRadius: rr)
        ctx.setFillColor(fill.cgColor)
        ctx.addPath(path.cgPath)
        ctx.fillPath()
        ctx.setStrokeColor(UIColor.black.cgColor)
        ctx.setLineWidth(max(4, 8 * ds))
        ctx.addPath(path.cgPath)
        ctx.strokePath()

        let cx = rect.midX
        var cy = rect.minY + padY + row1H / 2
        drawOutlinedText(ctx, text: line1, center: CGPoint(x: cx, y: cy), font: fontBigUI, fill: textFill, stroke: .black, strokeWidth: max(1.5, 2.8 * ds))
        if !line2.isEmpty {
            cy = rect.minY + padY + row1H + 8 * ds + row2H / 2
            drawOutlinedText(ctx, text: line2, center: CGPoint(x: cx, y: cy), font: fontSmallUI, fill: textFill, stroke: .black, strokeWidth: max(1.5, 2.8 * ds))
        }
    }

    // MARK: - QR

    private static func drawQRCode(_ ctx: CGContext, url: String, metrics: FlyerLayoutMetrics) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let qSize = metrics.qrSize
        let qx = metrics.qrOriginX
        let qy = metrics.qrOriginY
        let pad = metrics.qrPadding
        let inner = max(1, round(qSize - 2 * pad))
        let qCx = qx + qSize / 2
        let qCy = qy + qSize / 2
        let tilt = (-6 * CGFloat.pi) / 180

        ctx.saveGState()
        ctx.translateBy(x: qCx, y: qCy)
        ctx.rotate(by: tilt)
        ctx.translateBy(x: -qCx, y: -qCy)

        let bgRect = CGRect(x: qx, y: qy, width: qSize, height: qSize)
        let bgPath = UIBezierPath(roundedRect: bgRect, cornerRadius: metrics.qrCornerRadius)
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addPath(bgPath.cgPath)
        ctx.fillPath()

        if let qr = QRCodeGenerator.generateQR(from: trimmed, size: inner), let cg = qr.cgImage {
            let qrRect = CGRect(x: qx + pad, y: qy + pad, width: inner, height: inner)
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: qrRect)
        }
        ctx.restoreGState()
    }

    // MARK: - Footer

    private static func drawFooter(_ ctx: CGContext, state: FlyerStateDTO, metrics: FlyerLayoutMetrics) {
        let bottomY = metrics.printSafeBottomY
        let fh = metrics.footerStepsHeight
        let y0 = max(0, bottomY - fh)
        let fsc = min(1.35, max(0.7, state.flyerFooterTextScalePct / 100))
        let fg = UIColor.white
        let steps = [state.step1, state.step2, state.step3]
        let icons = ["①", "②", "③"]
        let cw = metrics.canvasWidth / 3

        for i in 0..<3 {
            let cx = cw * CGFloat(i) + cw / 2
            let cy = y0 + fh * 0.5
            let numFont = UIFont.systemFont(ofSize: round(fh * 0.14 * fsc), weight: .bold)
            let stepFont = UIFont.systemFont(ofSize: round(fh * 0.09 * fsc), weight: .semibold)
            let iconAttrs: [NSAttributedString.Key: Any] = [.font: numFont, .foregroundColor: fg]
            let iconSize = (icons[i] as NSString).size(withAttributes: iconAttrs)
            (icons[i] as NSString).draw(
                at: CGPoint(x: cx - iconSize.width / 2, y: cy - fh * 0.12 - iconSize.height / 2),
                withAttributes: iconAttrs
            )
            let lines = wrapHeadline(steps[i], font: stepFont, maxWidth: cw * 0.85)
            var lineY = cy + fh * 0.04
            for line in lines.prefix(2) {
                let attrs: [NSAttributedString.Key: Any] = [.font: stepFont, .foregroundColor: fg]
                let size = (line as NSString).size(withAttributes: attrs)
                (line as NSString).draw(at: CGPoint(x: cx - size.width / 2, y: lineY), withAttributes: attrs)
                lineY += round(fh * 0.085 * fsc)
            }
        }

        drawPoweredByBadge(ctx, metrics: metrics, bottomY: bottomY)
    }

    private static func drawPoweredByBadge(_ ctx: CGContext, metrics: FlyerLayoutMetrics, bottomY: CGFloat) {
        let ds = metrics.designScale
        let fontPx = max(44, round(72 * ds))
        let fontLabel = UIFont.systemFont(ofSize: fontPx, weight: .semibold)
        let fontBrand = UIFont.systemFont(ofSize: fontPx, weight: .heavy)
        let label = "Propulsé par "
        let brand = "Myfidpass"
        let labelW = (label as NSString).size(withAttributes: [.font: fontLabel]).width
        let brandW = (brand as NSString).size(withAttributes: [.font: fontBrand]).width
        let bannerH = metrics.canvasHeight * 0.132
        let lift = max(6 * ds, bannerH * 0.06)
        let yMid = bottomY - lift
        var x = (metrics.canvasWidth - labelW - brandW) / 2
        drawOutlinedText(ctx, text: label, center: CGPoint(x: x + labelW / 2, y: yMid), font: fontLabel, fill: .white, stroke: .black, strokeWidth: max(2.5, 5.5 * ds))
        x += labelW
        drawOutlinedText(ctx, text: brand, center: CGPoint(x: x + brandW / 2, y: yMid), font: fontBrand, fill: .white, stroke: .black, strokeWidth: max(2.5, 5.5 * ds))
    }
}
