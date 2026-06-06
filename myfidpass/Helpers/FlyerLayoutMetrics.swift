//
//  FlyerLayoutMetrics.swift
//  myfidpass
//
//  Gabarit flyer aligné sur `app-flyer-qr-presets.js` (fidelity).
//

import CoreGraphics
import Foundation
import UIKit

enum FlyerCanvasPreset {
    /// Aperçu éditeur — même ratio 2:3, ~16× moins de pixels que l’export.
    static let preview = CGSize(width: 1024, height: 1536)
    /// Export PNG partage / impression.
    static let export = CGSize(width: 4096, height: 6144)

    static let designBaseWidth: CGFloat = 2400
    static let aspectRatio: CGFloat = designBaseWidth / 3600
}

struct FlyerLayoutMetrics {
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let designScale: CGFloat

    init(canvasSize: CGSize) {
        canvasWidth = max(1, canvasSize.width)
        canvasHeight = max(1, canvasSize.height)
        designScale = canvasWidth / FlyerCanvasPreset.designBaseWidth
    }

    var wheelCenterX: CGFloat { canvasWidth * (0.5 + 0.013) }
    var wheelCenterY: CGFloat { canvasHeight * 0.522 }
    var wheelRadius: CGFloat { canvasWidth * 0.435 }
    var spinnerRadius: CGFloat { max(340 * designScale, min(wheelRadius * 0.7, canvasWidth * 0.47)) }

    var qrSize: CGFloat { canvasWidth * 0.42 }
    var qrOriginX: CGFloat { canvasWidth * 0.472 }
    var qrOriginY: CGFloat { canvasHeight * 0.558 }
    var qrCornerRadius: CGFloat { 50 * designScale }
    var qrPadding: CGFloat { 15 * designScale }

    var printSafeBottomY: CGFloat { canvasHeight * (1 - 0.034) }
    var footerStepsHeight: CGFloat { canvasHeight * 0.108 }

    func logoLayout(from state: FlyerStateDTO) -> (centerY: CGFloat, maxW: CGFloat, maxH: CGFloat) {
        let cy = min(0.22, max(0.06, state.flyerLogoCenterYFrac))
        let mw = min(0.88, max(0.28, state.flyerLogoMaxWFrac))
        let mh = min(0.36, max(0.06, state.flyerLogoMaxHFrac))
        return (cy, mw, mh)
    }

    func logoBlockBottomFrac(hasLogo: Bool, state: FlyerStateDTO) -> CGFloat {
        guard hasLogo else { return 0.026 }
        let layout = logoLayout(from: state)
        return layout.centerY + layout.maxH / 2
    }
}

enum FlyerWheelGeometry {
    static let segmentCount = 6
    static let maskAlignmentOffsetDeg: Double = -30
    static let cleanOddHex = "#fbbf24"
    static let cleanEvenHex = "#f8fafc"

    static func segmentColors(from state: FlyerStateDTO) -> [UIColor] {
        let odd = UIColor.flyerHex(state.wheelColorOdd, fallback: cleanOddHex)
        let even = UIColor.flyerHex(state.wheelColorEven, fallback: cleanEvenHex)
        return (0..<segmentCount).map { $0.isMultiple(of: 2) ? odd : even }
    }

    static func normalizedSegmentColors(from state: FlyerStateDTO) -> [UIColor] {
        segmentColors(from: state).enumerated().map { index, color in
            if index.isMultiple(of: 2) == false { return UIColor.flyerHex(cleanEvenHex) }
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let lum = 0.299 * r + 0.587 * g + 0.114 * b
            return lum > 0.9 ? UIColor.flyerHex(cleanOddHex) : color
        }
    }

    static func segmentAngles(index: Int, offsetDeg: Double) -> (start: CGFloat, end: CGFloat) {
        let base = -.pi / 2 + CGFloat((offsetDeg + maskAlignmentOffsetDeg) * .pi / 180)
        let step = (.pi * 2) / CGFloat(segmentCount)
        let overlap: CGFloat = 0.003
        return (base + CGFloat(index) * step - overlap, base + CGFloat(index + 1) * step + overlap)
    }
}

extension UIColor {
    static func flyerHex(_ raw: String, fallback: String = "#ffffff") -> UIColor {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        let hex = t.count == 6 ? t : fallback.replacingOccurrences(of: "#", with: "")
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .white }
        return UIColor(
            red: CGFloat((value >> 16) & 0xff) / 255,
            green: CGFloat((value >> 8) & 0xff) / 255,
            blue: CGFloat(value & 0xff) / 255,
            alpha: 1
        )
    }

    func relativeLuminance() -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}
