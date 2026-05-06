//
//  LogoColorExtractor.swift
//  myfidpass
//
//  Extrait des couleurs dominantes d’une image (logo) pour les proposer comme fond de carte, comme sur le SaaS.
//

import UIKit

enum LogoColorExtractor {
    private static let sampleSize: Int = 48
    /// Pas plus fin → trop de seaux proches ; plus large → couleurs « boue ». 14 ≈ teintes plus fidèles au visuel.
    private static let quantizeStep: Int = 14

    /// Retourne jusqu’à `maxColors` couleurs dominantes en hex (sans #), avec repli progressif si le logo est très clair, très sombre ou très transparent.
    static func dominantColors(from image: UIImage, maxColors: Int = 4) -> [String] {
        let prepared = bitmapForAnalysis(image)
        guard let cgImage = prepared.cgImage else { return [] }

        let strict = extractDominantHex(
            from: cgImage,
            maxColors: maxColors,
            minAlpha: 140,
            minLuminance: 0.06,
            maxLuminance: 0.92
        )
        if !strict.isEmpty { return strict }

        let relaxed = extractDominantHex(
            from: cgImage,
            maxColors: maxColors,
            minAlpha: 48,
            minLuminance: 0.01,
            maxLuminance: 0.99
        )
        if !relaxed.isEmpty { return relaxed }

        let last = extractDominantHex(
            from: cgImage,
            maxColors: maxColors,
            minAlpha: 8,
            minLuminance: 0,
            maxLuminance: 1
        )
        if !last.isEmpty { return last }

        /// Dernière chance (logos très clairs, très sombres, quasi-uniformes) : moyenne RGB des pixels opaques.
        if let flat = unfilteredAverageHex6(from: cgImage) { return [flat] }
        return []
    }

    /// Rend une bitmap « up » avec orientation appliquée (sinon `cgImage` brut peut être faux) et taille bornée pour l’analyse.
    private static func bitmapForAnalysis(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up, image.cgImage != nil {
            return image
        }
        let w = image.size.width * image.scale
        let h = image.size.height * image.scale
        let maxSide: CGFloat = 256
        let downscale = min(1, maxSide / max(w, h, 1))
        let size = CGSize(width: max(1, w * downscale), height: max(1, h * downscale))
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func extractDominantHex(
        from cgImage: CGImage,
        maxColors: Int,
        minAlpha: Int,
        minLuminance: Double,
        maxLuminance: Double
    ) -> [String] {
        let dim = min(sampleSize, cgImage.width, cgImage.height)
        guard dim > 0 else { return [] }

        let width = dim
        let height = dim
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var bucket: [String: Int] = [:]
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Int(pixelData[i]), g = Int(pixelData[i + 1]), b = Int(pixelData[i + 2]), a = Int(pixelData[i + 3])
            if a < minAlpha { continue }
            let lum = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
            if lum < minLuminance || lum > maxLuminance { continue }
            let kr = (r / quantizeStep) * quantizeStep
            let kg = (g / quantizeStep) * quantizeStep
            let kb = (b / quantizeStep) * quantizeStep
            let key = "\(kr),\(kg),\(kb)"
            bucket[key, default: 0] += 1
        }

        let sorted = bucket.sorted { $0.value > $1.value }.prefix(maxColors)
        return sorted.map { key, _ in
            let parts = key.split(separator: ",").compactMap { Int($0) }
            guard parts.count == 3 else { return "304FFE" }
            let r = min(255, parts[0]), g = min(255, parts[1]), b = min(255, parts[2])
            return String(format: "%02X%02X%02X", r, g, b)
        }
    }

    /// Moyenne des canaux (pixels avec alpha ≥ 8) — repli quand le quantification ne sort aucun seau.
    private static func unfilteredAverageHex6(from cgImage: CGImage) -> String? {
        let dim = min(sampleSize, cgImage.width, cgImage.height)
        guard dim > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        var pixelData = [UInt8](repeating: 0, count: dim * dim * 4)
        guard let context = CGContext(
            data: &pixelData,
            width: dim,
            height: dim,
            bitsPerComponent: 8,
            bytesPerRow: dim * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dim, height: dim))

        var rSum = 0, gSum = 0, bSum = 0, n = 0
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let a = Int(pixelData[i + 3])
            if a < 8 { continue }
            let r = Int(pixelData[i])
            let g = Int(pixelData[i + 1])
            let b = Int(pixelData[i + 2])
            rSum += r
            gSum += g
            bSum += b
            n += 1
        }
        guard n > 0 else { return nil }
        return String(
            format: "%02X%02X%02X",
            min(255, rSum / n),
            min(255, gSum / n),
            min(255, bSum / n)
        )
    }
}
