//
//  ImageIODownsampling.swift
//  myfidpass
//
//  Décodage partagé (ImageIO) avec plafond de pixels — robuste face aux HEIC multi-couches,
//  EXIF incohérents et miniatures ImageIO aux mauvaises proportions (bandelettes verticales en SwiftUI).
//

import ImageIO
import UIKit

enum ImageIODownsampling {

    /// Décode avec côté long plafonné (hors thread principal recommandé).
    static func imageFromData(_ data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        let maxPx = max(64, Int(maxPixelDimension.rounded()))
        if let source = CGImageSourceCreateWithData(data as CFData, nil),
           let ui = decodeThumbnailOrNil(from: source, maxPixelDimension: maxPx),
           !isAbsurdDisplayAspect(ui) {
            return displayFlattenIfNeeded(ui)
        }
        guard let fallback = uiImageFallbackDecodeAndDownsample(data: data, maxPixelDimension: maxPixelDimension),
              !isAbsurdDisplayAspect(fallback) else {
            return nil
        }
        return displayFlattenIfNeeded(fallback)
    }

    /// Lecture fichier → même pipeline que `imageFromData` (évite deux logiques divergentes).
    static func imageFromFile(at path: String, maxPixelDimension: CGFloat) -> UIImage? {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let url = URL(fileURLWithPath: trimmed)
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { return nil }
        return imageFromData(data, maxPixelDimension: maxPixelDimension)
    }

    // MARK: - ImageIO (thumbnail + validation)

    private static func decodeThumbnailOrNil(from source: CGImageSource, maxPixelDimension: Int) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelDimension,
        ]
        let sorted = candidateIndicesByDescendingPixelArea(source: source)
        guard !sorted.isEmpty else { return nil }

        for idx in sorted {
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, idx, options as CFDictionary),
                  cg.width > 1, cg.height > 1 else { continue }
            let props = CGImageSourceCopyPropertiesAtIndex(source, idx, nil) as? [String: Any] ?? [:]
            guard aspectRatioMatchesMetadata(cg: cg, properties: props, tolerance: 0.72) else { continue }
            if let ui = UIImage(cgImage: cg), !isAbsurdDisplayAspect(ui) { return ui }
        }

        for idx in sorted {
            guard let cg = CGImageSourceCreateThumbnailAtIndex(source, idx, options as CFDictionary),
                  cg.width > 8, cg.height > 8 else { continue }
            if let ui = UIImage(cgImage: cg), !isAbsurdDisplayAspect(ui) { return ui }
        }
        return nil
    }

    /// HEIC / GIF : plusieurs frames — on privilégie la plus grande surface pixel déclarée dans les métadonnées.
    private static func candidateIndicesByDescendingPixelArea(source: CGImageSource) -> [Int] {
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return [] }
        var scored: [(index: Int, area: CGFloat)] = []
        for i in 0..<count {
            guard let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                  let (pw, ph) = orientedPixelDimensions(from: props) else {
                scored.append((i, 0))
                continue
            }
            scored.append((i, pw * ph))
        }
        return scored.sorted { $0.area < $1.area }.map(\.index).reversed()
    }

    private static func orientedPixelDimensions(from properties: [String: Any]) -> (CGFloat, CGFloat)? {
        guard let pwNum = properties[kCGImagePropertyPixelWidth as String] as? NSNumber,
              let phNum = properties[kCGImagePropertyPixelHeight as String] as? NSNumber else {
            return nil
        }
        var pw = CGFloat(truncating: pwNum)
        var ph = CGFloat(truncating: phNum)
        guard pw > 0, ph > 0 else { return nil }
        let orientValue = (properties[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value ?? 1
        let orient = CGImagePropertyOrientation(rawValue: orientValue) ?? .up
        switch orient {
        case .left, .leftMirrored, .right, .rightMirrored:
            swap(&pw, &ph)
        default:
            break
        }
        return (pw, ph)
    }

    /// Compare le ratio du bitmap décodé au ratio attendu d’après les métadonnées (après orientation).
    private static func aspectRatioMatchesMetadata(cg: CGImage, properties: [String: Any], tolerance: CGFloat) -> Bool {
        guard let (pw, ph) = orientedPixelDimensions(from: properties) else { return true }
        let tw = CGFloat(cg.width)
        let th = CGFloat(cg.height)
        guard tw > 0, th > 0 else { return false }
        let rMeta = pw / ph
        let rCg = tw / th
        let lo = min(rMeta, rCg)
        let hi = max(rMeta, rCg)
        return (lo / hi) >= tolerance
    }

    /// Ratios délirants → quasi sûr que la miniature / les métadonnées sont incohérents (effet « fil » en SwiftUI).
    private static func isAbsurdDisplayAspect(_ image: UIImage) -> Bool {
        let w = image.size.width
        let h = image.size.height
        guard w > 0.01, h > 0.01 else { return true }
        let r = w / h
        return r < 0.0125 || r > 80
    }

    /// Aplatit l’orientation UIImage (chemins `UIImage(data:)` / dessin) pour un `size` fiable dans SwiftUI.
    private static func displayFlattenIfNeeded(_ image: UIImage) -> UIImage {
        guard image.size.width > 0.01, image.size.height > 0.01 else { return image }
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// Repli : décodage UIKit complet puis redimensionnement — coûteux mais rare si ImageIO échoue ou ment sur le ratio.
    private static func uiImageFallbackDecodeAndDownsample(data: Data, maxPixelDimension: CGFloat) -> UIImage? {
        guard let base = UIImage(data: data) else { return nil }
        let maxPx = max(64, maxPixelDimension)
        let pixelW = base.size.width * base.scale
        let pixelH = base.size.height * base.scale
        let longSide = max(pixelW, pixelH)
        guard longSide > maxPx else { return base }

        let scale = maxPx / longSide
        let targetSize = CGSize(
            width: max(1, floor(base.size.width * scale)),
            height: max(1, floor(base.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            base.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
