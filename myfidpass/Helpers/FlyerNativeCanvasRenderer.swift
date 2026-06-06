//
//  FlyerNativeCanvasRenderer.swift
//  myfidpass
//
//  Rendu natif CoreGraphics du flyer (roue, QR, textes) — aligné sur le canvas SaaS fidelity.
//

import UIKit

struct FlyerNativeRenderRequest: Equatable {
    var state: FlyerStateDTO
    var shareURL: String
    var logoImage: UIImage?
    var underlayImage: UIImage?
    var canvasSize: CGSize
    /// Si `true`, ne dessine que le calque transparent (roue/QR/texte) — fond via underlay séparé.
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

    /// Composite complet (fond + calque flyer) — export partage / aperçu.
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
                    drawImageCover(underlay, in: CGRect(origin: .zero, size: size))
                    drawUnderlayGradients(in: cg, state: request.state, size: size)
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

    // MARK: - Image helpers (respecte UIImage.imageOrientation — évite le miroir)

    private static func drawUIImage(_ image: UIImage, in rect: CGRect) {
        image.draw(in: rect)
    }

    private static func drawImageContain(_ image: UIImage, in target: CGRect) {
        let sw = image.size.width
        let sh = image.size.height
        guard sw > 0, sh > 0 else { return }
        let scale = min(target.width / sw, target.height / sh)
        let dw = sw * scale
        let dh = sh * scale
        let rect = CGRect(
            x: target.midX - dw / 2,
            y: target.midY - dh / 2,
            width: dw,
            height: dh
        )
        drawUIImage(image, in: rect)
    }

    private static func drawImageCover(_ image: UIImage, in target: CGRect) {
        let sw = image.size.width
        let sh = image.size.height
        guard sw > 0, sh > 0 else { return }
        let scale = max(target.width / sw, target.height / sh)
        let dw = sw * scale
        let dh = sh * scale
        let rect = CGRect(
            x: target.midX - dw / 2,
            y: target.midY - dh / 2,
            width: dw,
            height: dh
        )
        drawUIImage(image, in: rect)
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

    /// Voile optionnel sur photo de fond — aligné `drawFlyerBackgroundLayer` (fidelity) : `flyerBgOverlayPct` 0 = photo brute.
    private static func drawUnderlayGradients(in ctx: CGContext, state: FlyerStateDTO, size: CGSize) {
        let pct = max(0, min(90, state.flyerBgOverlayPct))
        guard pct > 0 else { return }

        let t = (pct / 100) * 0.88
        let b = (pct / 100) * 0.95
        let top = UIColor.flyerHex(state.colorBgTop).withAlphaComponent(CGFloat(t))
        let bottom = UIColor.flyerHex(state.colorBgBottom).withAlphaComponent(CGFloat(b))
        let space = CGColorSpaceCreateDeviceRGB()
        let colors = [top.cgColor, bottom.cgColor] as CFArray
        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) else { return }
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
        guard let logo else { return }
        let layout = metrics.logoLayout(from: state)
        let maxW = metrics.canvasWidth * layout.maxW
        let maxH = metrics.canvasHeight * layout.maxH
        let sw = logo.size.width
        let sh = logo.size.height
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
        ctx.setShadow(
            offset: CGSize(width: 0, height: metrics.designScale * 4),
            blur: metrics.designScale * 8,
            color: UIColor.black.withAlphaComponent(0.25).cgColor
        )
        drawUIImage(logo, in: rect)
        ctx.restoreGState()
    }

    // MARK: - Wheel

    private static func drawWheelStack(_ ctx: CGContext, state: FlyerStateDTO, metrics: FlyerLayoutMetrics) {
        let cx = metrics.wheelCenterX
        let cy = metrics.wheelCenterY
        let spinnerR = metrics.spinnerRadius

        if let flyergame = UIImage(named: "flyergame") {
            let fitBox = spinnerR * 2.35
            let rect = CGRect(x: cx - fitBox / 2, y: cy - fitBox / 2, width: fitBox, height: fitBox)
            drawImageContain(flyergame, in: rect)
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
        guard let gift = UIImage(named: "giftflyer") else { return }
        let sw = gift.size.width
        let sh = gift.size.height
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
        drawUIImage(gift, in: rect)
    }

    // MARK: - Headline (mot CADEAU en couleur pastille)

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
        let giftStroke = UIColor.flyerHex(state.headlineGiftStrokeColor, fallback: "#be185d")
        let ctaPink = UIColor.flyerHex(state.ctaBannerBgColor, fallback: "#ff4f78")
        let strokeW = max(1.2, metrics.designScale * min(48, max(0, state.headlineStrokeWidth)))

        for (index, line) in lines.enumerated() {
            let y = blockTop + lineH * 0.5 + CGFloat(index) * lineH
            drawHeadlineLine(
                ctx,
                line: line,
                centerY: y,
                canvasWidth: metrics.canvasWidth,
                font: font,
                lineH: lineH,
                fill: fill,
                stroke: stroke,
                giftFill: ctaPink,
                giftStroke: giftStroke,
                strokeWidth: strokeW
            )
        }
    }

    private static func drawHeadlineLine(
        _ ctx: CGContext,
        line: String,
        centerY: CGFloat,
        canvasWidth: CGFloat,
        font: UIFont,
        lineH: CGFloat,
        fill: UIColor,
        stroke: UIColor,
        giftFill: UIColor,
        giftStroke: UIColor,
        strokeWidth: CGFloat
    ) {
        let pattern = #"CADEAU(?:\s*!+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line))
        else {
            drawOutlinedText(
                ctx,
                text: line,
                center: CGPoint(x: canvasWidth / 2, y: centerY),
                font: font,
                fill: fill,
                stroke: stroke,
                strokeWidth: strokeWidth
            )
            return
        }

        let tokenRange = Range(match.range, in: line)!
        let token = String(line[tokenRange])
        let before = String(line[..<tokenRange.lowerBound])
        let after = String(line[tokenRange.upperBound...])

        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let totalW = (line as NSString).size(withAttributes: attrs).width
        let startX = canvasWidth / 2 - totalW / 2
        let beforeW = (before as NSString).size(withAttributes: attrs).width
        let tokenW = (token as NSString).size(withAttributes: attrs).width
        let afterW = (after as NSString).size(withAttributes: attrs).width

        func drawPart(
            _ txt: String,
            centerX: CGFloat,
            fillColor: UIColor,
            tiltDeg: CGFloat = 0,
            yOffset: CGFloat = 0,
            customStroke: UIColor? = nil
        ) {
            guard !txt.isEmpty else { return }
            ctx.saveGState()
            ctx.translateBy(x: centerX, y: centerY + yOffset)
            if tiltDeg != 0 { ctx.rotate(by: tiltDeg * .pi / 180) }
            drawOutlinedText(
                ctx,
                text: txt,
                center: .zero,
                font: font,
                fill: fillColor,
                stroke: customStroke ?? stroke,
                strokeWidth: strokeWidth,
                shadowDrop: max(1, strokeWidth * 0.32)
            )
            ctx.restoreGState()
        }

        if !before.isEmpty {
            if let votreRegex = try? NSRegularExpression(pattern: #"(.*?)(\bVOTRE\s*)$"#, options: [.caseInsensitive]),
               let vm = votreRegex.firstMatch(in: before, range: NSRange(before.startIndex..., in: before)),
               vm.numberOfRanges >= 3,
               let preRange = Range(vm.range(at: 1), in: before),
               let votreRange = Range(vm.range(at: 2), in: before) {
                let pre = String(before[preRange])
                let votreToken = String(before[votreRange])
                if !pre.isEmpty {
                    let preW = (pre as NSString).size(withAttributes: attrs).width
                    drawPart(pre, centerX: startX + preW / 2, fillColor: fill)
                }
                if !votreToken.isEmpty {
                    let preW = (pre as NSString).size(withAttributes: attrs).width
                    let votreW = (votreToken as NSString).size(withAttributes: attrs).width
                    drawPart(votreToken, centerX: startX + preW + votreW / 2, fillColor: fill, tiltDeg: -4)
                }
            } else {
                drawPart(before, centerX: startX + beforeW / 2, fillColor: fill)
            }
        }

        let giftDrop = lineH * 0.15
        drawPart(token, centerX: startX + beforeW + tokenW / 2, fillColor: giftFill, tiltDeg: 8, yOffset: giftDrop, customStroke: giftStroke)

        if !after.isEmpty {
            drawPart(after, centerX: startX + beforeW + tokenW + afterW / 2, fillColor: fill)
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
        strokeWidth: CGFloat,
        shadowDrop: CGFloat = 0
    ) {
        let size = (text as NSString).size(withAttributes: [.font: font])
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)

        if shadowDrop > 0 {
            let shadowAttrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.black.withAlphaComponent(0.2),
            ]
            (text as NSString).draw(at: CGPoint(x: origin.x, y: origin.y + shadowDrop), withAttributes: shadowAttrs)
        }

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
        (text as NSString).draw(at: origin, withAttributes: attrsStrokeOuter)
        (text as NSString).draw(at: origin, withAttributes: attrsStroke)
        (text as NSString).draw(at: origin, withAttributes: attrsFill)
    }

    /// Contours noirs nets et épais pour « Propulsé par Myfidpass ».
    private static func drawPoweredByOutlinedText(
        text: String,
        at point: CGPoint,
        font: UIFont,
        strokeW: CGFloat
    ) {
        let px = round(point.x)
        let py = round(point.y)
        let wHalo = max(4, strokeW * 2.45)
        let wOuter = max(3.5, strokeW * 2.05)
        let wInner = max(2.5, strokeW * 1.25)

        let halo: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.72),
            .strokeColor: UIColor.black.withAlphaComponent(0.72),
            .strokeWidth: -wHalo,
        ]
        let outer: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black.withAlphaComponent(0.55),
            .strokeColor: UIColor.black.withAlphaComponent(0.55),
            .strokeWidth: -wOuter,
        ]
        let inner: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black,
            .strokeColor: UIColor.black,
            .strokeWidth: -wInner,
        ]
        let fill: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white,
        ]
        let size = (text as NSString).size(withAttributes: fill)
        let origin = CGPoint(x: px, y: py - size.height / 2)
        (text as NSString).draw(at: origin, withAttributes: halo)
        (text as NSString).draw(at: origin, withAttributes: outer)
        (text as NSString).draw(at: origin, withAttributes: inner)
        (text as NSString).draw(at: origin, withAttributes: fill)
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

        if let qr = QRCodeGenerator.generateQR(from: trimmed, size: inner) {
            let qrRect = CGRect(x: qx + pad, y: qy + pad, width: inner, height: inner)
            ctx.interpolationQuality = .none
            drawUIImage(qr, in: qrRect)
        }
        ctx.restoreGState()
    }

    // MARK: - Footer (bandeau + badge Myfidpass)

    private static func drawFooter(_ ctx: CGContext, state: FlyerStateDTO, metrics: FlyerLayoutMetrics) {
        let bottomY = metrics.printSafeBottomY

        if let banner = UIImage(named: "FlyerFooterBanner") {
            let maxH = metrics.footerBannerMaxHeight
            let bleed = max(2, round(metrics.canvasWidth * 0.003))
            let yTop = bottomY - maxH
            let target = CGRect(x: -bleed, y: yTop, width: metrics.canvasWidth + bleed * 2, height: maxH)
            drawImageCover(banner, in: target)
        } else {
            // Sans bandeau PNG : repli textes étapes (comme le SaaS).
            drawFooterSteps(ctx, state: state, metrics: metrics, bottomY: bottomY)
        }

        drawPoweredByBadge(ctx, metrics: metrics, bottomY: bottomY)
    }

    private static func drawFooterSteps(
        _ ctx: CGContext,
        state: FlyerStateDTO,
        metrics: FlyerLayoutMetrics,
        bottomY: CGFloat
    ) {
        let fh = metrics.footerStepsHeight
        let y0 = max(0, bottomY - fh)
        let fsc = min(1.35, max(0.7, state.flyerFooterTextScalePct / 100))
        let fg = UIColor.white
        let steps = [state.step1, state.step2, state.step3]
        let nums = ["1", "2", "3"]
        let cw = metrics.canvasWidth / 3
        let pad = cw * 0.035

        for i in 0..<3 {
            let x0 = CGFloat(i) * cw
            let iconW = cw * 0.38
            let iconH = fh * 0.52
            let iconRowCy = y0 + fh * 0.34
            let iconX = x0 + pad
            let iconY = iconRowCy - iconH / 2

            if i == 2 {
                drawFooterStepVectorStar(ctx, x: iconX, y: iconY, w: iconW, h: iconH, fg: fg)
            }

            let numSize = round(fh * 0.38 * fsc)
            let numFont = UIFont.systemFont(ofSize: numSize, weight: .bold)
            let numX = iconX + iconW + cw * 0.025
            let numAttrs: [NSAttributedString.Key: Any] = [.font: numFont, .foregroundColor: fg]
            let numSize2 = ("\(nums[i])" as NSString).size(withAttributes: numAttrs)
            ("\(nums[i])" as NSString).draw(
                at: CGPoint(x: numX, y: iconRowCy - numSize2.height / 2),
                withAttributes: numAttrs
            )

            let cx = x0 + cw / 2
            let stepFont = UIFont.systemFont(ofSize: round(fh * 0.09 * fsc), weight: .semibold)
            let lineH = round(fh * 0.095 * fsc)
            let lines = wrapHeadline(steps[i], font: stepFont, maxWidth: cw * 0.85)
            let startY = y0 + fh * 0.78 - CGFloat(max(0, lines.prefix(2).count - 1)) * lineH / 2
            var lineY = startY
            for line in lines.prefix(2) {
                let attrs: [NSAttributedString.Key: Any] = [.font: stepFont, .foregroundColor: fg]
                let size = (line as NSString).size(withAttributes: attrs)
                (line as NSString).draw(at: CGPoint(x: cx - size.width / 2, y: lineY), withAttributes: attrs)
                lineY += lineH
            }
        }
    }

    private static func drawFooterStepVectorStar(
        _ ctx: CGContext,
        x: CGFloat,
        y: CGFloat,
        w: CGFloat,
        h: CGFloat,
        fg: UIColor
    ) {
        let cx = x + w / 2
        let cy = y + h / 2
        let outer = min(w, h) * 0.46
        let inner = outer * 0.42
        let path = CGMutablePath()
        for i in 0..<8 {
            let a = (CGFloat(i) * .pi / 4) - .pi / 2
            let r = i.isMultiple(of: 2) ? outer : inner
            let px = cx + cos(a) * r
            let py = cy + sin(a) * r
            if i == 0 { path.move(to: CGPoint(x: px, y: py)) }
            else { path.addLine(to: CGPoint(x: px, y: py)) }
        }
        path.closeSubpath()
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let colors = [UIColor(red: 1, green: 0.99, blue: 0.91, alpha: 1).cgColor, fg.cgColor, UIColor(red: 0.58, green: 0.64, blue: 0.69, alpha: 1).cgColor] as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.45, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: cx, y: cy - outer * 0.2), end: CGPoint(x: cx, y: cy + outer), options: [])
        }
        ctx.resetClip()
        ctx.setStrokeColor(UIColor.black.withAlphaComponent(0.28).cgColor)
        ctx.setLineWidth(max(1.2, outer * 0.06))
        ctx.addPath(path)
        ctx.strokePath()
        ctx.restoreGState()
    }

    private static func drawPoweredByBadge(_ ctx: CGContext, metrics: FlyerLayoutMetrics, bottomY: CGFloat) {
        let ds = metrics.designScale
        let fontPx = max(30, round(50 * ds))
        let gap = max(10 * ds, metrics.canvasWidth * 0.01)
        let iconH = max(36, round(62 * ds))
        let bannerMaxH = metrics.footerBannerMaxHeight
        let bottomPad = max(2 * ds, metrics.canvasHeight * 0.0012)
        let liftFromBottom = max(bottomPad + fontPx * 0.12, bannerMaxH * 0.012)
        let yMid = round(bottomY - liftFromBottom)

        let label = "Propulsé par "
        let brand = "Myfidpass"
        let labelFont = UIFont.systemFont(ofSize: fontPx, weight: .semibold)
        let brandFont = UIFont.systemFont(ofSize: fontPx, weight: .heavy)
        let labelW = (label as NSString).size(withAttributes: [.font: labelFont]).width
        let brandW = (brand as NSString).size(withAttributes: [.font: brandFont]).width

        var imgW: CGFloat = 0
        if let icon = UIImage(named: "FlyerMyfidpassIcon") {
            let iw = icon.size.width
            let ih = icon.size.height
            if ih > 0 {
                imgW = iconH * (iw / ih)
            }
        }
        let totalW = (imgW > 0 ? imgW + gap : 0) + labelW + brandW
        var x = round((metrics.canvasWidth - totalW) / 2)
        let strokeW = max(3.5, round(8 * ds))

        if imgW > 0, let icon = UIImage(named: "FlyerMyfidpassIcon") {
            let ix = round(x)
            let iy = round(yMid - iconH / 2)
            let iw = round(imgW)
            let ih = round(iconH)
            ctx.saveGState()
            ctx.setShadow(
                offset: CGSize(width: max(1, round(2.2 * ds)), height: max(1, round(2.2 * ds))),
                blur: 0,
                color: UIColor.black.withAlphaComponent(0.72).cgColor
            )
            drawUIImage(icon, in: CGRect(x: ix, y: iy, width: iw, height: ih))
            ctx.restoreGState()
            drawUIImage(icon, in: CGRect(x: ix, y: iy, width: iw, height: ih))
            x += iw + gap
        }

        drawPoweredByOutlinedText(text: label, at: CGPoint(x: x, y: yMid), font: labelFont, strokeW: strokeW)
        x += labelW
        drawPoweredByOutlinedText(text: brand, at: CGPoint(x: x, y: yMid), font: brandFont, strokeW: strokeW)
    }
}
