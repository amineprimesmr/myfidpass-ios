//
//  FlyerLogoBackgroundPrepared.swift
//  myfidpass
//
//  Détourage fond logo pour collage sur fond IA.
//  Stratégie : détection dynamique de la couleur de fond + BFS depuis tous les bords.
//  Conditions requises pour appliquer le détourage :
//    1. L'image ne possède pas déjà de transparence significative (> 5 % des pixels).
//    2. Le fond détecté est uniforme : >= 50 % des pixels de bord appartiennent à la couleur
//       dominante estimée par histogramme sur l'ensemble des pixels de bord (robuste aux logos
//       avec éléments colorés aux coins). Évite de toucher aux photos ou fonds complexes.
//  Vision Framework supprimé : VNGenerateForegroundInstanceMaskRequest est conçu pour des
//  scènes naturelles — appliqué à des logos (typographie, photos produit), il détecte de
//  faux sujets et découpe dans le logo lui-même.
//

import CoreImage
import UIKit

enum FlyerLogoBackgroundPrepared {

    /// Prépare le logo pour export flyer (PNG transparent).
    ///  1. Redimensionne à 1536 px max si nécessaire.
    ///  2. Si déjà transparent → retourné tel quel.
    ///  3. Si fond uniforme détecté → BFS retire le fond.
    ///  4. Sinon (photo, fond complexe) → retourné tel quel.
    static func imageForFlyerLogoExport(_ image: UIImage) -> UIImage {
        guard let resized = image.flyerResizedMaxSide(FlyerLogoExportConfig.maxSideBeforeMask) else {
            return image
        }
        if imageHasSignificantAlpha(resized) {
            return resized
        }
        if let result = removeUniformBackgroundFromEdges(from: resized) {
            return result
        }
        return resized
    }

    // MARK: - Vérification transparence existante

    /// Retourne true si l'image a un canal alpha avec > 5 % de pixels transparents (alpha < 128).
    /// Dans ce cas le logo est déjà détouré — on ne touche pas.
    private static func imageHasSignificantAlpha(_ image: UIImage) -> Bool {
        guard let cg = image.cgImage else { return false }
        let alpha = cg.alphaInfo
        let hasChannel = alpha != .none && alpha != .noneSkipFirst && alpha != .noneSkipLast
        guard hasChannel else { return false }

        // Vérification rapide sur vignette 64 × 64
        let side = 64
        var buf = Data(count: side * side * 4)
        return buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ptr = raw.bindMemory(to: UInt8.self).baseAddress else { return false }
            guard let ctx = CGContext(
                data: ptr, width: side, height: side, bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            var count = 0
            for i in 0..<(side * side) {
                if ptr[i * 4 + 3] < 128 { count += 1 }
            }
            return count > (side * side) / 20  // > 5 %
        }
    }

    // MARK: - Suppression du fond uniforme

    /// Retire les pixels de fond si le fond est uniforme (couleur estimée par histogramme
    /// sur tous les pixels de bord, vérifiée sur ces mêmes pixels).
    /// Si le fond n'est pas uniforme → nil (pas de modification).
    private static func removeUniformBackgroundFromEdges(from image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w >= 8, h >= 8 else { return nil }

        let bpp = 4
        let bpr = w * bpp
        var data = Data(count: h * bpr)

        return data.withUnsafeMutableBytes { raw -> UIImage? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            guard let ctx = CGContext(
                data: base, width: w, height: h, bitsPerComponent: 8,
                bytesPerRow: bpr, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue).rawValue
            ) else { return nil }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            let tol = 48  // tolérance par canal (absorbe artefacts JPEG, anti-aliasing, légères variations)

            // ── 1. Couleur de fond : couleur dominante parmi tous les pixels de bord ─
            // On échantillonne TOUS les pixels du bord (pas seulement les 4 coins) pour
            // trouver le groupe de couleur le plus fréquent. Robuste aux logos qui ont
            // des éléments colorés exactement aux coins.
            var edgePixels: [(r: Int, g: Int, b: Int)] = []
            edgePixels.reserveCapacity(2 * (w + h))
            func collectEdge(_ x: Int, _ y: Int) {
                let o = (y * w + x) * bpp
                edgePixels.append((Int(base[o]), Int(base[o + 1]), Int(base[o + 2])))
            }
            for x in 0..<w { collectEdge(x, 0); collectEdge(x, h - 1) }
            for y in 1..<(h - 1) { collectEdge(0, y); collectEdge(w - 1, y) }

            // Trouve la couleur dominante par vote : chaque pixel vote pour le premier
            // centroïde (groupe) dans la tolérance, sinon crée un nouveau centroïde.
            var centroids: [(r: Int, g: Int, b: Int, count: Int)] = []
            for px in edgePixels {
                var placed = false
                for i in 0..<centroids.count {
                    let c = centroids[i]
                    if abs(px.r - c.r) <= tol && abs(px.g - c.g) <= tol && abs(px.b - c.b) <= tol {
                        // Met à jour le centroïde par moyenne cumulative
                        let n = c.count + 1
                        centroids[i] = (
                            r: (c.r * c.count + px.r) / n,
                            g: (c.g * c.count + px.g) / n,
                            b: (c.b * c.count + px.b) / n,
                            count: n
                        )
                        placed = true
                        break
                    }
                }
                if !placed { centroids.append((px.r, px.g, px.b, 1)) }
            }
            guard let best = centroids.max(by: { $0.count < $1.count }) else { return nil }
            let bgR = best.r, bgG = best.g, bgB = best.b

            // ── 2. Uniformité : au moins 50 % des pixels de bord appartiennent au fond ─
            func isBg(_ idx: Int) -> Bool {
                let o = idx * bpp
                return abs(Int(base[o])     - bgR) <= tol
                    && abs(Int(base[o + 1]) - bgG) <= tol
                    && abs(Int(base[o + 2]) - bgB) <= tol
            }

            let total = edgePixels.count
            var matched = 0
            for x in 0..<w {
                if isBg(0 * w + x)       { matched += 1 }
                if isBg((h - 1) * w + x) { matched += 1 }
            }
            for y in 1..<(h - 1) {
                if isBg(y * w + 0)       { matched += 1 }
                if isBg(y * w + (w - 1)) { matched += 1 }
            }

            // Fond non uniforme (photo, scène complexe) → ne pas toucher
            guard Double(matched) / Double(max(1, total)) >= 0.50 else { return nil }

            // ── 3. BFS depuis tous les pixels de bord qui appartiennent au fond ──────
            var visited = [Bool](repeating: false, count: w * h)
            var queue = [Int]()
            queue.reserveCapacity(min(w * h / 4, 100_000))

            func tryEnqueue(_ x: Int, _ y: Int) {
                guard x >= 0, x < w, y >= 0, y < h else { return }
                let i = y * w + x
                guard !visited[i], isBg(i) else { return }
                visited[i] = true
                queue.append(i)
            }

            for x in 0..<w { tryEnqueue(x, 0); tryEnqueue(x, h - 1) }
            for y in 1..<(h - 1) { tryEnqueue(0, y); tryEnqueue(w - 1, y) }

            var q = 0
            while q < queue.count {
                let i = queue[q]; q += 1
                let x = i % w, y = i / w
                tryEnqueue(x + 1, y); tryEnqueue(x - 1, y)
                tryEnqueue(x, y + 1); tryEnqueue(x, y - 1)
            }

            // ── 4. Effacer les pixels de fond (alpha = 0) ─────────────────────────────
            for i in 0..<(w * h) where visited[i] {
                let o = i * bpp
                base[o] = 0; base[o + 1] = 0; base[o + 2] = 0; base[o + 3] = 0
            }

            guard let outCg = ctx.makeImage() else { return nil }
            return UIImage(cgImage: outCg, scale: image.scale, orientation: image.imageOrientation)
        }
    }
}

// MARK: - Config

private enum FlyerLogoExportConfig {
    /// Taille max avant traitement — assez grand pour rendu net, assez petit pour l'API.
    static let maxSideBeforeMask: CGFloat = 1536
}

// MARK: - UIImage extensions

extension UIImage {
    /// Exporte le logo préparé (fond retiré si uniforme) en PNG data URL.
    /// Réduit progressivement jusqu'à tenir dans maxEncodedLength octets UTF-8.
    func flyerLogoPNGDataURLForAI(maxEncodedLength: Int = 2_400_000) -> String? {
        let prepared = FlyerLogoBackgroundPrepared.imageForFlyerLogoExport(self)
        let sides: [CGFloat] = [1536, 1280, 1024, 896, 768, 640, 512]
        let maxIn = max(prepared.size.width, prepared.size.height)
        for maxSide in sides {
            let scale = min(1.0, maxSide / max(1, maxIn))
            let w = prepared.size.width * scale
            let h = prepared.size.height * scale
            let fmt = UIGraphicsImageRendererFormat.default()
            fmt.opaque = false
            fmt.scale = prepared.scale
            let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: fmt)
                .image { _ in prepared.draw(in: CGRect(origin: .zero, size: CGSize(width: w, height: h))) }
            if let data = img.pngData() {
                let b64 = data.base64EncodedString()
                let url = "data:image/png;base64,\(b64)"
                if url.utf8.count <= maxEncodedLength { return url }
            }
        }
        return nil
    }

    fileprivate func flyerResizedMaxSide(_ maxSide: CGFloat) -> UIImage? {
        let m = max(size.width, size.height)
        guard m > maxSide else { return self }
        let s = maxSide / m
        let newSize = CGSize(width: size.width * s, height: size.height * s)
        let fmt = UIGraphicsImageRendererFormat.default()
        fmt.opaque = false
        fmt.scale = scale
        return UIGraphicsImageRenderer(size: newSize, format: fmt)
            .image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
